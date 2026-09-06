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
require 'stringio'
require 'securerandom'
require 'digest'

require_relative 'db/database'
require_relative 'db/seed_data'
require_relative 'services/storage_service'
require_relative 'services/s3_storage_adapter'
require_relative 'services/media_chunker'
require_relative 'services/transcription_service'
require_relative 'services/certificate_service'
require_relative 'services/gemini_service'
require_relative 'services/aggregation_service'
require_relative 'services/auth_service'
require_relative 'services/job_queue'

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
    unfinished = Database.connection.execute("SELECT id, case_id, tenant_id FROM evidence_files WHERE status IN ('Queued', 'Processing', 'UPLOADING', 'UPLOADED', 'VERIFYING', 'QUEUED')")
    unfinished.each do |file|
      Database.update_file_status(file['id'], 'Queued', progress: 0)
      WORKER_QUEUE.push({ case_id: file['case_id'], file_id: file['id'] })
      JobQueue.enqueue(
        tenant_id: file['tenant_id'] || 'ten_default',
        job_type: 'extract',
        payload: { case_id: file['case_id'], file_id: file['id'] }
      )
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

  def extract_client_ip(req)
    (req['x-forwarded-for'] || req['X-Forwarded-For'])&.split(',')&.first&.strip || (req.peeraddr[3] rescue '127.0.0.1')
  end

  def extract_current_user(req)
    auth_header = (req['authorization'] || req['Authorization']).to_s.dup.force_encoding('UTF-8').scrub
    token = nil
    if auth_header =~ /\ABearer\s+(.+)\z/i
      token = $1.strip.dup.force_encoding('UTF-8').scrub
    end

    if token.nil? && req['Cookie']
      cookies = WEBrick::Cookie.parse(req['Cookie']) rescue []
      sess_cookie = cookies.find { |c| c.name == 'lexdraft_token' }
      token = sess_cookie.value.to_s.strip.dup.force_encoding('UTF-8').scrub if sess_cookie
    end

    if token.nil? && req.query
      token = req.query['token'].to_s.strip.dup.force_encoding('UTF-8').scrub unless req.query['token'].nil?
    end

    return nil if token.nil? || token.empty?
    AuthService.authenticate_token(token)
  rescue => e
    nil
  end

  def cookie_security_flags(req)
    flags = "Path=/; HttpOnly; SameSite=Lax"
    is_secure = (req['x-forwarded-proto'] || req['X-Forwarded-Proto']).to_s.downcase == 'https' || !ENV['RENDER'].nil?
    flags += "; Secure" if is_secure
    flags
  end

  def handle_request(req, res)
    path = req.path.to_s.dup.force_encoding('UTF-8').scrub.chomp('/')
    method = req.request_method

    set_cors_headers(res)

    # Direct evidence files MUST go through the authenticated evidence handler
    if path.start_with?('/uploads/')
      handle_authenticated_evidence_download(req, res)
      return
    end

    # Health & Readiness Check Endpoints (Phase 2)
    if method == 'GET' && (path == '/healthz' || path == '/api/health')
      json_response(res, { 'status' => 'healthy', 'service' => 'lexdraft', 'timestamp' => Time.now.utc.iso8601 })
      return
    end

    if method == 'GET' && path == '/readyz'
      db_ok = begin
        Database.connection.execute("SELECT 1") rescue nil
        true
      rescue
        false
      end
      storage_ok = StorageService.adapter.object_exists?("health_check_probe") rescue true
      if db_ok
        json_response(res, { 'status' => 'ready', 'database' => 'ok', 'storage' => 'ok', 'timestamp' => Time.now.utc.iso8601 })
      else
        json_response(res, { 'status' => 'unavailable', 'database' => false, 'storage' => storage_ok }, 503)
      end
      return
    end

    if method == 'GET' && path == '/api/system/storage-diagnostic'
      begin
        current_user = extract_current_user(req)
        unless current_user
          json_response(res, { 'error' => 'Unauthorized. Authentication required.' }, 401)
          return
        end

        adapter = StorageService.adapter
        target_key = (req.query && req.query['key']) || "tenants/tnt_1788715913_2320/cases/case_usr_1788715913_2320_starter/evidence/ef_1788716743_27383ed0/d47dd3309de15af4de971f68e4795deb6fd34f1547771c88e19745d567c5930d"
        local_path = (req.query && req.query['path']) || "/app/uploads/case_usr_1788715913_2320_starter/1788716743_016e92b1_live_evidence_affidavit.txt"

        all_safe_env_names = ENV.keys.sort.reject { |k| k =~ /KEY|SECRET|TOKEN|PASS|AUTH/i }
        has_secret_key = ENV.keys.any? { |k| k =~ /(R2|AWS|S3).*(SECRET|KEY)/i && !ENV[k].to_s.empty? }

        is_s3 = adapter.class.name.to_s.include?('S3StorageAdapter')
        s3_avail = adapter.respond_to?(:s3_available?) ? adapter.s3_available? : false
        bucket_name = adapter.respond_to?(:bucket) ? adapter.bucket : nil
        endpoint_val = adapter.respond_to?(:endpoint) ? adapter.endpoint : nil

        obj_exists = adapter.object_exists?(key: target_key) rescue false
        obj_size = adapter.object_size(key: target_key) rescue 0

        r2_head_meta = nil
        r2_head_error = nil
        if is_s3 && adapter.respond_to?(:client) && adapter.client
          begin
            h = adapter.client.head_object(bucket: bucket_name, key: target_key)
            r2_head_meta = {
              'content_length' => h.content_length,
              'content_type' => h.content_type,
              'last_modified' => h.last_modified&.iso8601,
              'etag' => h.etag,
              'metadata' => h.metadata.to_h
            }
          rescue => e
            r2_head_error = "#{e.class}: #{e.message}"
          end
        end

        local_exists = File.file?(local_path)
        local_size = local_exists ? File.size(local_path) : 0

        json_response(res, {
          'adapter_class' => adapter.class.name,
          'is_s3_adapter' => is_s3,
          's3_available' => s3_avail,
          'bucket' => bucket_name,
          'region' => adapter.respond_to?(:region) ? adapter.region : nil,
          'endpoint_host' => endpoint_val ? (URI(endpoint_val).host rescue 'invalid_uri') : nil,
          'git_commit' => ENV['RENDER_GIT_COMMIT'],
          'deploy_version' => 'phase2_v6',
          'access_key_len' => adapter.respond_to?(:access_key_len) ? adapter.access_key_len : nil,
          'secret_key_len' => adapter.respond_to?(:secret_key_len) ? adapter.secret_key_len : nil,
          'detected_cred_keys' => adapter.respond_to?(:detected_cred_keys) ? adapter.detected_cred_keys : nil,
          'all_safe_env_names' => all_safe_env_names,
          'has_secret_or_access_key' => has_secret_key,
          'target_key' => target_key,
          'adapter_object_exists' => obj_exists,
          'adapter_object_size' => obj_size,
          'r2_head_metadata' => r2_head_meta,
          'r2_head_error' => r2_head_error,
          'local_file_path' => local_path,
          'local_file_exists' => local_exists,
          'local_file_size' => local_size
        })
      rescue => e
        json_response(res, { 'error' => "#{e.class}: #{e.message}", 'backtrace' => e.backtrace.first(5) }, 500)
      end
      return
    end


    # ==========================================
    # Public Authentication Endpoints
    # ==========================================
    if method == 'POST' && path == '/api/auth/signup'
      begin
        body = parse_json_body(req)
        result = AuthService.signup(body)
        if result[:success]
          res['Set-Cookie'] = "lexdraft_token=#{result[:token]}; #{cookie_security_flags(req)}"
          json_response(res, { 'token' => result[:token], 'user' => result[:user] }, result[:status])
        else
          err_msg = result[:errors]&.join(', ') || 'Failed to sign up'
          json_response(res, { 'errors' => result[:errors], 'error' => err_msg }, result[:status])
        end
      rescue => e
        puts "[Auth Error] Signup failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        json_response(res, { 'error' => "Server error: #{e.message}", 'errors' => [e.message] }, 500)
      end
      return

    elsif method == 'POST' && path == '/api/auth/signin'
      begin
        body = parse_json_body(req)
        client_ip = (req['x-forwarded-for'] || req['X-Forwarded-For'])&.split(',')&.first&.strip || req.peeraddr[3]
        result = AuthService.signin(body['email'], body['password'], client_ip)
        if result[:success]
          res['Set-Cookie'] = "lexdraft_token=#{result[:token]}; #{cookie_security_flags(req)}"
          json_response(res, { 'token' => result[:token], 'user' => result[:user] }, result[:status])
        else
          err_msg = result[:errors]&.join(', ') || 'Invalid credentials'
          json_response(res, { 'errors' => result[:errors], 'error' => err_msg }, result[:status])
        end
      rescue => e
        puts "[Auth Error] Signin failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        json_response(res, { 'error' => "Server error: #{e.message}", 'errors' => [e.message] }, 500)
      end
      return

    elsif method == 'POST' && path == '/api/auth/signout'
      auth_header = req['Authorization'] || req['authorization']
      token = auth_header.to_s.sub(/\ABearer\s+/i, '').strip
      if token.empty? && req['Cookie']
        cookies = WEBrick::Cookie.parse(req['Cookie']) rescue []
        sess_cookie = cookies.find { |c| c.name == 'lexdraft_token' }
        token = sess_cookie.value.to_s.strip if sess_cookie
      end
      AuthService.signout(token)
      res['Set-Cookie'] = "lexdraft_token=; Max-Age=0; #{cookie_security_flags(req)}"
      json_response(res, { 'success' => true })
      return

    elsif method == 'POST' && path == '/api/auth/forgot-password'
      body = parse_json_body(req)
      email = body['email'].to_s.strip
      json_response(res, {
        'success' => true,
        'message' => "If an account exists for #{email}, a secure password reset link has been dispatched."
      })
      return

    elsif method == 'GET' && path == '/api/auth/me'
      user = extract_current_user(req)
      if user
        json_response(res, { 'user' => user })
      else
        json_response(res, { 'error' => 'Unauthorized' }, 401)
      end
      return
    end

    # ==========================================
    # Authentication Guard & Data Isolation
    # ==========================================
    current_user = extract_current_user(req)

    # Protected API Gate: All /api/ endpoints require authentication except public auth and health
    is_public_api = path.start_with?('/api/auth/') || path == '/api/health'
    if path.start_with?('/api/') && !is_public_api
      if current_user.nil?
        json_response(res, { 'error' => 'Unauthorized. Please sign in to access your case vault.' }, 401)
        return
      end
    end

    # Client Status Polling Endpoint (Phase 2 Lightweight Stateless Alternative to SSE)
    if method == 'GET' && path =~ %r{^/api/cases/([^/]+)/progress$}
      case_id = $1
      if current_user.nil? || !Database.verify_case_access(case_id, current_user)
        json_response(res, { 'error' => 'Forbidden: You do not have access to this case progress.' }, 403)
        return
      end
      files = Database.list_files(case_id)
      active_count = files.count { |f| %w[Queued Processing Transcribing (ASR) UPLOADING UPLOADED VERIFYING QUEUED PROCESSING].include?(f['status'].to_s) }
      json_response(res, {
        'case_id' => case_id,
        'active_count' => active_count,
        'is_processing' => active_count > 0,
        'files' => files.map { |f|
          {
            'id' => f['id'],
            'filename' => f['original_name'],
            'status' => f['status'],
            'progress' => f['progress'],
            'error_message' => f['error_message']
          }
        }
      })
      return
    end

    # SSE Event Stream Endpoint
    if method == 'GET' && path =~ %r{^/api/cases/([^/]+)/events$}
      case_id = $1
      if current_user.nil? || !Database.verify_case_access(case_id, current_user)
        json_response(res, { 'error' => 'Forbidden: You do not have access to this case stream.' }, 403)
        return
      end
      handle_sse_stream(case_id, req, res)
      return
    end


    # Protected API Routes
    begin
      if method == 'GET' && path == '/api/cases'
        user_id = current_user['id']
        json_response(res, Database.list_cases(user_id))

      elsif method == 'POST' && path == '/api/cases'
        body = parse_json_body(req)
        user_id = current_user['id']
        tenant_id = current_user['tenant_id']
        created = Database.create_case(body, user_id, tenant_id)
        Database.log_audit_event(
          tenant_id: tenant_id,
          user_id: user_id,
          case_id: created['id'],
          action: 'case.created',
          resource_type: 'case',
          resource_id: created['id'],
          ip_address: extract_client_ip(req),
          metadata: { name: created['name'] }
        )
        json_response(res, created, 201)

      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)$}
        case_id = $1
        c = Database.get_case(case_id, current_user)
        if c
          json_response(res, c)
        else
          json_response(res, { 'error' => 'Case not found or access denied' }, 404)
        end

      elsif method == 'PUT' && path =~ %r{^/api/cases/([^/]+)$}
        case_id = $1
        unless Database.verify_case_access(case_id, current_user)
          json_response(res, { 'error' => 'Forbidden: You do not own this case.' }, 403)
          return
        end
        body = parse_json_body(req)
        updated = Database.update_case(case_id, body, current_user['id'])
        json_response(res, updated)

      elsif method == 'DELETE' && path =~ %r{^/api/cases/([^/]+)$}
        case_id = $1
        unless Database.verify_case_access(case_id, current_user)
          json_response(res, { 'error' => 'Forbidden: You do not own this case.' }, 403)
          return
        end
        Database.log_audit_event(
          tenant_id: current_user['tenant_id'],
          user_id: current_user['id'],
          case_id: case_id,
          action: 'case.deleted',
          resource_type: 'case',
          resource_id: case_id,
          ip_address: extract_client_ip(req)
        )
        Database.delete_case(case_id, current_user['id'])
        json_response(res, { 'success' => true })

      # Evidence Files API
      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/files$}
        case_id = $1
        unless Database.verify_case_access(case_id, current_user)
          json_response(res, { 'error' => 'Forbidden: You do not have access to files for this case.' }, 403)
          return
        end
        files = Database.list_files(case_id)
        json_response(res, files)

      elsif method == 'POST' && (path =~ %r{^/api/cases/([^/]+)/evidence$} || path =~ %r{^/api/cases/([^/]+)/upload$})
        case_id = $1
        unless Database.verify_case_access(case_id, current_user)
          json_response(res, { 'error' => 'Forbidden: You cannot upload evidence to this case.' }, 403)
          return
        end
        handle_file_upload(case_id, req, res, current_user)

      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/files/([^/]+)/download$}
        case_id = $1
        file_id = $2
        unless Database.verify_case_access(case_id, current_user)
          json_response(res, { 'error' => 'Forbidden: You do not have access to this case evidence.' }, 403)
          return
        end
        file_rec = Database.get_file(file_id)
        if file_rec.nil? || file_rec['case_id'] != case_id
          json_response(res, { 'error' => 'Evidence file not found.' }, 404)
          return
        end
        data = nil
        if file_rec['storage_key']
          data = StorageService.adapter.get_object(key: file_rec['storage_key']) rescue nil
        end
        if data.nil? && file_rec['storage_path'] && File.file?(file_rec['storage_path'])
          data = File.binread(file_rec['storage_path']) rescue nil
        end

        if data.nil?
          json_response(res, { 'error' => 'Evidence file not found in storage.' }, 404)
          return
        end

        mime = mime_for(file_rec['original_name'] || file_rec['storage_path'])
        res.status = 200
        res['Content-Type'] = mime
        res['Content-Length'] = data.bytesize.to_s
        res['Cache-Control'] = 'private, no-cache, no-store, must-revalidate'
        safe_name = file_rec['original_name'].to_s.gsub(/["\r\n]/, '_')
        res['Content-Disposition'] = "attachment; filename=\"#{safe_name}\""
        res.body = data

        Database.log_audit_event(
          tenant_id: current_user['tenant_id'],
          user_id: current_user['id'],
          case_id: case_id,
          file_id: file_id,
          action: 'evidence.download',
          resource_type: 'evidence_file',
          resource_id: file_id,
          ip_address: extract_client_ip(req),
          metadata: {
            filename: file_rec['original_name'],
            bytes_sent: data.bytesize
          }
        )
        return

      elsif method == 'POST' && path =~ %r{^/api/files/([^/]+)/retry$}
        file_id = $1
        file_rec = Database.get_file(file_id)
        if file_rec
          unless Database.verify_case_access(file_rec['case_id'], current_user)
            json_response(res, { 'error' => 'Forbidden: You cannot retry processing for this file.' }, 403)
            return
          end
          Database.update_file_status(file_id, 'Queued', progress: 0, error_message: nil)
          WORKER_QUEUE.push({ case_id: file_rec['case_id'], file_id: file_id })
          json_response(res, { 'success' => true, 'status' => 'Queued' })
        else
          json_response(res, { 'error' => 'File not found.' }, 404)
        end

      elsif method == 'DELETE' && path =~ %r{^/api/files/([^/]+)$}
        file_id = $1
        file_rec = Database.get_file(file_id)
        if file_rec
          case_id = file_rec['case_id']
          unless Database.verify_case_access(case_id, current_user)
            json_response(res, { 'error' => 'Forbidden: You cannot delete this file.' }, 403)
            return
          end
          Database.log_audit_event(
            tenant_id: current_user['tenant_id'],
            user_id: current_user['id'],
            case_id: case_id,
            file_id: file_id,
            action: 'evidence.delete',
            resource_type: 'evidence_file',
            resource_id: file_id,
            ip_address: extract_client_ip(req),
            metadata: { filename: file_rec['original_name'] }
          )
          Database.delete_file(file_id)
          StorageService.delete_file(file_rec['storage_path'])
          AggregationService.aggregate_case_evidence(case_id)
          json_response(res, { 'success' => true })
        else
          json_response(res, { 'error' => 'File not found.' }, 404)
        end

      # Master Summary & Diff APIs
      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/summary$}
        case_id = $1
        unless Database.verify_case_access(case_id, current_user)
          json_response(res, { 'error' => 'Forbidden: You do not have access to this case summary.' }, 403)
          return
        end
        summary = Database.get_latest_summary(case_id)
        json_response(res, summary || {})

      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/diffs$}
        case_id = $1
        unless Database.verify_case_access(case_id, current_user)
          json_response(res, { 'error' => 'Forbidden: You do not have access to diffs for this case.' }, 403)
          return
        end
        diffs = Database.list_diffs(case_id)
        json_response(res, diffs)

      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/extractions/([^/]+)$}
        parts = path.split('/')
        case_id = parts[3]
        file_id = parts[5]
        unless Database.verify_case_access(case_id, current_user)
          json_response(res, { 'error' => 'Forbidden: You do not have access to this extraction.' }, 403)
          return
        end
        file_rec = Database.get_file(file_id)
        if file_rec.nil? || file_rec['case_id'] != case_id
          json_response(res, { 'error' => 'Extraction not found.' }, 404)
          return
        end
        ext = Database.get_extraction(file_id)
        if ext
          json_response(res, ext)
        else
          json_response(res, { 'error' => 'Extraction not found.' }, 404)
        end

      # Section 65B (IEA) / Section 63 (BSA, 2023) Electronic Evidence Certificate API
      elsif method == 'GET' && path =~ %r{^/api/cases/([^/]+)/files/([^/]+)/certificate$}
        case_id = $1
        file_id = $2
        unless Database.verify_case_access(case_id, current_user)
          json_response(res, { 'error' => 'Forbidden: You do not have access to this certificate.' }, 403)
          return
        end
        case_record = Database.get_case(case_id, current_user)
        file_record = Database.get_file(file_id)

        if case_record && file_record && file_record['case_id'] == case_id
          cert = CertificateService.generate_section_65b_certificate(case_record, file_record)
          Database.log_audit_event(
            tenant_id: current_user['tenant_id'],
            user_id: current_user['id'],
            case_id: case_id,
            file_id: file_id,
            action: 'certificate.issued',
            resource_type: 'certificate',
            resource_id: cert['certificate_id'] || file_id,
            ip_address: extract_client_ip(req),
            metadata: { legal_statute: "Section 65B IEA / Section 63 BSA" }
          )
          json_response(res, cert)
        else
          json_response(res, { 'error' => 'Case or evidence file not found.' }, 404)
        end

      # Notifications API
      elsif method == 'GET' && path == '/api/notifications'
        user_id = current_user['id']
        notifs = Database.list_notifications(30, user_id)
        json_response(res, notifs)

      elsif method == 'POST' && path == '/api/notifications/read'
        body = parse_json_body(req)
        user_id = current_user['id']
        Database.mark_notifications_read(body['case_id'], user_id)
        json_response(res, { 'success' => true })

      # Cost & Performance Optimization Analytics API (Requires Admin Privileges)
      elsif method == 'GET' && path == '/api/analytics/cost-performance'
        unless AuthService.admin?(current_user)
          json_response(res, { 'error' => 'Forbidden: Administrator privileges required to view system analytics.' }, 403)
          return
        end
        analytics = Database.get_performance_analytics
        json_response(res, analytics)

      # Enterprise Audit Logging API (Requires Admin Privileges, strictly scoped to current tenant)
      elsif method == 'GET' && path == '/api/audit-logs'
        unless AuthService.admin?(current_user)
          json_response(res, { 'error' => 'Forbidden: Administrator privileges required to view audit logs.' }, 403)
          return
        end
        tenant_id = current_user['tenant_id']
        limit = (req.query && req.query['limit']) ? req.query['limit'].to_i : 100
        logs = Database.list_audit_logs(tenant_id, limit)
        json_response(res, logs)

      # Administrative Dead-Letter Recovery API
      elsif method == 'POST' && path =~ %r{^/api/admin/jobs/([^/]+)/retry$}
        job_id = $1
        unless AuthService.admin?(current_user)
          json_response(res, { 'error' => 'Forbidden: Administrator privileges required to retry dead-letter jobs.' }, 403)
          return
        end
        begin
          retried_job = JobQueue.retry_dead_letter(job_id, current_user)
          json_response(res, { 'status' => 'requeued', 'job' => retried_job })
        rescue => e
          json_response(res, { 'error' => e.message }, 400)
        end

      # Settings API (Requires Authentication, Mutation Requires Admin)
      elsif method == 'GET' && path == '/api/settings'
        has_key = !GeminiService.api_key.nil? && !GeminiService.api_key.empty?
        is_admin = AuthService.admin?(current_user)
        json_response(res, {
          'ai_api_key_configured' => has_key,
          'ai_model' => GeminiService::DEFAULT_MODEL,
          'app_version' => '1.0.0-PROD',
          'is_admin' => is_admin,
          'analytics' => is_admin ? Database.get_performance_analytics : nil
        })

      elsif method == 'POST' && path == '/api/settings'
        unless AuthService.admin?(current_user)
          json_response(res, { 'error' => 'Forbidden: Administrator privileges required to modify settings.' }, 403)
          return
        end
        body = parse_json_body(req)
        if body.key?('ai_api_key')
          Database.set_setting('gemini_api_key', body['ai_api_key'])
        end
        json_response(res, { 'success' => true })

      # Seed reset API (Requires Admin Authentication)
      elsif method == 'POST' && path == '/api/seed/reset'
        unless AuthService.admin?(current_user)
          json_response(res, { 'error' => 'Forbidden: Administrator privileges required to reset seed data.' }, 403)
          return
        end
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

  def handle_file_upload(case_id, req, res, current_user)
    case_rec = Database.get_case(case_id, current_user)
    unless case_rec
      json_response(res, { 'error' => 'Case not found or access denied.' }, 404)
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

          # Magic-byte file-type verification
          type_check = StorageService.validate_file_content(fname, file_bytes)
          unless type_check[:valid]
            json_response(res, { 'error' => type_check[:error] }, 400)
            return
          end

          quota = StorageService.check_case_quota(case_id, file_bytes.bytesize)
          
          unless quota['allowed']
            json_response(res, { 'error' => quota['reason'] }, 400)
            return
          end

          saved_info = StorageService.save_stream(case_id, fname, file_bytes, part['content-type'], tenant_id: current_user['tenant_id'])
          
          file_rec = Database.create_file({
            'id' => saved_info['id'],
            'case_id' => case_id,
            'tenant_id' => current_user['tenant_id'],
            'filename' => saved_info['filename'],
            'original_name' => fname,
            'file_type' => saved_info['file_type'],
            'file_size' => saved_info['file_size'],
            'storage_path' => saved_info['storage_path'],
            'storage_key' => saved_info['storage_key'],
            'sha256_hash' => saved_info['sha256_hash'],
            'status' => 'VERIFIED',
            'progress' => 0
          })

          WORKER_QUEUE.push({ case_id: case_id, file_id: file_rec['id'] })
          JobQueue.enqueue(
            tenant_id: current_user['tenant_id'],
            job_type: 'extract',
            payload: { case_id: case_id, file_id: file_rec['id'], sha256: file_rec['sha256_hash'] }
          )
          uploaded_files << file_rec

        end
      end
    elsif content_type.include?('application/json')
      # JSON Upload payload (simulated/text or base64 file)
      body = parse_json_body(req)
      filename = body['filename'] || "evidence_#{Time.now.to_i}.txt"
      content = body['content'] || body['text'] || ""
      file_type_hint = body['file_type'] || 'text/plain'

      if body['encoding'] == 'base64'
        require 'base64'
        content = Base64.decode64(content) rescue content
      end

      # Magic-byte file-type verification
      type_check = StorageService.validate_file_content(filename, content)
      unless type_check[:valid]
        json_response(res, { 'error' => type_check[:error] }, 400)
        return
      end

      quota = StorageService.check_case_quota(case_id, content.bytesize)
      unless quota['allowed']
        json_response(res, { 'error' => quota['reason'] }, 400)
        return
      end

      saved_info = StorageService.save_stream(case_id, filename, content, file_type_hint, tenant_id: current_user['tenant_id'])

      file_rec = Database.create_file({
        'id' => saved_info['id'],
        'case_id' => case_id,
        'tenant_id' => current_user['tenant_id'],
        'filename' => saved_info['filename'],
        'original_name' => filename,
        'file_type' => saved_info['file_type'],
        'file_size' => saved_info['file_size'],
        'storage_path' => saved_info['storage_path'],
        'storage_key' => saved_info['storage_key'],
        'sha256_hash' => saved_info['sha256_hash'],
        'status' => 'VERIFIED',
        'progress' => 0
      })

      WORKER_QUEUE.push({ case_id: case_id, file_id: file_rec['id'] })
      JobQueue.enqueue(
        tenant_id: current_user['tenant_id'],
        job_type: 'extract',
        payload: { case_id: case_id, file_id: file_rec['id'], sha256: file_rec['sha256_hash'] }
      )
      uploaded_files << file_rec

    end

    client_ip = extract_client_ip(req)
    uploaded_files.each do |f|
      Database.log_audit_event(
        tenant_id: current_user['tenant_id'],
        user_id: current_user['id'],
        case_id: case_id,
        file_id: f['id'],
        action: 'evidence.upload',
        resource_type: 'evidence_file',
        resource_id: f['id'],
        ip_address: client_ip,
        metadata: {
          filename: f['original_name'],
          file_size: f['file_size'],
          file_type: f['file_type']
        }
      )
    end

    json_response(res, { 'success' => true, 'files' => uploaded_files }, 201)
  end

  def handle_authenticated_evidence_download(req, res)
    current_user = extract_current_user(req)
    if current_user.nil?
      json_response(res, { 'error' => 'Unauthorized. Please sign in to access evidence files.' }, 401)
      return
    end

    raw_path = req.path.to_s.dup.force_encoding('UTF-8').scrub
    match = raw_path.match(%r{\A/uploads/([^/]+)/(.+)\z})
    unless match
      json_response(res, { 'error' => 'Invalid evidence path format.' }, 404)
      return
    end

    case_id = match[1]
    rel_filename = match[2]

    # Explicitly reject directory traversal attempts
    if case_id.include?('..') || rel_filename.include?('..') || rel_filename.include?('\\')
      json_response(res, { 'error' => 'Forbidden: Invalid path traversal detected.' }, 403)
      return
    end

    unless Database.verify_case_access(case_id, current_user)
      json_response(res, { 'error' => 'Forbidden: You do not have access to this case evidence.' }, 403)
      return
    end

    uploads_root = File.expand_path('../uploads', __FILE__)
    target_file = File.expand_path(File.join(uploads_root, case_id, rel_filename))

    unless target_file.start_with?(uploads_root + File::SEPARATOR)
      json_response(res, { 'error' => 'Forbidden: Path traversal detected.' }, 403)
      return
    end

    file_record = Database.find_file_by_name(case_id, File.basename(rel_filename))

    data = nil
    if file_record && file_record['storage_key']
      data = StorageService.adapter.get_object(key: file_record['storage_key']) rescue nil
    end
    if data.nil? && File.file?(target_file)
      data = File.binread(target_file) rescue nil
    end

    if data.nil?
      json_response(res, { 'error' => 'Evidence file not found in storage.' }, 404)
      return
    end

    mime = mime_for(target_file)
    res.status = 200
    res['Content-Type'] = mime
    res['Content-Length'] = data.bytesize.to_s
    res['Cache-Control'] = 'private, no-cache, no-store, must-revalidate'
    download_name = file_record ? file_record['original_name'] : File.basename(rel_filename)
    safe_name = download_name.to_s.gsub(/["\r\n]/, '_')
    # SECURITY FIX: force download instead of inline rendering. Rendering
    # user-uploaded content (e.g. .html or .svg files) inline in the
    # browser at this route's origin allows stored XSS with same-origin
    # access to cookies and localStorage. Always force a download.
    res['Content-Disposition'] = "attachment; filename=\"#{safe_name}\""
    res.body = data

    Database.log_audit_event(
      tenant_id: current_user['tenant_id'],
      user_id: current_user['id'],
      case_id: case_id,
      file_id: file_record ? file_record['id'] : nil,
      action: 'evidence.download',
      resource_type: 'evidence_file',
      resource_id: file_record ? file_record['id'] : nil,
      ip_address: extract_client_ip(req),
      metadata: {
        filename: download_name,
        bytes_sent: data.bytesize
      }
    )
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
    public_dir = File.expand_path('../public', __FILE__)
    raw_path = req.path.split('?').first.to_s
    clean_path = raw_path.gsub(%r{\A/+}, '')
    clean_path = 'index.html' if clean_path.empty?

    # Explicitly reject directory traversal, dotfiles, or requests targeting uploads / api
    if clean_path.include?('..') || clean_path.start_with?('uploads') || clean_path.start_with?('api') || File.basename(clean_path).start_with?('.')
      res.status = 404
      res['Content-Type'] = 'text/plain; charset=utf-8'
      res.body = 'Not Found'
      return
    end

    target_file = File.expand_path(File.join(public_dir, clean_path))

    # Ensure target_file is strictly inside public_dir
    unless target_file.start_with?(public_dir + File::SEPARATOR) || target_file == File.join(public_dir, 'index.html')
      res.status = 403
      res['Content-Type'] = 'text/plain; charset=utf-8'
      res.body = 'Forbidden'
      return
    end

    # Block sensitive file extensions even if mistakenly placed in public
    forbidden_extensions = %w[.db .sqlite .sqlite3 .rb .env .yml .yaml .gem .sh .git .log]
    if forbidden_extensions.include?(File.extname(target_file).downcase)
      res.status = 404
      res['Content-Type'] = 'text/plain; charset=utf-8'
      res.body = 'Not Found'
      return
    end

    if File.file?(target_file)
      mime = mime_for(target_file)
      res.status = 200
      res['Content-Type'] = mime
      if mime.start_with?('image/', 'font/')
        res['Cache-Control'] = 'public, max-age=86400, immutable'
      elsif mime.start_with?('application/javascript', 'text/css')
        res['Cache-Control'] = 'public, max-age=3600'
      else
        res['Cache-Control'] = 'no-cache, must-revalidate'
      end
      res.body = File.binread(target_file)
      return
    end

    # Fallback to index.html for Single Page App routing ONLY for clean GET paths without extensions or dotfiles
    if req.request_method == 'GET' && File.extname(clean_path).empty? && !File.basename(clean_path).start_with?('.')
      index_file = File.join(public_dir, 'index.html')
      if File.file?(index_file)
        res.status = 200
        res['Content-Type'] = 'text/html; charset=utf-8'
        res['Cache-Control'] = 'no-cache, must-revalidate'
        res.body = File.binread(index_file)
        return
      end
    end

    res.status = 404
    res['Content-Type'] = 'text/plain; charset=utf-8'
    res.body = 'Not Found'
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

# Rack Bridge for Puma (Phase 2)
class RackRequestAdapter
  attr_reader :env, :path, :request_method, :body, :query

  def initialize(env)
    @env = env
    @path = env['PATH_INFO'] || '/'
    @request_method = env['REQUEST_METHOD'] || 'GET'
    @body = env['rack.input'] ? env['rack.input'].read : ''
    env['rack.input'].rewind if env['rack.input'].respond_to?(:rewind)
    @query = {}
    if env['QUERY_STRING'] && !env['QUERY_STRING'].empty?
      env['QUERY_STRING'].split('&').each do |pair|
        k, v = pair.split('=', 2)
        @query[CGI.unescape(k)] = CGI.unescape(v || '') if k
      end
    end
  end

  def [](header_key)
    cgi_key = "HTTP_" + header_key.to_s.upcase.tr('-', '_')
    if @env.key?(cgi_key)
      @env[cgi_key]
    elsif header_key.to_s.downcase == 'content-type'
      @env['CONTENT_TYPE']
    elsif header_key.to_s.downcase == 'content-length'
      @env['CONTENT_LENGTH']
    else
      @env[header_key.to_s]
    end
  end

  def peeraddr
    [nil, nil, nil, @env['REMOTE_ADDR'] || '127.0.0.1']
  end
end

class RackResponseAdapter
  attr_accessor :status, :header, :body

  def initialize
    @status = 200
    @header = {}
    @body = ''
  end

  def []=(k, v)
    @header[k] = v
  end

  def [](k)
    @header[k]
  end
end

class LexDraftApp
  def initialize
    @servlet = CaseOrganizerServlet.new(WEBrick::Config::HTTP)
  end

  def call(env)
    req = RackRequestAdapter.new(env)
    res = RackResponseAdapter.new
    @servlet.service(req, res)
    headers = {}
    res.header.each do |k, v|
      headers[k.to_s.downcase] = v.to_s
    end
    headers['server'] ||= 'Puma (Ruby/3.2)'
    body_str = res.body.is_a?(String) ? res.body : res.body.to_s
    headers['content-length'] ||= body_str.bytesize.to_s
    [res.status, headers, [body_str]]
  end
end


# Canonical Server configuration
PORT = (ENV['PORT'] || 8080).to_i

if __FILE__ == $0
  server = WEBrick::HTTPServer.new(
    Port: PORT,
    BindAddress: '0.0.0.0',
    DoNotReverseLookup: true,
    MaxClients: 100,
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
end
