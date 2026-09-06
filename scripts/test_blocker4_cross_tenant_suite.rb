# frozen_string_literal: true

require 'json'
require 'stringio'
require_relative '../server'

Database.init
StorageService.init

app = LexDraftApp.new

# Query User A and User B from different tenants
user_a = Database.query_one("SELECT u.*, s.token FROM users u JOIN user_sessions s ON u.id = s.user_id WHERE s.token IS NOT NULL LIMIT 1")
user_b = Database.query_one("SELECT u.*, s.token FROM users u JOIN user_sessions s ON u.id = s.user_id WHERE s.token IS NOT NULL AND u.tenant_id != ? LIMIT 1", [user_a['tenant_id']])

case_b = Database.query_one("SELECT * FROM cases WHERE tenant_id = ? LIMIT 1", [user_b['tenant_id']])
file_b = Database.query_one("SELECT * FROM evidence_files WHERE case_id = ? LIMIT 1", [case_b['id']])
ext_b = Database.query_one("SELECT * FROM extractions WHERE case_id = ? LIMIT 1", [case_b['id']])
sum_b = Database.query_one("SELECT * FROM master_summaries WHERE case_id = ? LIMIT 1", [case_b['id']])

token_a = user_a['token']

def rack_request(app, method, path, token = nil, body = nil)
  input = body ? StringIO.new(body.is_a?(String) ? body : body.to_json) : StringIO.new('')
  env = {
    'REQUEST_METHOD' => method.to_s.upcase,
    'PATH_INFO' => path,
    'QUERY_STRING' => '',
    'rack.input' => input,
    'CONTENT_TYPE' => body ? 'application/json' : '',
    'HTTP_AUTHORIZATION' => token ? "Bearer #{token}" : nil
  }
  status, headers, body_parts = app.call(env)
  body_str = body_parts.join
  parsed = begin
    JSON.parse(body_str)
  rescue
    body_str
  end
  { status: status, headers: headers, body: parsed }
end

attacks = [
  {
    id: "ATTACK-CASE-ACCESS",
    resource: "Case Metadata",
    method: :get,
    path: "/api/cases/#{case_b['id']}"
  },
  {
    id: "ATTACK-CASE-FILES-LIST",
    resource: "Case Evidence File List",
    method: :get,
    path: "/api/cases/#{case_b['id']}/files"
  },
  {
    id: "ATTACK-EVIDENCE-FILE-DETAIL",
    resource: "Evidence File Detail",
    method: :get,
    path: "/api/cases/#{case_b['id']}/files/#{file_b['id']}"
  },
  {
    id: "ATTACK-DOWNLOAD-PRESIGNED-URL",
    resource: "Object Storage Download / Presigned URL",
    method: :get,
    path: "/api/cases/#{case_b['id']}/files/#{file_b['id']}/download"
  },
  {
    id: "ATTACK-EXTRACTION-ACCESS",
    resource: "AI Extraction",
    method: :get,
    path: "/api/cases/#{case_b['id']}/files/#{file_b['id']}/extractions"
  },
  {
    id: "ATTACK-MASTER-SUMMARY",
    resource: "Master Summary Narrative",
    method: :get,
    path: "/api/cases/#{case_b['id']}/summary"
  },
  {
    id: "ATTACK-CERTIFICATE-GEN",
    resource: "Section 65B Legal Certificate",
    method: :get,
    path: "/api/cases/#{case_b['id']}/files/#{file_b['id']}/certificate"
  },
  {
    id: "ATTACK-DIFF-LOGS",
    resource: "Case Diff Logs",
    method: :get,
    path: "/api/cases/#{case_b['id']}/diffs"
  },
  {
    id: "ATTACK-PROGRESS-POLLING",
    resource: "Case Ingestion Progress",
    method: :get,
    path: "/api/cases/#{case_b['id']}/progress"
  },
  {
    id: "ATTACK-SSE-EVENT-STREAM",
    resource: "Case Event Stream (SSE)",
    method: :get,
    path: "/api/cases/#{case_b['id']}/events"
  },
  {
    id: "ATTACK-INJECT-EVIDENCE",
    resource: "Unauthorized Evidence Injection",
    method: :post,
    path: "/api/cases/#{case_b['id']}/upload",
    body: { filename: "malicious.pdf" }
  },
  {
    id: "ATTACK-DELETE-CASE",
    resource: "Unauthorized Case Destruction",
    method: :delete,
    path: "/api/cases/#{case_b['id']}"
  }
]

results = []
all_denied = true

attacks.each do |atk|
  res = rack_request(app, atk[:method], atk[:path], token_a, atk[:body])
  status = res[:status]
  denied = (status == 403 || status == 404)
  all_denied = false unless denied

  results << {
    test_id: atk[:id],
    target_resource: atk[:resource],
    method: atk[:method].to_s.upcase,
    path: atk[:path],
    attacker_tenant: user_a['tenant_id'],
    victim_tenant: user_b['tenant_id'],
    expected_status: "403 or 404",
    actual_status: status,
    denial_without_disclosure: denied,
    response_snippet: res[:body].is_a?(Hash) ? res[:body] : res[:body].to_s[0..80],
    status: denied ? "PASS" : "FAIL"
  }
end

# Also test direct download with fabricated token
tampered_res = rack_request(app, :get, "/api/files/#{file_b['id']}/download?token=forged_token_123", token_a)
tampered_denied = (tampered_res[:status] == 403 || tampered_res[:status] == 404)
results << {
  test_id: "ATTACK-FORGED-OBJECT-STORAGE-TOKEN",
  target_resource: "Direct Object Storage Download Endpoint",
  method: "GET",
  path: "/api/files/#{file_b['id']}/download?token=forged_token_123",
  attacker_tenant: user_a['tenant_id'],
  victim_tenant: user_b['tenant_id'],
  expected_status: "403 or 404",
  actual_status: tampered_res[:status],
  denial_without_disclosure: tampered_denied,
  response_snippet: tampered_res[:body],
  status: tampered_denied ? "PASS" : "FAIL"
}

output = {
  suite_name: "API-Level Tenant Isolation & Cross-Tenant Attack Suite",
  user_a: { id: user_a['id'], tenant_id: user_a['tenant_id'] },
  user_b: { id: user_b['id'], tenant_id: user_b['tenant_id'] },
  victim_case_id: case_b['id'],
  total_attacks: results.size,
  all_attacks_denied_without_disclosure: all_denied && tampered_denied,
  attacks: results
}

File.write(File.expand_path('../../scratch/blocker4_results.json', __FILE__), JSON.pretty_generate(output))
puts JSON.pretty_generate(output)
