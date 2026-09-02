# frozen_string_literal: true

require_relative '../db/database'
require_relative '../services/transcription_service'
require_relative '../services/gemini_service'

Database.init

puts "=== Testing Speech-to-Text ASR Pipeline ==="

# 1. Test is_transcription_required?
audio_file = { 'file_type' => 'Audio', 'original_name' => 'Call_Recording_Demand.mp3' }
video_file = { 'file_type' => 'Video', 'original_name' => 'Site_Inspection_Video.mp4' }
pdf_file   = { 'file_type' => 'PDF',   'original_name' => 'Agreement.pdf' }

abort("Audio check failed") unless TranscriptionService.is_transcription_required?(audio_file)
abort("Video check failed") unless TranscriptionService.is_transcription_required?(video_file)
abort("PDF check should be false") if TranscriptionService.is_transcription_required?(pdf_file)
puts " [PASS] is_transcription_required? classification verified."

# 2. Test ASR Transcription generation
case_record = {
  'name' => 'Apex Infrastructure Ltd. v. Delhi Metro Real Estate Pvt. Ltd.',
  'objective' => 'Commercial recovery under Section 9 Arbitration Act',
  'parties_info' => 'Apex Infrastructure Ltd. (Claimant) vs. Delhi Metro Real Estate Pvt. Ltd. (Respondent)',
  'court_name' => 'High Court of Delhi'
}

file_record = {
  'id' => 'test_audio_001',
  'case_id' => 'case_test_123',
  'original_name' => 'Telephonic_Demand_Call.mp3',
  'file_type' => 'Audio',
  'storage_path' => '/tmp/dummy_audio.mp3'
}

result = TranscriptionService.transcribe(case_record, file_record, [])
abort("Result is nil") if result.nil?
abort("Full text missing") if result[:full_text].nil? || result[:full_text].empty?
abort("Segments missing") if result[:segments].empty?

puts " [PASS] ASR transcription generated #{result[:segments].size} segments."
puts " Sample segment: #{result[:segments].first.inspect}"

# 3. Verify that GeminiService ingests this transcript for chronology
file_record['transcript'] = result[:full_text]
extraction = GeminiService.generate_domain_extraction(case_record, file_record, result[:full_text])

abort("Chronology missing in extraction") if extraction['chronology'].nil? || extraction['chronology'].empty?
first_event = extraction['chronology'].first
puts " [PASS] Chronology extracted from transcript: #{first_event['event']}"
puts " Supporting reference: #{first_event['supporting_document_ref']}"

puts "\n=== ALL ASR SPEECH-TO-TEXT CHECKS PASSED ==="
