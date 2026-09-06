# frozen_string_literal: true

require_relative '../db/database'
require_relative '../services/storage_service'
require_relative '../services/job_queue'
require_relative '../services/gemini_service'
require_relative '../services/transcription_service'
require_relative '../services/aggregation_service'

module BackgroundWorker
  def self.start_loop(worker_id = "worker_#{Process.pid}_#{SecureRandom.hex(2)}", once: false)
    puts "[Worker #{worker_id}] Started background job processor..."
    $running = true
    trap('INT') { $running = false }
    trap('TERM') { $running = false }

    while $running
      begin
        # Periodically reap stale jobs with expired leases
        JobQueue.reap_stale_jobs!

        job = JobQueue.claim_next_job(worker_id)
        if job
          process_job(job)
        else
          break if once
          sleep 1.0 # Idle sleep
        end
      rescue => e
        puts "[Worker Error] #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        sleep 2.0
      end
      break if once
    end
    puts "[Worker #{worker_id}] Exiting gracefully."
  end

  def self.with_lease_heartbeat(job_id, worker_id, interval: 30, extension: 600)
    return yield unless worker_id && job_id

    running = true
    heartbeat_thread = Thread.new do
      while running
        sleep interval
        break unless running
        renewed = JobQueue.renew_lease(job_id, worker_id, extension)
        unless renewed
          puts "[Worker #{worker_id}] Heartbeat lost ownership for job #{job_id}"
          break
        end
      end
    end

    begin
      yield
    ensure
      running = false
      heartbeat_thread.kill if heartbeat_thread.alive?
    end
  end

  def self.process_job(job, worker_id = nil)
    job_id = job['id']
    job_type = job['job_type']
    payload = job['payload'] || {}
    tenant_id = job['tenant_id']
    active_worker = worker_id || job['locked_by'] || "worker_default"

    puts "[Worker] Claimed #{job_type} (Job ID: #{job_id})"

    with_lease_heartbeat(job_id, active_worker) do
      case job_type
      when 'extract'
      file_id = payload['file_id']
      case_id = payload['case_id']
      
      # 1. Gate: Must verify file exists and is in VERIFIED/QUEUED/PROCESSING status
      file_rec = Database.get_file(file_id)
      unless file_rec
        JobQueue.mark_failed(job_id, "File record not found: #{file_id}", 1)
        return
      end

      # Strict Evidence Gate: Refuse unverified or failed files
      unless StorageService.can_consume_evidence?(file_rec)
        puts "[Worker Gate] Refused to process unverified/failed file: #{file_id} (status: #{file_rec['status']})"
        JobQueue.mark_failed(job_id, "Evidence consumption gate rejected file with status: #{file_rec['status']}", 1)
        return
      end

      # 2. Idempotency Check: Verify if side-effect already committed in DB
      existing = Database.query_one(
        Database.postgresql? ? "SELECT id FROM extractions WHERE file_id = $1" : "SELECT id FROM extractions WHERE file_id = ?",
        [file_id]
      )
      if existing
        puts "[Worker] Extraction already exists for file: #{file_id}. Marking job complete (idempotent)."
        JobQueue.mark_completed(job_id)
        return
      end

      # Transition to PROCESSING
      Database.update_file_status(file_id, 'PROCESSING', progress: 30)


      # 3. Read evidence via StorageService abstraction
      storage_key = file_rec['storage_key'] || file_rec['storage_path']
      file_bytes = StorageService.adapter.get_object(key: storage_key)
      unless file_bytes
        # Try local path fallback
        if File.file?(file_rec['storage_path'].to_s)
          file_bytes = File.binread(file_rec['storage_path'])
        else
          Database.update_file_status(file_id, 'Failed', error_message: "Evidence payload missing from storage: #{storage_key}")
          JobQueue.mark_failed(job_id, "Evidence payload missing: #{storage_key}")
          return
        end
      end

      # 4. Perform AI Synthesis
      case_rec = Database.get_case(case_id)
      extraction = GeminiService.extract_from_bytes(file_rec, file_bytes, case_rec)
      
      # 5. Commit extraction and mark job completed atomically
      Database.transaction do
        Database.save_extraction(file_id, case_id, extraction)
        Database.update_file_status(file_id, 'Complete', progress: 100)
        JobQueue.mark_completed(job_id)
      end

      # Trigger master chronology synthesis
      JobQueue.enqueue(
        tenant_id: tenant_id,
        job_type: 'aggregate',
        payload: { case_id: case_id }
      )

    when 'aggregate'
      case_id = payload['case_id']
      AggregationService.aggregate_case_evidence(case_id)
      JobQueue.mark_completed(job_id)

    else
      JobQueue.mark_completed(job_id)
    end
    end
  rescue => e
    puts "[Worker Job Failed] #{job_id}: #{e.message}"
    JobQueue.mark_failed(job_id, "#{e.class}: #{e.message}")
  end
end

if __FILE__ == $0
  BackgroundWorker.start_loop
end
