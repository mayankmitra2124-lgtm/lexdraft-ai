# frozen_string_literal: true

require 'json'
require_relative '../db/database'
require_relative '../services/certificate_service'
require_relative '../services/aggregation_service'

Database.init

puts "\n========================================================"
puts " RUNNING REMEDIATION 9 — IDEMPOTENCY SEMANTICS TESTS"
puts "========================================================\n"

case_rec = Database.query_one("SELECT * FROM cases LIMIT 1")
file_rec = Database.query_one("SELECT * FROM evidence_files WHERE case_id = ? LIMIT 1", [case_rec['id']])

# 1. Certificate Idempotency
cert1 = CertificateService.generate_section_65b_certificate(case_rec, file_rec)
cert2 = CertificateService.generate_section_65b_certificate(case_rec, file_rec)

raise "Certificate generation non-idempotent" unless cert1[:certificate_id] == cert2[:certificate_id]
puts "[Pass] Certificate generation is deterministic & idempotent (Ref ID: #{cert1[:certificate_id]})."

# 2. Aggregation Idempotency
# Repeated aggregation call without changes should not append duplicate version rows
versions_before = Database.query("SELECT count(*) as c FROM master_summaries WHERE case_id = ?", [case_rec['id']]).first['c']
summary1 = AggregationService.aggregate_case_evidence(case_rec['id'])
versions_mid = Database.query("SELECT count(*) as c FROM master_summaries WHERE case_id = ?", [case_rec['id']]).first['c']
summary2 = AggregationService.aggregate_case_evidence(case_rec['id'])
versions_after = Database.query("SELECT count(*) as c FROM master_summaries WHERE case_id = ?", [case_rec['id']]).first['c']

raise "Aggregation created duplicate version on identical data" unless versions_mid == versions_after
puts "[Pass] Master summary aggregation is idempotent (Version count preserved at #{versions_after})."

results = {
  test_name: "Remediation 9: Certification & Aggregation Idempotency",
  certificate_deterministic_id: cert1[:certificate_id],
  certificate_idempotent: true,
  summary_version_stable: true,
  status: "PASS"
}

File.write('scratch/remediation9_results.json', JSON.pretty_generate(results))
puts "\n" + JSON.pretty_generate(results)
