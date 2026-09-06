# frozen_string_literal: true

require 'test/unit'
require 'time'
require 'json'
require 'digest'
require 'securerandom'
require 'sqlite3'

require_relative '../db/database'
require_relative '../services/storage_service'
require_relative '../services/job_queue'
require_relative '../server'
require_relative '../db/migrate_sqlite_to_pg'

class Phase2DurabilityTest < Test::Unit::TestCase
  def setup
    Database.init
    StorageService.init
  end

  # ========================================================
  # 1. DATABASE LAYER TESTS
  # ========================================================

  def test_pg1_schema_integrity
    # Verify canonical schema file exists and contains all 16 target tables
    schema_sql = File.read(File.expand_path('../../db/pg_schema.sql', __FILE__))
    tables = %w[
      tenants users user_sessions ip_login_attempts cases evidence_files
      file_chunks extractions master_summaries diff_logs notifications
      audit_logs system_settings performance_metrics extraction_cache jobs
    ]
    tables.each do |tbl|
      assert_match(/CREATE TABLE IF NOT EXISTS #{tbl}/i, schema_sql, "Table #{tbl} must be defined in pg_schema.sql")
    end
  end

  def test_pg2_tenant_isolation_scoping
    user_a = Database.query_one("SELECT * FROM users LIMIT 1")
    user_b = Database.query_one("SELECT * FROM users WHERE tenant_id != ? LIMIT 1", [user_a['tenant_id']])
    
    if user_b
      case_a = Database.query_one("SELECT * FROM cases WHERE tenant_id = ? LIMIT 1", [user_a['tenant_id']])
      if case_a
        # User B querying User A's case must be denied
        has_access = Database.verify_case_access(case_a['id'], user_b)
        assert_equal false, has_access, "User B must not access User A's tenant-scoped case"
      end
    end
  end

  def test_pg3_pool_sizing_and_placeholders
    # Test lexical SQL tokenizer
    sql_with_question = "SELECT * FROM cases WHERE objective = 'Is this 100% genuine?' AND tenant_id = ? AND case_number = ?"
    sanitized = Database.sanitize_placeholders(sql_with_question)
    assert_equal "SELECT * FROM cases WHERE objective = 'Is this 100% genuine?' AND tenant_id = $1 AND case_number = $2", sanitized
  end

  def test_pg4_transaction_rollback
    test_id = "test_case_rb_#{Time.now.to_i}"
    begin
      Database.transaction do
        Database.connection.execute(
          "INSERT INTO cases (id, name, created_at, updated_at, tenant_id, user_id) VALUES (?, ?, ?, ?, ?, ?)",
          [test_id, 'Rollback Probe', Time.now.to_i.to_s, Time.now.to_i.to_s, 'ten_default', 'usr_default']
        )
        raise "Intentional crash to test rollback"
      end
    rescue => e
      # Expected
    end

    row = Database.query_one("SELECT * FROM cases WHERE id = ?", [test_id])
    assert_nil row, "Transaction rollback must ensure aborted insert does not persist"
  end

  # ========================================================
  # 2. STORAGE ADAPTER TESTS
  # ========================================================

  def test_st1_storage_adapter_operations
    adapter = StorageService.adapter
    test_key = "tenants/test_ten/cases/test_case/evidence/test_file/mock_hash_123"
    payload = "LexDraft AI Supreme Court Evidence Document Payload\n"

    # Put object
    put_res = adapter.put_object(key: test_key, io_or_string: payload, content_type: 'text/plain')
    assert_equal test_key, put_res[:key]
    assert_equal Digest::SHA256.hexdigest(payload), put_res[:sha256]

    # Check existence and size
    assert_equal true, adapter.object_exists?(key: test_key)
    assert_equal payload.bytesize, adapter.object_size(key: test_key)

    # Get object
    retrieved = adapter.get_object(key: test_key)
    assert_equal payload, retrieved

    # Delete object
    adapter.delete_object(key: test_key)
    assert_equal false, adapter.object_exists?(key: test_key)
  end

  def test_st2_presigned_url_authorization
    test_key = "tenants/ten_4920/cases/case_9182/evidence/ef_001/a591a6d40bf4"
    url = StorageService.generate_download_url(test_key, expires_in: 300, filename: 'petition.pdf')
    assert_not_nil url, "Presigned download URL must be generated"
    assert url.include?('token='), "URL must contain secure token parameter"
  end

  def test_st3_sha256_trust_model
    # Upload file through StorageService
    fake_client_hash = "fake_client_sha256_000000000000000000000000000000000000000000000"
    content = "%PDF-1.4 Genuine Evidence Content #{SecureRandom.hex(8)}"
    authoritative_hash = Digest::SHA256.hexdigest(content)

    saved = StorageService.save_stream("case_test_trust", "evidence.pdf", content, "application/pdf")
    
    # Assert authoritative hash was computed server-side
    assert_equal authoritative_hash, saved['sha256_hash']
    assert_equal 'VERIFIED', saved['status']
    assert_not_equal fake_client_hash, saved['sha256_hash']

    # Clean up test artifact so reconciliation inventory stays clean
    StorageService.delete_file(saved['storage_path'])
    FileUtils.rm_rf(File.expand_path('../../uploads/case_test_trust', __FILE__))
  end

  def test_st4_evidence_reconciliation
    # Clean up any transient test folders before inventory check
    FileUtils.rm_rf(File.expand_path('../../uploads/case_test_trust', __FILE__))
    FileUtils.rm_rf(File.expand_path('../../uploads/test_case', __FILE__))

    # Verify that reconciliation script runs and accounts for all 184 rows
    res = MigrationRunner.reconcile_evidence_inventory!
    assert_equal 184, res[:total_rows]
    assert_equal 174, res[:verified_existing]
    assert_equal 10, res[:flagged_missing]
    assert res[:untracked_archived] >= 2

    # Verify that the 10 missing test records have status 'Failed'
    failed_test_rows = Database.query("SELECT * FROM evidence_files WHERE storage_path LIKE '/tmp/%'")
    failed_test_rows.each do |row|
      assert_equal 'Failed', row['status']
      assert_match(/Legacy test artifact payload missing/, row['error_message'])
    end
  end

  def test_st5_failed_evidence_consumption_gate
    # 1. Pick one of the 10 failed legacy evidence records
    failed_file = Database.query_one("SELECT * FROM evidence_files WHERE status = 'Failed' LIMIT 1")
    assert_not_nil failed_file, "Must have a failed legacy evidence record"

    file_id = failed_file['id']
    case_id = failed_file['case_id']

    # 2. Assert StorageService gate refuses it
    assert_equal false, StorageService.can_consume_evidence?(failed_file), "StorageService must refuse failed evidence"

    ext_count_before = Database.query_one("SELECT count(*) as c FROM extractions")['c']

    # 3. Attempt to enqueue and process via BackgroundWorker
    Database.query("DELETE FROM jobs WHERE status = 'pending'")
    job = JobQueue.enqueue(
      tenant_id: failed_file['tenant_id'] || 'ten_default',
      job_type: 'extract',
      payload: { file_id: file_id, case_id: case_id, sha256: 'dummy_hash' },
      idempotency_key: "test_gate_fail_#{Time.now.to_f}"
    )

    # 4. Process job via BackgroundWorker
    claimed = JobQueue.claim_next_job("worker_gate_tester")
    require_relative '../bin/worker'
    BackgroundWorker.process_job(claimed)

    # 5. Verify assertions:
    # - File status remains 'Failed' (no transition to PROCESSING or VERIFIED)
    file_after = Database.get_file(file_id)
    assert_equal 'Failed', file_after['status'], "File must remain in Failed status"

    # - Job status is dead_letter / failed (refused by worker)
    job_after = Database.query_one("SELECT * FROM jobs WHERE id = ?", [claimed['id']])
    assert_equal 'dead_letter', job_after['status'], "Job must be marked dead_letter"
    assert_match(/Evidence consumption gate rejected/, job_after['last_error'])

    # - No extraction side-effect created
    ext_count_after = Database.query_one("SELECT count(*) as c FROM extractions")['c']
    assert_equal ext_count_before, ext_count_after, "No new extraction row may be created for failed evidence"
  end

  # ========================================================
  # 3. MIGRATION & CANONICAL VERIFICATION TESTS
  # ========================================================

  def test_m1_canonical_checksums_all_16_tables
    report = MigrationRunner.run_verification!
    expected_tables = %w[
      tenants users user_sessions ip_login_attempts cases evidence_files
      file_chunks extractions master_summaries diff_logs notifications
      system_settings performance_metrics extraction_cache audit_logs jobs
    ]

    # Verify all 16 tables are present
    assert_equal 16, report.keys.size, "Verification must cover exactly 16 tables"
    expected_tables.each do |tbl|
      assert report.key?(tbl), "Table #{tbl} must be present in canonical checksum report"
      assert_equal 64, report[tbl][:canonical_checksum].length, "Table #{tbl} must have 64-char SHA256 checksum"
    end

    # Verify foreign key and idempotency integrity
    integrity = MigrationRunner.verify_integrity!
    assert_equal true, integrity[:jobs_idempotency_key_unique], "jobs idempotency keys must be unique"
    assert_equal true, integrity[:cases_tenant_fk_valid], "cases tenant_id foreign keys must be valid"
    assert_equal true, integrity[:evidence_files_case_fk_valid], "evidence_files case_id foreign keys must be valid"
    assert_equal true, integrity[:extractions_file_fk_valid], "extractions file_id foreign keys must be valid"
  end

  def test_m2_interrupted_migration_idempotency
    # Running reconciliation and canonical checksum calculation repeatedly produces identical results
    rep1 = MigrationRunner.run_verification!
    rep2 = MigrationRunner.run_verification!
    assert_equal rep1['tenants'][:canonical_checksum], rep2['tenants'][:canonical_checksum]
    assert_equal rep1['cases'][:canonical_checksum], rep2['cases'][:canonical_checksum]
    assert_equal rep1['jobs'][:canonical_checksum], rep2['jobs'][:canonical_checksum]
  end

  def test_pg5_connection_pool_concurrency_headroom
    # Mathematical sizing validation:
    # 2 Puma workers x 10 connection pool = 20 max web connections
    # 1 background worker daemon = 4 connections
    # 1 ops / maintenance = 4 connections
    # Total application connections: 28
    # Target Managed PostgreSQL capacity: 97
    web_pool_per_worker = Integer(ENV.fetch('DB_POOL_SIZE', 10))
    puma_workers = Integer(ENV.fetch('WEB_CONCURRENCY', 2))
    worker_daemon_pool = 4
    maintenance_pool = 4

    total_app_connections = (web_pool_per_worker * puma_workers) + worker_daemon_pool + maintenance_pool
    pg_capacity = 97 # Render Starter/Standard managed PostgreSQL default

    assert_equal 28, total_app_connections, "Total application connections must be 28"
    assert total_app_connections < pg_capacity, "Total application connections (#{total_app_connections}) must have safe headroom below PostgreSQL capacity (#{pg_capacity})"
    headroom_percentage = ((pg_capacity - total_app_connections).to_f / pg_capacity * 100).round(1)
    assert headroom_percentage > 60.0, "Headroom must be > 60% (currently #{headroom_percentage}%)"
  end


  # ========================================================
  # 4. BACKGROUND JOB QUEUE TESTS
  # ========================================================

  def test_q1_queue_exclusive_claiming_and_lease
    tenant_id = "ten_test_q1"
    job_type = "extract"
    payload = { file_id: "file_q1_#{SecureRandom.hex(4)}", sha256: "hash_q1" }

    # Enqueue
    job = JobQueue.enqueue(tenant_id: tenant_id, job_type: job_type, payload: payload)
    assert_not_nil job
    assert_equal 'pending', job['status']

    # Exclusive Claim
    worker_1 = "worker_alpha"
    claimed_1 = JobQueue.claim_next_job(worker_1, 600)
    assert_not_nil claimed_1
    assert_equal 'running', claimed_1['status']
    assert_equal worker_1, claimed_1['locked_by']

    # Mark completed
    JobQueue.mark_completed(claimed_1['id'])
    completed = Database.query_one("SELECT * FROM jobs WHERE id = ?", [claimed_1['id']])
    assert_equal 'completed', completed['status']
  end

  def test_q2_queue_idempotency_duplicate_enqueue
    tenant_id = "ten_test_q2"
    idempotency_key = "extract:file_dup_123:sha256_dup_123"
    payload = { file_id: "file_dup_123", sha256: "sha256_dup_123" }

    # First enqueue
    job1 = JobQueue.enqueue(tenant_id: tenant_id, job_type: "extract", payload: payload, idempotency_key: idempotency_key)
    # Second enqueue with identical idempotency key
    job2 = JobQueue.enqueue(tenant_id: tenant_id, job_type: "extract", payload: payload, idempotency_key: idempotency_key)

    assert_equal job1['id'], job2['id'], "Duplicate enqueue with same idempotency key must return existing job without duplicating"
  end

  def test_q3_ai_crash_recovery_and_side_effect_idempotency
    # Clear any previous test pending jobs so queue test is deterministic
    Database.query("DELETE FROM jobs WHERE status = 'pending'")

    existing_file = Database.query_one("SELECT * FROM evidence_files LIMIT 1")
    file_id = existing_file['id']
    case_id = existing_file['case_id']

    # Ensure extraction row exists
    existing_ext = Database.query_one("SELECT id FROM extractions WHERE file_id = ?", [file_id])
    unless existing_ext
      Database.connection.execute(
        "INSERT INTO extractions (id, file_id, case_id, file_summary, created_at) VALUES (?, ?, ?, ?, ?)",
        ["ext_#{file_id}", file_id, case_id, "Summary already extracted", Time.now.utc.iso8601]
      )
    end

    # Job is enqueued
    job = JobQueue.enqueue(
      tenant_id: existing_file['tenant_id'] || 'ten_default',
      job_type: 'extract',
      payload: { file_id: file_id, case_id: case_id, sha256: 'abc' },
      idempotency_key: "test_crash_recovery_#{Time.now.to_f}"
    )
    claimed = JobQueue.claim_next_job("worker_crash_test")

    # BackgroundWorker process_job detects existing extraction and skips API call
    require_relative '../bin/worker'
    BackgroundWorker.process_job(claimed)

    job_after = Database.query_one("SELECT * FROM jobs WHERE id = ?", [claimed['id']])
    assert_equal 'completed', job_after['status'], "Worker must complete job idempotently if extraction side-effect exists"
  end



  def test_q4_dead_letter_queue_handling
    tenant_id = "ten_test_dlq"
    payload = { file_id: "toxic_payload_#{SecureRandom.hex(4)}" }
    job = JobQueue.enqueue(tenant_id: tenant_id, job_type: "extract", payload: payload)

    # Simulate 5 consecutive failures
    5.times do |i|
      JobQueue.mark_failed(job['id'], "Simulated failure attempt #{i + 1}", 5)
    end

    job_final = Database.query_one("SELECT * FROM jobs WHERE id = ?", [job['id']])
    assert_equal 'dead_letter', job_final['status'], "Job failing 5 times must route to dead_letter"
    assert_match(/Simulated failure/, job_final['last_error'])
  end

  # ========================================================
  # 5. PUMA RACK APP CONCURRENCY TESTS
  # ========================================================

  def test_pu1_rack_application_lifecycle
    app = LexDraftApp.new
    
    # Test /healthz
    env_health = {
      'PATH_INFO' => '/healthz',
      'REQUEST_METHOD' => 'GET',
      'rack.input' => StringIO.new('')
    }
    status, headers, body = app.call(env_health)
    assert_equal 200, status
    assert_match(/healthy/, body.first)

    # Test /readyz
    env_ready = {
      'PATH_INFO' => '/readyz',
      'REQUEST_METHOD' => 'GET',
      'rack.input' => StringIO.new('')
    }
    status, headers, body = app.call(env_ready)
    assert_equal 200, status
    assert_match(/ready/, body.first)
  end

  # ========================================================
  # 6. DATA INTEGRITY VERIFICATION DRILL (NOT LIVE DR RESTORE)
  # ========================================================

  def test_data_integrity_verification_drill
    # NOTE: This is a canonical data integrity and checksum verification drill,
    # NOT a live disaster-recovery restore drill.
    # No fresh PostgreSQL instance was created or destroyed during this test;
    # data was verified against authoritative SQLite/PostgreSQL storage in-place.
    start_time = Time.now
    # Execute canonical verification as measurable integrity drill
    report = MigrationRunner.run_verification!
    elapsed_seconds = Time.now - start_time

    assert elapsed_seconds < 10.0, "Integrity verification drill must complete promptly (took #{elapsed_seconds}s)"
    assert_equal 184, report['evidence_files'][:row_count], "All 184 evidence files must be accounted for in DB inventory"
    assert_equal 16, report.keys.size, "Verification drill must cover all 16 tables"
  end

  # ========================================================
  # 7. PHASE 2 REMEDIATIONS EXTENDED VALIDATION
  # ========================================================

  def test_q5_lease_heartbeat_renewal
    test_file_id = "file_lh_#{SecureRandom.hex(4)}"
    idemp_key = "extract:#{test_file_id}:hash"
    job = JobQueue.enqueue(tenant_id: 'ten_default', job_type: 'extract', payload: { file_id: test_file_id }, idempotency_key: idemp_key)
    
    claimed = JobQueue.claim_next_job("worker_alpha", 2)
    assert_not_nil claimed
    orig_lease = claimed['lease_until']

    # Renew lease
    sleep 0.5
    renewed = JobQueue.renew_lease(job['id'], "worker_alpha", 10)
    assert_equal true, renewed, "Active worker must be able to renew its lease"
    
    updated_job = Database.query_one("SELECT * FROM jobs WHERE id = ?", [job['id']])
    assert Time.parse(updated_job['lease_until']) > Time.parse(orig_lease), "Lease timestamp must be extended forward"

    # Competing worker cannot claim while active
    competitor = JobQueue.claim_next_job("worker_beta", 5)
    assert(competitor.nil? || competitor['id'] != job['id'], "Competing worker must not claim actively leased job")

    JobQueue.mark_completed(job['id'])
  end

  def test_q6_dead_letter_admin_recovery
    tenant = Database.query_one("SELECT * FROM tenants LIMIT 1")
    admin = Database.query_one("SELECT * FROM users WHERE tenant_id = ? AND role = 'admin' LIMIT 1", [tenant['id']])
    unless admin
      admin = Database.query_one("SELECT * FROM users WHERE tenant_id = ? LIMIT 1", [tenant['id']])
      Database.query("UPDATE users SET role = 'admin' WHERE id = ?", [admin['id']])
      admin['role'] = 'admin'
    end
    non_admin = { 'id' => 'usr_associate', 'tenant_id' => tenant['id'], 'role' => 'associate' }

    job = JobQueue.enqueue(tenant_id: tenant['id'], job_type: 'extract', payload: { file_id: 'test_dlq_rec' })
    JobQueue.mark_failed(job['id'], "Forced fatal crash", 1)
    dead_job = Database.query_one("SELECT * FROM jobs WHERE id = ?", [job['id']])
    assert_equal 'dead_letter', dead_job['status']

    # Non-admin attempt rejected
    assert_raise(RuntimeError) { JobQueue.retry_dead_letter(job['id'], non_admin) }

    # Admin retry permitted
    retried = JobQueue.retry_dead_letter(job['id'], admin)
    assert_equal 'pending', retried['status']
    assert_equal 0, retried['attempts']
    assert_nil retried['locked_by']
  end

  def test_aud1_audit_log_immutability
    tenant = Database.query_one("SELECT * FROM tenants LIMIT 1")
    user = Database.query_one("SELECT * FROM users WHERE tenant_id = ? LIMIT 1", [tenant['id']])

    Database.log_audit_event(
      tenant_id: tenant['id'],
      user_id: user['id'],
      action: 'security.immutability_probe',
      resource_type: 'audit',
      resource_id: 'probe_001'
    )
    audit = Database.query_one("SELECT * FROM audit_logs WHERE action = 'security.immutability_probe' ORDER BY created_at DESC LIMIT 1")
    assert_not_nil audit, "INSERT must succeed"

    # UPDATE must be denied by trigger
    assert_raise(SQLite3::ConstraintException) do
      Database.query("UPDATE audit_logs SET action = 'tampered' WHERE id = ?", [audit['id']])
    end

    # DELETE must be denied by trigger
    assert_raise(SQLite3::ConstraintException) do
      Database.query("DELETE FROM audit_logs WHERE id = ?", [audit['id']])
    end

    persisted = Database.query_one("SELECT * FROM audit_logs WHERE id = ?", [audit['id']])
    assert_equal 'security.immutability_probe', persisted['action'], "Record must remain pristine"
  end

  def test_idem1_certification_and_aggregation_idempotency
    case_rec = Database.query_one("SELECT * FROM cases LIMIT 1")
    file_rec = Database.query_one("SELECT * FROM evidence_files WHERE case_id = ? LIMIT 1", [case_rec['id']])

    # Certificate ID deterministic
    c1 = CertificateService.generate_section_65b_certificate(case_rec, file_rec)
    c2 = CertificateService.generate_section_65b_certificate(case_rec, file_rec)
    assert_equal c1[:certificate_id], c2[:certificate_id], "Certificate ID must be deterministic and idempotent"

    # Master summary stable when content unchanged
    s1 = AggregationService.aggregate_case_evidence(case_rec['id'])
    v1 = Database.query_one("SELECT count(*) as c FROM master_summaries WHERE case_id = ?", [case_rec['id']])['c']
    s2 = AggregationService.aggregate_case_evidence(case_rec['id'])
    v2 = Database.query_one("SELECT count(*) as c FROM master_summaries WHERE case_id = ?", [case_rec['id']])['c']
    assert_equal v1, v2, "Summary version count must remain unchanged when content is identical"
  end

  def test_top1_production_topology_safety_assertion
    orig_env = ENV['RACK_ENV']
    orig_sw = ENV['STANDALONE_WORKER']
    orig_dew = ENV['DISABLE_EMBEDDED_WORKER']
    begin
      ENV['RACK_ENV'] = 'production'
      ENV['STANDALONE_WORKER'] = 'false'
      ENV['DISABLE_EMBEDDED_WORKER'] = 'false'

      assert_raise(RuntimeError) do
        load File.expand_path('../../config.ru', __FILE__)
      end
    ensure
      ENV['RACK_ENV'] = orig_env
      ENV['STANDALONE_WORKER'] = orig_sw
      ENV['DISABLE_EMBEDDED_WORKER'] = orig_dew
    end
  end

  def test_adm1_admin_dead_letter_retry_endpoint
    tenant = Database.query_one("SELECT * FROM tenants LIMIT 1")
    admin = Database.query_one("SELECT u.*, s.token FROM users u JOIN user_sessions s ON u.id = s.user_id WHERE u.tenant_id = ? AND u.role = 'admin' AND s.token IS NOT NULL LIMIT 1", [tenant['id']])
    unless admin
      admin = Database.query_one("SELECT u.*, s.token FROM users u JOIN user_sessions s ON u.id = s.user_id WHERE u.tenant_id = ? AND s.token IS NOT NULL LIMIT 1", [tenant['id']])
      Database.query("UPDATE users SET role = 'admin' WHERE id = ?", [admin['id']])
      admin['role'] = 'admin'
    end

    job = JobQueue.enqueue(tenant_id: tenant['id'], job_type: 'extract', payload: { file_id: 'test_api_dlq' })
    JobQueue.mark_failed(job['id'], "Trigger DLQ for API", 1)

    app = LexDraftApp.new
    env = {
      'REQUEST_METHOD' => 'POST',
      'PATH_INFO' => "/api/admin/jobs/#{job['id']}/retry",
      'HTTP_AUTHORIZATION' => "Bearer #{admin['token']}",
      'rack.input' => StringIO.new('')
    }
    status, _, body = app.call(env)
    assert_equal 200, status, "Admin dead-letter retry API must return 200 OK"
    parsed = JSON.parse(body.join)
    assert_equal 'requeued', parsed['status']
  end
end
