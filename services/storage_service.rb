# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require 'digest'
require_relative 'storage_adapter'
require_relative 'local_storage_adapter'
require_relative 's3_storage_adapter'

module StorageService
  STORAGE_ROOT = File.expand_path('../../uploads', __FILE__)

  def self.adapter
    @adapter ||= begin
      use_s3 = (
        ENV['STORAGE_BACKEND'] == 's3' ||
        ENV['STORAGE_ADAPTER'] == 's3' ||
        !ENV['R2_BUCKET'].to_s.empty? ||
        !ENV['S3_BUCKET'].to_s.empty? ||
        !ENV['R2_ENDPOINT'].to_s.empty? ||
        !ENV['S3_ENDPOINT'].to_s.empty?
      )
      has_creds = (!ENV['AWS_ACCESS_KEY_ID'].to_s.empty? || !ENV['R2_ACCESS_KEY_ID'].to_s.empty?)
      if use_s3 && has_creds
        begin
          require_relative 's3_storage_adapter'
          s3_adapter = S3StorageAdapter.new
          if s3_adapter.s3_available?
            puts "[StorageService] Activated S3StorageAdapter (Bucket: #{s3_adapter.bucket}, Region: #{s3_adapter.region})"
            s3_adapter
          else
            puts "[StorageService] S3StorageAdapter not available, falling back to LocalStorageAdapter"
            LocalStorageAdapter.new
          end
        rescue => e
          puts "[StorageService] S3StorageAdapter initialization failed (#{e.class}: #{e.message}), falling back to LocalStorageAdapter"
          LocalStorageAdapter.new
        end
      else
        LocalStorageAdapter.new
      end
    end
  end

  def self.set_adapter(custom_adapter)
    @adapter = custom_adapter
  end

  # Prohibited executable and script extensions (including SVG active vector markup)
  BLOCKED_EXTENSIONS = %w[
    .exe .dll .so .dylib .bin .sh .bash .bat .cmd .msi .vbs .scr .com .pif .app .jar .py .rb .php .cgi .pl .svg
  ].freeze

  def self.init
    FileUtils.mkdir_p(STORAGE_ROOT)
  end

  def self.extract_header_bytes(io_or_string, max_bytes = 512)
    if io_or_string.is_a?(String)
      io_or_string.b[0...max_bytes] || "".b
    elsif io_or_string.respond_to?(:read)
      bytes = io_or_string.read(max_bytes)
      io_or_string.rewind if io_or_string.respond_to?(:rewind)
      bytes ? bytes.b : "".b
    else
      io_or_string.to_s.b[0...max_bytes] || "".b
    end
  end

  def self.is_executable_binary?(header)
    return false if header.nil? || header.empty?
    h = header.b
    # Windows PE / DOS ('MZ')
    return true if h.start_with?('MZ'.b)
    # Linux ELF ('\x7FELF')
    return true if h.start_with?("\x7FELF".b)
    # macOS Mach-O & Universal Fat Binary
    return true if h.start_with?("\xFE\xED\xFA\xCE".b) || h.start_with?("\xFE\xED\xFA\xCF".b) ||
                   h.start_with?("\xCE\xFA\xED\xFE".b) || h.start_with?("\xCF\xFA\xED\xFE".b) ||
                   h.start_with?("\xCA\xFE\xBA\xBE".b)
    false
  end

  def self.contains_vba_macros?(raw_bytes)
    return false unless raw_bytes.to_s.b.start_with?("PK\x03\x04".b)
    raw = raw_bytes.to_s.b
    return true if raw.include?("word/vbaProject.bin".b)
    return true if raw.include?("vbaData.xml".b)
    return true if raw.include?("word/vbaProjectSignature.bin".b)
    false
  end

  def self.contains_pdf_active_content?(raw_bytes)
    return false unless raw_bytes.to_s.b.start_with?("%PDF-".b)
    raw = raw_bytes.to_s.b[0..65536] # Inspect leading structural dictionaries
    return true if raw =~ %r{/JavaScript|/JS\b|/Launch\b|/EmbeddedFiles\b}i
    false
  end

  def self.validate_file_content(filename, io_or_string)
    ext = File.extname(filename.to_s).downcase

    if BLOCKED_EXTENSIONS.include?(ext)
      return { valid: false, error: "Executable and script file uploads are strictly prohibited (#{ext})." }
    end

    raw = extract_header_bytes(io_or_string, 512)

    if raw.empty?
      return { valid: false, error: "Uploaded file is empty." }
    end

    header = raw[0..31] || raw

    # Explicitly check for executable binary signatures regardless of claimed extension
    if is_executable_binary?(header)
      return { valid: false, error: "File content contains executable binary signatures and cannot be accepted." }
    end

    # Explicitly reject SVG markup in evidence uploads
    if raw.include?('<svg'.b) || raw.include?('xmlns="http://www.w3.org/2000/svg"'.b)
      return { valid: false, error: "SVG files and active SVG markup are strictly prohibited for evidence storage." }
    end

    case ext
    when '.pdf'
      unless header.start_with?('%PDF-'.b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine PDF (%PDF-) format." }
      end
      pdf_sample = extract_header_bytes(io_or_string, 65536)
      if contains_pdf_active_content?(pdf_sample)
        return { valid: false, error: "PDF contains active scripts or executable actions (/JavaScript, /Launch) and cannot be accepted." }
      end

    when '.jpg', '.jpeg'
      unless header.start_with?("\xFF\xD8\xFF".b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine JPEG (FF D8 FF) format." }
      end

    when '.png'
      unless header.start_with?("\x89PNG".b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine PNG (89 50 4E 47) format." }
      end

    when '.webp'
      unless header.start_with?('RIFF'.b) && raw.bytesize >= 12 && raw[8..11] == 'WEBP'.b
        return { valid: false, error: "File content does not match its declared type: Expected genuine WebP format." }
      end

    when '.bmp'
      unless header.start_with?('BM'.b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine BMP format." }
      end

    when '.tiff', '.tif'
      unless header.start_with?("II*\x00".b) || header.start_with?("MM\x00*".b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine TIFF format." }
      end

    when '.wav'
      unless header.start_with?('RIFF'.b) && raw.bytesize >= 12 && raw[8..11] == 'WAVE'.b
        return { valid: false, error: "File content does not match its declared type: Expected genuine WAV audio format." }
      end

    when '.mp3'
      is_id3 = header.start_with?('ID3'.b)
      is_mp3_frame = header.bytesize >= 2 && header.getbyte(0) == 0xFF && (header.getbyte(1) & 0xE0) == 0xE0
      unless is_id3 || is_mp3_frame
        return { valid: false, error: "File content does not match its declared type: Expected genuine MP3 audio format." }
      end

    when '.ogg'
      unless header.start_with?('OggS'.b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine OGG audio format." }
      end

    when '.flac'
      unless header.start_with?('fLaC'.b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine FLAC audio format." }
      end

    when '.mp4', '.m4a', '.mov'
      # MP4 / M4A / QuickTime container check: bytes 4..7 == 'ftyp' or 'moov' or 'mdat' or 'wide'
      has_container = raw.bytesize >= 8 && %w[ftyp moov mdat wide].include?(raw[4..7].to_s)
      unless has_container
        return { valid: false, error: "File content does not match its declared type: Expected genuine MP4/M4A/MOV container format." }
      end

    when '.mkv', '.webm'
      unless header.start_with?("\x1A\x45\xDF\xA3".b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine Matroska/WebM container format." }
      end

    when '.docx'
      unless header.start_with?("PK\x03\x04".b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine DOCX (ZIP container) format." }
      end
      docx_sample = if io_or_string.is_a?(String)
                      io_or_string
                    elsif io_or_string.respond_to?(:read)
                      b = io_or_string.read
                      io_or_string.rewind if io_or_string.respond_to?(:rewind)
                      b
                    else
                      raw
                    end
      if contains_vba_macros?(docx_sample)
        return { valid: false, error: "File content contains active VBA macros and cannot be accepted for legal evidence ingestion." }
      end

    when '.doc'
      unless header.start_with?("\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1".b) || header.start_with?("PK\x03\x04".b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine DOC format." }
      end

    when '.zip'
      unless header.start_with?("PK\x03\x04".b) || header.start_with?("PK\x05\x06".b) || header.start_with?("PK\x07\x08".b)
        return { valid: false, error: "File content does not match its declared type: Expected genuine ZIP archive format." }
      end

    when '.txt', '.csv', '.log', '.md'
      # Text files should not contain null bytes in their leading bytes
      if raw.include?("\x00".b)
        return { valid: false, error: "File content does not match its declared type: Binary content detected in text file." }
      end
    end

    { valid: true }
  end

  def self.save_stream(case_id, original_filename, io_or_string, content_type = 'application/octet-stream', tenant_id: nil, file_id: nil)
    init
    case_dir = File.join(STORAGE_ROOT, case_id)
    FileUtils.mkdir_p(case_dir)

    file_id ||= "ef_#{Time.now.to_i}_#{SecureRandom.hex(4)}"
    ext = File.extname(original_filename).downcase
    safe_name = File.basename(original_filename, ext).gsub(/[^a-zA-Z0-9_-]/, '_')
    unique_filename = "#{Time.now.to_i}_#{SecureRandom.hex(4)}_#{safe_name}#{ext}"
    target_path = File.join(case_dir, unique_filename)

    size = 0
    digest = Digest::SHA256.new
    raw_content = String.new

    File.open(target_path, 'wb') do |f|
      if io_or_string.is_a?(String)
        f.write(io_or_string)
        digest.update(io_or_string)
        raw_content = io_or_string
        size = io_or_string.bytesize
      else
        while (chunk = io_or_string.read(65536)) # 64KB chunks
          f.write(chunk)
          digest.update(chunk)
          raw_content << chunk
          size += chunk.bytesize
        end
        io_or_string.rewind if io_or_string.respond_to?(:rewind)
      end
    end

    detected_type = detect_file_type(original_filename, content_type)
    sha256_hex = digest.hexdigest

    # Resolve tenant_id if not explicitly provided
    resolved_tenant_id = tenant_id
    if resolved_tenant_id.nil? || resolved_tenant_id.empty?
      case_rec = Database.get_case(case_id) rescue nil
      resolved_tenant_id = case_rec ? case_rec['tenant_id'] : 'ten_default'
    end

    # Deterministic storage key decoupled from user-controlled filename
    storage_key = StorageAdapter.build_storage_key(
      tenant_id: resolved_tenant_id,
      case_id: case_id,
      file_id: file_id,
      sha256: sha256_hex
    )

    # Put object in configured adapter (S3 or LocalStorage)
    adapter.put_object(
      key: storage_key,
      io_or_string: raw_content,
      content_type: content_type,
      metadata: {
        'tenant_id' => resolved_tenant_id,
        'case_id' => case_id,
        'file_id' => file_id,
        'original_name' => original_filename
      }
    )

    {
      'id' => file_id,
      'filename' => unique_filename,
      'original_name' => original_filename,
      'file_type' => detected_type,
      'file_size' => size,
      'storage_path' => target_path,
      'storage_key' => storage_key,
      'checksum' => sha256_hex,
      'sha256_hash' => sha256_hex,
      'status' => 'VERIFIED',
      'relative_path' => "/uploads/#{case_id}/#{unique_filename}"
    }
  end

  def self.can_consume_evidence?(file_record)
    return false unless file_record
    status = file_record['status'].to_s.upcase
    # Only allow verified or currently in processing states; reject UPLOADING, UPLOADED, VERIFYING, FAILED
    %w[VERIFIED QUEUED PROCESSING COMPLETE TRANSCRIBING].include?(status) ||
      %w[Queued Processing Complete].include?(file_record['status'].to_s)
  end

  def self.get_object(key)
    return nil unless key
    adapter.get_object(key: key)
  end

  def self.delete_object(key)
    return unless key
    adapter.delete_object(key: key)
  end

  def self.generate_download_url(key, expires_in: 300, filename: nil)
    return nil unless key
    adapter.generate_download_url(key: key, expires_in: expires_in, filename: filename)
  end

  def self.check_case_quota(case_id, incoming_size_bytes)
    c = Database.get_case(case_id)
    return { 'allowed' => false, 'reason' => 'Case not found' } unless c

    current_size = c['total_size_bytes'].to_i
    max_bytes = c['max_storage_bytes'].to_i
    current_files = c['total_files'].to_i
    max_files = c['max_files'].to_i

    if current_files + 1 > max_files
      return {
        'allowed' => false,
        'reason' => "Case file limit reached (#{max_files} files). Upgrade to Pro/Enterprise for higher limits."
      }
    end

    if current_size + incoming_size_bytes > max_bytes
      return {
        'allowed' => false,
        'reason' => "Storage limit exceeded (Max #{Database.format_bytes(max_bytes)}). Upgrade case tier."
      }
    end

    { 'allowed' => true }
  end

  def self.detect_file_type(filename, content_type = nil)
    ext = File.extname(filename).downcase

    case ext
    when '.pdf'
      'PDF'
    when '.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff'
      'Image'
    when '.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'
      'Audio'
    when '.mp4', '.mov', '.avi', '.mkv', '.webm'
      'Video'
    when '.txt', '.csv', '.rtf', '.log', '.md'
      'WhatsApp/Text'
    when '.doc', '.docx'
      'Word Document'
    when '.zip', '.tar', '.gz'
      'Archive/Export'
    else
      if content_type&.include?('image')
        'Image'
      elsif content_type&.include?('audio')
        'Audio'
      elsif content_type&.include?('video')
        'Video'
      elsif content_type&.include?('pdf')
        'PDF'
      else
        'Document'
      end
    end
  end

  def self.get_file_path(storage_path)
    return nil unless File.exist?(storage_path)
    storage_path
  end

  def self.delete_file(storage_path)
    return unless storage_path
    resolved = File.expand_path(storage_path)
    return unless resolved.start_with?(STORAGE_ROOT + File::SEPARATOR)
    File.delete(resolved) if File.file?(resolved)
  end
end

