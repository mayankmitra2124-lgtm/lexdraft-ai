# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require 'digest'

module StorageService
  STORAGE_ROOT = File.expand_path('../../uploads', __FILE__)

  def self.init
    FileUtils.mkdir_p(STORAGE_ROOT)
  end

  def self.save_stream(case_id, original_filename, io_or_string, content_type = 'application/octet-stream')
    init
    case_dir = File.join(STORAGE_ROOT, case_id)
    FileUtils.mkdir_p(case_dir)

    ext = File.extname(original_filename).downcase
    safe_name = File.basename(original_filename, ext).gsub(/[^a-zA-Z0-9_-]/, '_')
    unique_filename = "#{Time.now.to_i}_#{SecureRandom.hex(4)}_#{safe_name}#{ext}"
    target_path = File.join(case_dir, unique_filename)

    size = 0
    digest = Digest::SHA256.new

    File.open(target_path, 'wb') do |f|
      if io_or_string.is_a?(String)
        f.write(io_or_string)
        digest.update(io_or_string)
        size = io_or_string.bytesize
      else
        while (chunk = io_or_string.read(65536)) # 64KB chunks
          f.write(chunk)
          digest.update(chunk)
          size += chunk.bytesize
        end
      end
    end

    detected_type = detect_file_type(original_filename, content_type)

    {
      'filename' => unique_filename,
      'original_name' => original_filename,
      'file_type' => detected_type,
      'file_size' => size,
      'storage_path' => target_path,
      'checksum' => digest.hexdigest,
      'relative_path' => "/uploads/#{case_id}/#{unique_filename}"
    }
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
    File.delete(storage_path) if File.exist?(storage_path)
  end
end
