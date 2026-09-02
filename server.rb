# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

require 'webrick'
require 'json'
require 'fileutils'
require 'uri'
require 'time'
require 'cgi'
require 'thread'

require_relative 'db/database'
require_relative 'db/seed_data'
require_relative 'services/storage_service'
require_relative 'services/media_chunker'
require_relative 'services/transcription_service'
require_relative 'services/certificate_service'
require_relative 'services/gemini_service'
require_relative 'services/aggregation_service'

# Initialize DB & Seed Data
Database.init
StorageService.init
SeedData.seed!

# Global background worker queue
WORKER_QUEUE = Queue.new

# Re-enqueue unfinished file extractions on startup
Thread.new do
  sleep 0.5
  begin
    unfinished = Database.connection.execute("SELECT id, case_id FROM evidence_files WHERE status IN ('Queued', 'Processing')")
    unfinished.each do |file|
      Database.update_file_status(file['id'], 'Queued', progress: 0)
      WORKER_QUEUE.push({ case_id: file['case_id'], file_id: file['id'] })
      puts "[Startup Recovery] Re-enqueued unfinished file: #{file['id']} for case: #{file['case_id']}"
    end
  rescue => e
    puts "[Startup Recovery Error] #{e.message}"
  end
end

SSE_CLIENTS_MUTEX = Mutex.new
SSE_CLIENTS = {} # case_id => array of response output streams

# Broadcast helper for live SSE updates
def broadcast_case_event(case_id, event_type, data)
  payload = "event: #{event_type}\ndata: #{JSON.generate(data)}\n\n"
  SSE_CLIENTS_MUTEX.synchronize do
    clients = SSE_CLIENTS[case_id] || []
    clients.reject! do |stream|
      begin
        stream.write(payload)
        stream.flush
        false
      rescue => e
        true
      end
    end
  end
end

# Background Worker Thread for Parallel/Queued File Processing
Thread.new do
  loop do
    task = WORKER_QUEUE.pop
    case_id = task[:case_id]
    file_id = task[:file_id]

    begin
      file_record = Database.get_file(file_id)
      case_record = Database.get_case(case_id)

      next unless file_record && case_record

      puts "[Worker] Starting processing for #{file_record['original_name']} (Case: #{case_id})"

      # Phase 1: Processing Status & Media Chunking
      Database.update_file_status(file_id, 'Processing', progress: 20)
      broadcast_case_event(case_id, 'file_progress', { 'file_id' => file_id, 'status' => 'Processing', 'progress' => 20 })

      # Perform chunking if required
      chunks = []
      if MediaChunker.should_chunk?(file_record)
        chunks = MediaChunker.chunk_file(file_record)
      end

      # Phase 1.5: Speech-to-Text (ASR) with Diarization & Timestamps (Before Multi-Model Engine)
      if TranscriptionService.is_transcription_required?(file_record)
        Database.update_file_status(file_id, 'Transcribing (ASR)', progress: 35)
        broadcast_case_event(case_id, 'file_progress', { 'file_id' => file_id, 'status' => 'Transcribing (ASR)', 'progress' => 35 })
        
        transcript_result = TranscriptionService.transcribe(case_record, file_record, chunks)
        if transcript_result && transcript_result[:full_text]
          file_record['transcript'] = transcript_result[:full_text]
        end

        Database.update_file_status(file_id, 'Processing (ASR Complete)', progress: 55)
        broadcast_case_event(case_id, 'file_progress', { 'file_id' => file_id, 'status' => 'Processing (ASR Complete)', 'progress' => 55 })
      else
        Database.update_file_status(file_id, 'Processing', progress: 50)
        broadcast_case_event(case_id, 'file_progress', { 'file_id' => file_id, 'status' => 'Processing', 'progress' => 50 })
      end

      # Phase 2: AI Multi-Model Structured Extraction (Ingests verbatim transcript for audio/video)
      extraction = GeminiService.extract_evidence(case_record, file_record, chunks)

      is_critical = extraction['chronology']&.any? { |ev| ev['is_critical_flag'] == true || ev['is_critical_flag'].to_s == 'true' }

      Database.save_extraction(file_id, case_id, extraction)
      Database.update_file_status(file_id, 'Processing', progress: 85, is_critical: is_critical)
      broadcast_case_event(case_id, 'file_progress', { 'file_id' => file_id, 'status' => 'Processing', 'progress' => 85 })

      # Phase 3: Aggregation Step (Synthesizes Master Summary & Diff)
      master_summary = AggregationService.aggregate_case_evidence(case_id, file_id)

      Database.update_file_status(file_id, 'Complete', progress: 100, is_critical: is_critical)
      broadcast_case_event(case_id, 'file_completed', {
        'file_id' => file_id,
        'status' => 'Complete',
        'progress' => 100,
        'is_critical' => is_critical,
        'summary_version' => master_summary ? master_summary['version'] : 1
      })

      puts "[Worker] Completed processing & aggregation for #{file_record['original_name']}"
    rescue => e
      puts "[Worker] Error processing file #{file_id}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      Database.update_file_status(file_id, 'Failed', progress: 0, error_message: e.message)
      broadcast_case_event(case_id, 'file_failed', { 'file_id' => file_id, 'status' => 'Failed', 'error' => e.message })
    end
  end
