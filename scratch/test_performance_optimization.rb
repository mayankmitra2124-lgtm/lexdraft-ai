# frozen_string_literal: true

require_relative '../db/database'
require_relative '../services/gemini_service'

Database.init

puts "=== Testing Engineering Performance & Cost Optimization ==="

case_rec = Database.query("SELECT * FROM cases LIMIT 1").first
file_rec = Database.query("SELECT * FROM evidence_files LIMIT 1").first

# 1. First run: Generates and caches
puts "Pass 1 (Fresh extraction)..."
t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
res1 = GeminiService.extract_evidence(case_rec, file_rec)
d1 = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t1) * 1000).round
puts " [PASS] Pass 1 finished in #{d1}ms."

# 2. Second run: Must hit SHA-256 Deduplication Cache!
puts "Pass 2 (Identical SHA-256 cache hit)..."
t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
res2 = GeminiService.extract_evidence(case_rec, file_rec)
d2 = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t2) * 1000).round

abort("Cache hit flag not set!") unless res2['is_cached_hit']
puts " [PASS] Pass 2 hit SHA-256 cache in #{d2}ms (Latency reduction: #{((d1 - d2).to_f / [d1, 1].max * 100).round}%)"

# 3. Check Analytics
analytics = Database.get_performance_analytics
abort("Analytics cache count is zero") if analytics['cache_entries'] == 0
puts " [PASS] Analytics: #{analytics['total_tokens_saved']} tokens saved, ₹#{analytics['estimated_cost_saved_inr']} saved."
puts " [PASS] Efficiency ratio: #{analytics['efficiency_ratio']}"

puts "\n=== ALL PERFORMANCE & COST OPTIMIZATION TESTS PASSED ==="
