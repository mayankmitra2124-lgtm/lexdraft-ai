# frozen_string_literal: true

require 'securerandom'
require 'json'
require 'time'

module JobQueue
  DEFAULT_LEASE_SECONDS = 600 # 10 minutes

  def self.build_idempotency_key(job_type, payload)
    case job_type.to_s
    when 'extract'
      "extract:#{payload[:file_id] || payload['file_id']}:#{payload[:sha256] || payload['sha256']}"
    when 'transcribe'
      "transcribe:#{payload[:file_id] || payload['file_id']}:#{payload[:sha256] || payload['sha256']}"
    when 'aggregate'
      "aggregate:#{payload[:case_id] || payload['case_id']}:v#{payload[:summary_version] || payload['summary_version'] || 1}"
    when 'certify'
      "certify:#{payload[:case_id] || payload['case_id']}:#{payload[:timestamp_bucket] || payload['timestamp_bucket'] || Time.now.to_i / 60}"
    else
      "#{job_type}:#{Digest::SHA256.hexdigest(JSON.generate(payload))[0..16]}"
    end
  end

  def self.enqueue(tenant_id:, job_type:, payload:, priority: 100, run_at: Time.now, idempotency_key: nil)
    key = idempotency_key || build_idempotency_key(job_type, payload)
    job_id = "job_#{Time.now.to_i}_#{SecureRandom.hex(4)}"
    payload_json = payload.is_a?(String) ? payload : JSON.generate(payload)
    now_iso = Time.now.utc.iso8601
    run_at_iso = (run_at || Time.now).utc.iso8601

    sql = if Database.postgresql?
      <<-SQL
        INSERT INTO jobs (
          id, tenant_id, job_type, idempotency_key, payload,
          status, priority, attempts, max_attempts, run_at, created_at, updated_at
        ) VALUES (
          $1, $2, $3, $4, $5::jsonb, 'pending', $6, 0, 5, $7, $8, $9
        ) ON CONFLICT (idempotency_key) DO NOTHING
        RETURNING id;
      SQL
    else
      <<-SQL
        INSERT OR IGNORE INTO jobs (
          id, tenant_id, job_type, idempotency_key, payload,
          status, priority, attempts, max_attempts, run_at, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, 'pending', ?, 0, 5, ?, ?, ?)
      SQL
    end

    params = [job_id, tenant_id, job_type.to_s, key, payload_json, priority.to_i, run_at_iso, now_iso, now_iso]
    result = Database.query(sql, params)
    
    # Return job_id or existing job with that idempotency_key
    lookup_sql = Database.postgresql? ? 
      "SELECT * FROM jobs WHERE idempotency_key = $1" : 
      "SELECT * FROM jobs WHERE idempotency_key = ?"
    Database.query_one(lookup_sql, [key])
  end

  def self.claim_next_job(worker_id, lease_seconds = DEFAULT_LEASE_SECONDS)
    now = Time.now.utc
    lease_until = (now + lease_seconds).iso8601
    now_iso = now.iso8601

    if Database.postgresql?
      claim_sql = <<-SQL
        WITH next_job AS (
          SELECT id FROM jobs
          WHERE (status = 'pending' AND run_at <= NOW())
             OR (status = 'running' AND lease_until < NOW())
          ORDER BY priority ASC, run_at ASC
          FOR UPDATE SKIP LOCKED
          LIMIT 1
        )
        UPDATE jobs
        SET status = 'running',
            attempts = attempts + 1,
            locked_at = NOW(),
            locked_by = $1,
            lease_until = $2,
            updated_at = NOW()
        FROM next_job
        WHERE jobs.id = next_job.id
        RETURNING jobs.*;
      SQL
      row = Database.query_one(claim_sql, [worker_id, lease_until])
      return format_job(row) if row
    else
      # SQLite single-connection / test mode locking
      Database.transaction do
        select_sql = <<-SQL
          SELECT * FROM jobs
          WHERE (status = 'pending' AND run_at <= ?)
             OR (status = 'running' AND lease_until < ?)
          ORDER BY priority ASC, run_at ASC
          LIMIT 1
        SQL
        job = Database.query_one(select_sql, [now_iso, now_iso])
        if job
          update_sql = <<-SQL
            UPDATE jobs
            SET status = 'running',
                attempts = attempts + 1,
                locked_at = ?,
                locked_by = ?,
                lease_until = ?,
                updated_at = ?
            WHERE id = ?
          SQL
          Database.query(update_sql, [now_iso, worker_id, lease_until, now_iso, job['id']])
          job['status'] = 'running'
          job['attempts'] = job['attempts'].to_i + 1
          job['locked_by'] = worker_id
          job['lease_until'] = lease_until
          return format_job(job)
        end
      end
    end
    nil
  end

  def self.renew_lease(job_id, worker_id, extension_seconds = DEFAULT_LEASE_SECONDS)
    now = Time.now.utc
    new_lease_until = (now + extension_seconds).iso8601
    now_iso = now.iso8601

    if Database.postgresql?
      sql = <<-SQL
        UPDATE jobs
        SET lease_until = $1, updated_at = $2
        WHERE id = $3 AND locked_by = $4 AND status = 'running'
        RETURNING id;
      SQL
      res = Database.query_one(sql, [new_lease_until, now_iso, job_id, worker_id])
      !res.nil?
    else
      Database.transaction do
        job = Database.query_one("SELECT * FROM jobs WHERE id = ? AND locked_by = ? AND status = 'running'", [job_id, worker_id])
        if job
          Database.query(
            "UPDATE jobs SET lease_until = ?, updated_at = ? WHERE id = ?",
            [new_lease_until, now_iso, job_id]
          )
          true
        else
          false
        end
      end
    end
  end

  def self.retry_dead_letter(job_id, requesting_user = nil)
    # Admin authorization check
    if requesting_user
      is_admin = (requesting_user['role'].to_s.downcase == 'admin' || requesting_user['role'].to_s.downcase == 'managing_partner')
      unless is_admin
        raise "Unauthorized: Only administrators may requeue dead-letter jobs."
      end
    end

    now = Time.now.utc.iso8601
    job = Database.query_one(
      Database.postgresql? ? "SELECT * FROM jobs WHERE id = $1" : "SELECT * FROM jobs WHERE id = ?",
      [job_id]
    )
    return nil unless job
    unless job['status'] == 'dead_letter'
      raise "InvalidJobState: Only dead_letter jobs can be retried (current state: #{job['status']})"
    end

    update_sql = Database.postgresql? ?
      "UPDATE jobs SET status = 'pending', attempts = 0, locked_by = NULL, locked_at = NULL, lease_until = NULL, last_error = NULL, run_at = $1, updated_at = $1 WHERE id = $2 RETURNING *" :
      "UPDATE jobs SET status = 'pending', attempts = 0, locked_by = NULL, locked_at = NULL, lease_until = NULL, last_error = NULL, run_at = ?, updated_at = ? WHERE id = ?"
    
    if Database.postgresql?
      updated = Database.query_one(update_sql, [now, job_id])
    else
      Database.query(update_sql, [now, now, job_id])
      updated = Database.query_one("SELECT * FROM jobs WHERE id = ?", [job_id])
    end

    Database.log_audit_event(
      tenant_id: job['tenant_id'] || (requesting_user ? requesting_user['tenant_id'] : 'system'),
      user_id: requesting_user ? requesting_user['id'] : 'system_admin',
      action: 'job.requeued_from_dead_letter',
      resource_type: 'job',
      resource_id: job_id,
      metadata: { original_attempts: job['attempts'], last_error: job['last_error'] }
    )

    format_job(updated)
  end

  def self.mark_completed(job_id)
    now_iso = Time.now.utc.iso8601
    sql = Database.postgresql? ?
      "UPDATE jobs SET status = 'completed', lease_until = NULL, updated_at = $1 WHERE id = $2" :
      "UPDATE jobs SET status = 'completed', lease_until = NULL, updated_at = ? WHERE id = ?"
    Database.query(sql, [now_iso, job_id])
  end

  def self.mark_failed(job_id, error_message, max_attempts = 5)
    now = Time.now.utc
    job = Database.query_one(
      Database.postgresql? ? "SELECT * FROM jobs WHERE id = $1" : "SELECT * FROM jobs WHERE id = ?",
      [job_id]
    )
    return unless job

    attempts = job['attempts'].to_i + 1
    if attempts >= max_attempts
      # Move to Dead Letter
      sql = Database.postgresql? ?
        "UPDATE jobs SET status = 'dead_letter', attempts = $1, last_error = $2, lease_until = NULL, updated_at = $3 WHERE id = $4" :
        "UPDATE jobs SET status = 'dead_letter', attempts = ?, last_error = ?, lease_until = NULL, updated_at = ? WHERE id = ?"
      Database.query(sql, [attempts, error_message.to_s, now.iso8601, job_id])
    else
      # Exponential backoff: 5 * (2 ^ attempts) seconds
      backoff = 5 * (2 ** attempts)
      next_run = (now + backoff).iso8601
      sql = Database.postgresql? ?
        "UPDATE jobs SET status = 'pending', attempts = $1, run_at = $2, last_error = $3, lease_until = NULL, updated_at = $4 WHERE id = $5" :
        "UPDATE jobs SET status = 'pending', attempts = ?, run_at = ?, last_error = ?, lease_until = NULL, updated_at = ? WHERE id = ?"
      Database.query(sql, [attempts, next_run, error_message.to_s, now.iso8601, job_id])
    end
  end


  def self.cancel(job_id)
    now_iso = Time.now.utc.iso8601
    sql = Database.postgresql? ?
      "UPDATE jobs SET status = 'cancelled', lease_until = NULL, updated_at = $1 WHERE id = $2" :
      "UPDATE jobs SET status = 'cancelled', lease_until = NULL, updated_at = ? WHERE id = ?"
    Database.query(sql, [now_iso, job_id])
  end

  def self.reap_stale_jobs!
    now_iso = Time.now.utc.iso8601
    sql = Database.postgresql? ?
      "UPDATE jobs SET status = 'pending', lease_until = NULL, updated_at = $1 WHERE status = 'running' AND lease_until < $2" :
      "UPDATE jobs SET status = 'pending', lease_until = NULL, updated_at = ? WHERE status = 'running' AND lease_until < ?"
    Database.query(sql, [now_iso, now_iso])
  end

  def self.format_job(row)
    return nil unless row
    job = row.dup
    if job['payload'].is_a?(String)
      job['payload'] = JSON.parse(job['payload']) rescue {}
    end
    job
  end
end
