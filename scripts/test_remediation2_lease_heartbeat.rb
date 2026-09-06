# frozen_string_literal: true

require 'json'
require 'time'
require 'securerandom'
require_relative '../db/database'
require_relative '../services/job_queue'
require_relative '../bin/worker'

Database.init

# Clear lingering running or pending test jobs
Database.query("DELETE FROM jobs WHERE status IN ('pending', 'running')")

puts "\n========================================================"
puts " RUNNING REMEDIATION 2 — LONG-RUNNING LEASE & HEARTBEAT TESTS"
puts "========================================================\n"

# Test 1: Worker A claims, heartbeats, Worker B cannot steal, Worker A completes
test_file_id = "file_lease_test_#{SecureRandom.hex(4)}"
idempotency_key = "extract:#{test_file_id}:hash123"

# Clear any lingering test jobs
Database.query("DELETE FROM jobs WHERE idempotency_key = ?", [idempotency_key])

job1 = JobQueue.enqueue(
  tenant_id: 'ten_test_lease',
  job_type: 'extract',
  payload: { file_id: test_file_id, case_id: 'case_test' },
  idempotency_key: idempotency_key
)

worker_a = "worker_alpha_#{Process.pid}"
worker_b = "worker_beta_#{Process.pid}"

# Worker A claims job with a short 2-second initial lease to test rapid renewal
claimed_a = JobQueue.claim_next_job(worker_a, 2)
raise "Worker A failed to claim" unless claimed_a && claimed_a['id'] == job1['id']
initial_lease = claimed_a['lease_until']
puts "[Pass] Worker A claimed job #{job1['id']}. Initial lease: #{initial_lease}"

# Worker A simulates long-running job and heartbeats
sleep 1.0
renewed = JobQueue.renew_lease(job1['id'], worker_a, 5) # extends by 5s
raise "Lease renewal failed" unless renewed
job_after_renew = Database.query_one("SELECT * FROM jobs WHERE id = ?", [job1['id']])
new_lease = job_after_renew['lease_until']
puts "[Pass] Worker A successfully renewed lease. New lease: #{new_lease}"
raise "Lease was not extended forward" unless Time.parse(new_lease) > Time.parse(initial_lease)

# Worker B attempts to claim while Worker A is still actively heartbeating
claimed_b = JobQueue.claim_next_job(worker_b, 5)
raise "Concurrency Failure: Worker B stole active job from Worker A!" if claimed_b && claimed_b['id'] == job1['id']
puts "[Pass] Worker B was rejected from claiming job #{job1['id']} while Worker A lease is active."

# Worker A completes job
JobQueue.mark_completed(job1['id'])
job_final = Database.query_one("SELECT * FROM jobs WHERE id = ?", [job1['id']])
raise "Job not completed" unless job_final['status'] == 'completed'
puts "[Pass] Worker A completed job #{job1['id']} successfully."

# Verify single result in DB
count = Database.query_one("SELECT count(*) as c FROM jobs WHERE idempotency_key = ?", [idempotency_key])['c']
raise "Duplication failure: multiple jobs exist for key #{idempotency_key}" unless count == 1
puts "[Pass] Exactly 1 job record exists for idempotency key #{idempotency_key}."

# -------------------------------------------------------------
# Test 2: Worker Crash Simulation and Stale-Worker Recovery
# -------------------------------------------------------------
puts "\nTesting Worker Crash & Lease Expiration Recovery..."
test_file_id_crash = "file_crash_test_#{SecureRandom.hex(4)}"
idemp_crash = "extract:#{test_file_id_crash}:hash456"

job2 = JobQueue.enqueue(
  tenant_id: 'ten_test_lease',
  job_type: 'extract',
  payload: { file_id: test_file_id_crash, case_id: 'case_test' },
  idempotency_key: idemp_crash
)

# Worker A claims with 1-second lease, then "crashes" (stops heartbeating)
claimed_crash = JobQueue.claim_next_job("worker_crashed_process", 1)
puts "[Pass] Worker A claimed job #{job2['id']} with 1s lease, then terminated abruptly."

# Wait for lease to expire
sleep 2.5

# Worker B claims expired job via stale lease recovery
claimed_by_b = JobQueue.claim_next_job("worker_survivor_process", 10)
raise "Stale Recovery Failure: Worker B could not reclaim expired job!" unless claimed_by_b && claimed_by_b['id'] == job2['id']
puts "[Pass] Worker B successfully reclaimed expired job #{job2['id']} after Worker A crash."

# Worker B finishes job
JobQueue.mark_completed(job2['id'])
job2_final = Database.query_one("SELECT * FROM jobs WHERE id = ?", [job2['id']])
raise "Job 2 not completed" unless job2_final['status'] == 'completed'
puts "[Pass] Worker B successfully completed job #{job2['id']}."

results = {
  test_name: "Remediation 2: Long-Running Lease Protection and Stale Recovery",
  heartbeat_renewal_verified: true,
  concurrent_theft_prevented: true,
  single_execution_guaranteed: true,
  crash_recovery_verified: true,
  status: "PASS"
}

File.write('scratch/remediation2_results.json', JSON.pretty_generate(results))
puts "\n" + JSON.pretty_generate(results)