end

# WEBrick Custom Dispatcher Servlet
class CaseOrganizerServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    handle_request(req, res)
  end

  def do_POST(req, res)
    handle_request(req, res)
  end

  def do_PUT(req, res)
    handle_request(req, res)
  end

  def do_DELETE(req, res)
    handle_request(req, res)
  end

  def do_OPTIONS(req, res)
    set_cors_headers(res)
    res.status = 200
  end

  private

  def set_cors_headers(res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With'
  end

  def json_response(res, data, status = 200)
    set_cors_headers(res)
    res.status = status
    res['Content-Type'] = 'application/json; charset=utf-8'
    res.body = JSON.generate(data)
  end

  def parse_json_body(req)
    JSON.parse(req.body) rescue {}
  end

  def handle_request(req, res)
    path = req.path.chomp('/').force_encoding('UTF-8')
    method = req.request_method

    # SSE Event Stream Endpoint
    if method == 'GET' && path =~ %r{^/api/cases/([^/]+)/events$}
      case_id = $1
      handle_sse_stream(case_id, req, res)
      return
    end

    set_cors_headers(res)

    # API Routes
    begin
      if method == 'GET' && path == '/api/cases'
        json_response(res, Database.list_cases)

      elsif method == 'POST' && path == '/api/cases'
        body = parse_json_body(req)
        created = Database.create_case(body)
        json_response(res, created, 201)

      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)$}
        case_id = $1
        c = Database.get_case(case_id)
        if c
          json_response(res, c)
        else
          json_response(res, { 'error' => 'Case not found' }, 404)
        end

      elsif method == 'PUT' && path =~ %r{^/api/cases/([^/]+)$}
        case_id = $1
        body = parse_json_body(req)
        updated = Database.update_case(case_id, body)
        json_response(res, updated)

      elsif method == 'DELETE' && path =~ %r{^/api/cases/([^/]+)$}
        case_id = $1
        Database.delete_case(case_id)
        json_response(res, { 'success' => true })

      # Evidence Files API
      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/files$}
        case_id = $1
        files = Database.list_files(case_id)
        json_response(res, files)

      elsif method == 'POST' && path =~ %r{^/api/cases/([^/]+)/evidence$}
        case_id = $1
        handle_file_upload(case_id, req, res)

      elsif method == 'POST' && path =~ %r{^/api/files/([^/]+)/retry$}
        file_id = $1
        file_rec = Database.get_file(file_id)
        if file_rec
          Database.update_file_status(file_id, 'Queued', progress: 0, error_message: nil)
          WORKER_QUEUE.push({ case_id: file_rec['case_id'], file_id: file_id })
          json_response(res, { 'success' => true, 'status' => 'Queued' })
        else
          json_response(res, { 'error' => 'File not found' }, 404)
        end

      elsif method == 'DELETE' && path =~ %r{^/api/files/([^/]+)$}
        file_id = $1
        file_rec = Database.get_file(file_id)
        if file_rec
          case_id = file_rec['case_id']
          Database.delete_file(file_id)
          StorageService.delete_file(file_rec['storage_path'])
          # Re-aggregate remaining files
          AggregationService.aggregate_case_evidence(case_id)
          json_response(res, { 'success' => true })
        else
          json_response(res, { 'error' => 'File not found' }, 404)
        end

      # Master Summary & Diff APIs
      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/summary$}
        case_id = $1
        summary = Database.get_latest_summary(case_id)
        json_response(res, summary || {})

      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/diffs$}
        case_id = $1
        diffs = Database.list_diffs(case_id)
        json_response(res, diffs)

      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/extractions/([^/]+)$}
        parts = path.split('/')
        file_id = parts[5]
        ext = Database.get_extraction(file_id)
        if ext
          json_response(res, ext)
        else
          json_response(res, { 'error' => 'Extraction not found' }, 404)
        end

      # Section 65B (IEA) / Section 63 (BSA, 2023) Electronic Evidence Certificate API
      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/files/([^/]+)/certificate$}
        case_id = $1
        file_id = $2
        case_record = Database.get_case(case_id)
        file_record = Database.get_file(file_id)

        if case_record && file_record
          cert = CertificateService.generate_section_65b_certificate(case_record, file_record)
          json_response(res, cert)
        else
          json_response(res, { 'error' => 'Case or evidence file not found' }, 404)
        end

      # Notifications API
      elsif method == 'GET' && path == '/api/notifications'
        notifs = Database.list_notifications(30)
        json_response(res, notifs)

      elsif method == 'POST' && path == '/api/notifications/read'
        body = parse_json_body(req)
        Database.mark_notifications_read(body['case_id'])
        json_response(res, { 'success' => true })

      # Cost & Performance Optimization Analytics API
      elsif method == 'GET' && path == '/api/analytics/cost-performance'
        analytics = Database.get_performance_analytics
        json_response(res, analytics)

      # Settings API
      elsif method == 'GET' && path == '/api/settings'
        has_key = !GeminiService.api_key.nil? && !GeminiService.api_key.empty?
        json_response(res, {
          'ai_api_key_configured' => has_key,
          'ai_model' => GeminiService::DEFAULT_MODEL,
          'app_version' => '1.0.0-PROD',
          'analytics' => Database.get_performance_analytics
        })

      elsif method == 'POST' && path == '/api/settings'
        body = parse_json_body(req)
        if body.key?('ai_api_key')
          Database.set_setting('gemini_api_key', body['ai_api_key'])
        end
        json_response(res, { 'success' => true })

      # Seed reset API
      elsif method == 'POST' && path == '/api/seed/reset'
        SeedData.seed!
        json_response(res, { 'success' => true })

      else
        # Static Assets or 404
        serve_static_or_404(req, res)
      end
    rescue => e
      puts "[Server Error] #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      json_response(res, { 'error' => e.message }, 500)
    end
  end

  def handle_file_upload(case_id, req, res)
    case_rec = Database.get_case(case_id)
    unless case_rec
      json_response(res, { 'error' => 'Case not found' }, 404)
      return
    end

    content_type = req['content-type'].to_s

    uploaded_files = []

    if content_type.include?('multipart/form-data')
      # Parse multipart payload
      boundary = nil
      if content_type =~ /boundary=(?:"([^"]+)"|([^;\s]+))/i
        boundary = $1 || $2
      end
      unless boundary
        json_response(res, { 'error' => 'No multipart boundary found in request headers' }, 400)
        return
      end
      body_io = StringIO.new(req.body)
      
      # Use WEBrick multipart parser or regex extraction
      parts = WEBrick::HTTPUtils.parse_form_data(body_io, boundary)
      parts.each do |key, val|
        next unless val
        
        # Traverse FormData linked list (WEBrick chaining for multi-file fields)
        form_datas = []
        if val.respond_to?(:each_data)
          val.each_data { |fd| form_datas << fd }
        else
          form_datas << val
        end
        
        form_datas.each do |part|
          next unless part.respond_to?(:filename) && part.filename && !part.filename.empty?
          
          fname = part.filename
          file_bytes = part.to_s
          quota = StorageService.check_case_quota(case_id, file_bytes.bytesize)
          
          unless quota['allowed']
            json_response(res, { 'error' => quota['reason'] }, 400)
            return
          end

          saved_info = StorageService.save_stream(case_id, fname, file_bytes, part['content-type'])
          
          file_rec = Database.create_file({
            'case_id' => case_id,
            'filename' => saved_info['filename'],
            'original_name' => fname,
            'file_type' => saved_info['file_type'],
            'file_size' => saved_info['file_size'],
            'storage_path' => saved_info['storage_path'],
            'status' => 'Queued',
            'progress' => 0
          })

          WORKER_QUEUE.push({ case_id: case_id, file_id: file_rec['id'] })
          uploaded_files << file_rec
        end
      end
    elsif content_type.include?('application/json')
      # JSON Upload payload (simulated/text or base64 file)
      body = parse_json_body(req)
      filename = body['filename'] || "evidence_#{Time.now.to_i}.txt"
      content = body['content'] || body['text'] || ""
      file_type_hint = body['file_type'] || 'text/plain'

      quota = StorageService.check_case_quota(case_id, content.bytesize)
      unless quota['allowed']
        json_response(res, { 'error' => quota['reason'] }, 400)
        return
      end

      saved_info = StorageService.save_stream(case_id, filename, content, file_type_hint)

      file_rec = Database.create_file({
        'case_id' => case_id,
        'filename' => saved_info['filename'],
        'original_name' => filename,
        'file_type' => saved_info['file_type'],
        'file_size' => saved_info['file_size'],
        'storage_path' => saved_info['storage_path'],
        'status' => 'Queued',
        'progress' => 0
      })

      WORKER_QUEUE.push({ case_id: case_id, file_id: file_rec['id'] })
      uploaded_files << file_rec
    end

    json_response(res, { 'success' => true, 'files' => uploaded_files }, 201)
  end

  def handle_sse_stream(case_id, req, res)
    res.status = 200
    res['Content-Type'] = 'text/event-stream'
    res['Cache-Control'] = 'no-cache'
    res['Connection'] = 'keep-alive'
    res['Access-Control-Allow-Origin'] = '*'

    # Initial ping
    res.body = "event: connected\ndata: {\"case_id\":\"#{case_id}\"}\n\n"
  end

  def serve_static_or_404(req, res)
    clean_path = req.path.gsub(%r{^/+}, '')
    clean_path = 'index.html' if clean_path.empty?

    # Check public folder
    public_dir = File.expand_path('../public', __FILE__)
    public_file = File.join(public_dir, clean_path)
    if File.exist?(public_file) && !File.directory?(public_file)
      res.status = 200
      res['Content-Type'] = mime_for(public_file)
      res['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
      res['Pragma'] = 'no-cache'
      res['Expires'] = '0'
      res.body = File.read(public_file)
      return
    end

    # Check uploads folder for direct media/document preview
    if req.path =~ %r{^/uploads/}
      uploads_dir = File.expand_path('../', __FILE__)
      upload_file = File.join(uploads_dir, clean_path)
      if File.exist?(upload_file) && !File.directory?(upload_file)
        res.status = 200
        res['Content-Type'] = mime_for(upload_file)
        res.body = File.read(upload_file)
        return
      end
    end

    # Fallback to index.html for Single Page App routing
    index_file = File.join(public_dir, 'index.html')
    if File.exist?(index_file)
      res.status = 200
      res['Content-Type'] = 'text/html; charset=utf-8'
      res.body = File.read(index_file)
    else
      res.status = 404
      res.body = "Not Found"
    end
  end

  def mime_for(file_path)
    case File.extname(file_path).downcase
    when '.html' then 'text/html; charset=utf-8'
    when '.css'  then 'text/css; charset=utf-8'
    when '.js'   then 'application/javascript; charset=utf-8'
    when '.json' then 'application/json; charset=utf-8'
    when '.png'  then 'image/png'
    when '.jpg', '.jpeg' then 'image/jpeg'
    when '.svg'  then 'image/svg+xml'
    when '.pdf'  then 'application/pdf'
    when '.txt'  then 'text/plain; charset=utf-8'
    when '.mp3'  then 'audio/mpeg'
    when '.mp4'  then 'video/mp4'
    else 'application/octet-stream'
    end
  end
end

# Server configuration
PORT = (ENV['PORT'] || 8080).to_i

server = WEBrick::HTTPServer.new(
  Port: PORT,
  BindAddress: '0.0.0.0',
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO)
)

server.mount('/', CaseOrganizerServlet)

trap('INT') { server.shutdown }
trap('TERM') { server.shutdown }

puts "========================================================"
puts "  Case Evidence Organizer (Feature 1) Running!"
puts "  Access Application at: http://localhost:#{PORT}"
puts "========================================================"

server.start
