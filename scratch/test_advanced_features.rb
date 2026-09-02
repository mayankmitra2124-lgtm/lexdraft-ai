# frozen_string_literal: true

require_relative '../db/database'
require_relative '../services/certificate_service'
require_relative '../services/gemini_service'
require_relative '../services/aggregation_service'

Database.init

puts "=== Testing Advanced Legal Features ==="

case_rec = Database.query("SELECT * FROM cases LIMIT 1").first
file_rec = Database.query("SELECT * FROM evidence_files LIMIT 1").first

abort("No sample case in database") unless case_rec
abort("No sample file in database") unless file_rec

puts "Test Case: #{case_rec['name']}"
puts "Test File: #{file_rec['original_name']}"

# 1. Test CertificateService
cert = CertificateService.generate_section_65b_certificate(case_rec, file_rec)
abort("Certificate ID missing") unless cert[:certificate_id]
abort("SHA-256 digest missing") unless cert[:sha256] && cert[:sha256].length == 64
abort("Certificate text missing") unless cert[:certificate_text]&.include?("65B")

puts " [PASS] Section 65B Certificate generated successfully with SHA-256: #{cert[:sha256][0..15]}..."

# 2. Test Zero-Tolerance Reverse Grounding
chronology = [
  {
    "date" => "2024-01-15",
    "event" => "Petitioner issued invoice for ₹40,00,000 to Respondent.",
    "supporting_document_ref" => "Bill.pdf, Page 1"
  }
]
raw_with_token = "On 15.01.2024, RA Bill submitted for amount ₹40,00,000 under contract."
raw_without_token = "Some unrelated document without numbers."

res_good = GeminiService.verify_reverse_grounding(chronology, [], raw_with_token)
abort("Reverse grounding failed on matching tokens") unless res_good["zero_tolerance_passed"]
puts " [PASS] Reverse Grounding verified tokens (Score: #{res_good['anti_hallucination_score']}%)"

res_drift = GeminiService.verify_reverse_grounding(chronology, [], raw_without_token)
abort("Reverse grounding should detect drift") if res_drift["zero_tolerance_passed"]
puts " [PASS] Anti-Hallucination Gate flagged drift (Status: #{chronology.first['grounding_status']})"

# 3. Test Statutory Limitation Clock
limitation = GeminiService.calculate_statutory_limitation(chronology, nil, case_rec)
days = limitation['days_remaining'] || limitation[:days_remaining]
abort("Limitation days remaining missing") unless days
puts " [PASS] Statutory Limitation Clock computed: #{days} days remaining (Status: #{limitation['status']})"

puts "\n=== ALL ADVANCED LEGAL FEATURES VERIFIED ==="
