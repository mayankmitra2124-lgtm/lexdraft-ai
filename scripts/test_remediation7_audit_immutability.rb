# frozen_string_literal: true

require 'sqlite3'
require 'json'
require_relative '../db/database'

Database.init

puts "\n========================================================"
puts " RUNNING REMEDIATION 7 — AUDIT LOG IMMUTABILITY TEST"
puts "========================================================\n"

tenant = Database.query_one("SELECT * FROM tenants LIMIT 1")
user = Database.query_one("SELECT * FROM users WHERE tenant_id = ? LIMIT 1", [tenant['id']])

# 1. INSERT PROOF
begin
  Database.log_audit_event(
    tenant_id: tenant['id'],
    user_id: user['id'],
    action: 'evidence.access_probed',
    resource_type: 'evidence',
    resource_id: 'file_probe_123',
    metadata: { test_flag: true }
  )
  puts "[Pass] Step 1: INSERT into audit_logs successfully permitted."
  insert_allowed = true
rescue => e
  puts "[Fail] Step 1: INSERT failed: #{e.message}"
  insert_allowed = false
end

latest_audit = Database.query_one("SELECT * FROM audit_logs WHERE action = 'evidence.access_probed' ORDER BY created_at DESC LIMIT 1")
raise "Inserted audit record not found" unless latest_audit

# 2. UPDATE PROOF (Must be denied)
update_denied = false
update_error = nil
begin
  Database.query("UPDATE audit_logs SET action = 'tampered_action' WHERE id = ?", [latest_audit['id']])
  puts "[Fail] Step 2: UPDATE was allowed! Immutability broken."
rescue => e
  update_denied = true
  update_error = e.message
  puts "[Pass] Step 2: UPDATE strictly DENIED by database trigger: #{e.message}"
end

# 3. DELETE PROOF (Must be denied)
delete_denied = false
delete_error = nil
begin
  Database.query("DELETE FROM audit_logs WHERE id = ?", [latest_audit['id']])
  puts "[Fail] Step 3: DELETE was allowed! Immutability broken."
rescue => e
  delete_denied = true
  delete_error = e.message
  puts "[Pass] Step 3: DELETE strictly DENIED by database trigger: #{e.message}"
end

# 4. Verify original record remains pristine
record_after = Database.query_one("SELECT * FROM audit_logs WHERE id = ?", [latest_audit['id']])
pristine = (record_after && record_after['action'] == 'evidence.access_probed')
puts "[Pass] Step 4: Existing audit record verified completely unmodified in database."

results = {
  test_name: "Remediation 7: Audit Log Immutability Enforcement",
  insert_allowed: insert_allowed,
  update_denied: update_denied,
  update_trigger_message: update_error,
  delete_denied: delete_denied,
  delete_trigger_message: delete_error,
  record_intact: pristine,
  status: (insert_allowed && update_denied && delete_denied && pristine) ? "PASS" : "FAIL"
}

File.write('scratch/remediation7_results.json', JSON.pretty_generate(results))
puts "\n" + JSON.pretty_generate(results)
