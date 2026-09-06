# frozen_string_literal: true

require 'socket'
require 'uri'
require 'net/http'

PORT = 8080
HOST = 'localhost'

def send_raw_http(request_line)
  s = TCPSocket.new(HOST, PORT)
  s.write("#{request_line}\r\nHost: #{HOST}\r\nConnection: close\r\n\r\n")
  response = s.read
  s.close
  
  first_line = response.lines.first.to_s.strip
  [first_line, response]
end

probes = [
  "GET /../case_organizer.db HTTP/1.1",
  "GET /..%2fcase_organizer.db HTTP/1.1",
  "GET /%2e%2e%2fcase_organizer.db HTTP/1.1",
  "GET /%2e%2e/case_organizer.db HTTP/1.1",
  "GET /%252e%252e%252fcase_organizer.db HTTP/1.1",
  "GET /..\\case_organizer.db HTTP/1.1",
  "GET /..%5ccase_organizer.db HTTP/1.1",
  "GET /uploads/../case_organizer.db HTTP/1.1",
  "GET /uploads/..%2fcase_organizer.db HTTP/1.1",
  "GET /uploads/%2e%2e%2fcase_organizer.db HTTP/1.1",
  "GET /uploads/%252e%252e%252fcase_organizer.db HTTP/1.1",
  "GET /uploads/..\\case_organizer.db HTTP/1.1",
  "GET /uploads/..%5ccase_organizer.db HTTP/1.1",
  "GET /server.rb HTTP/1.1",
  "GET /.env HTTP/1.1",
  "GET /etc/passwd HTTP/1.1"
]

puts "\n=== PROBING TRAVERSAL AND ENCODING RESISTANCE ==="
probes.each do |req|
  status, body = send_raw_http(req)
  leaked = body.include?("SQLite format 3") || body.include?("CaseOrganizerServlet") || body.include?("root:x:")
  puts format("%-50s -> %-20s (Leaked: %s)", req.sub(" HTTP/1.1", ""), status, leaked)
  if leaked
    puts "CRITICAL LEAK DETECTED ON #{req}!"
    exit 1
  end
end
