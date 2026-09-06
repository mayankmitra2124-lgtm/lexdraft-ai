# frozen_string_literal: true

require 'fileutils'
require 'openssl'
require 'base64'
require_relative 'storage_adapter'

module StorageService
  class LocalStorageAdapter < StorageAdapter
    attr_reader :storage_root, :secret_key

    def initialize(storage_root = nil, secret_key = nil)
      @storage_root = storage_root || File.expand_path('../../uploads', __FILE__)
      @secret_key = secret_key || ENV['APP_SECRET_KEY'] || 'lexdraft_local_dev_secret_32_bytes_pad'
      FileUtils.mkdir_p(@storage_root)
    end

    def path_for(key)
      # Normalize key and ensure it stays inside storage_root
      clean_key = key.to_s.gsub(%r{\A/+}, '')
      File.join(@storage_root, clean_key)
    end

    def put_object(key:, io_or_string:, content_type: 'application/octet-stream', metadata: {})
      target_file = path_for(key)
      FileUtils.mkdir_p(File.dirname(target_file))

      digest = Digest::SHA256.new
      size = 0

      File.open(target_file, 'wb') do |f|
        if io_or_string.is_a?(String)
          f.write(io_or_string)
          digest.update(io_or_string)
          size = io_or_string.bytesize
        elsif io_or_string.respond_to?(:read)
          while (chunk = io_or_string.read(65536))
            f.write(chunk)
            digest.update(chunk)
            size += chunk.bytesize
          end
          io_or_string.rewind if io_or_string.respond_to?(:rewind)
        else
          s = io_or_string.to_s
          f.write(s)
          digest.update(s)
          size = s.bytesize
        end
      end

      # Write metadata sidecar if provided
      if metadata && !metadata.empty?
        meta_file = "#{target_file}.meta.json"
        File.write(meta_file, JSON.generate(metadata)) rescue nil
      end

      {
        key: key,
        sha256: digest.hexdigest,
        bytesize: size,
        content_type: content_type
      }
    end

    def get_object(key:)
      target_file = path_for(key)
      return nil unless File.file?(target_file)
      File.binread(target_file)
    end

    def delete_object(key:)
      target_file = path_for(key)
      return unless File.exist?(target_file)
      File.delete(target_file) if File.file?(target_file)
      meta_file = "#{target_file}.meta.json"
      File.delete(meta_file) if File.file?(meta_file)
    end

    def object_exists?(key:)
      File.file?(path_for(key))
    end

    def object_size(key:)
      target_file = path_for(key)
      File.file?(target_file) ? File.size(target_file) : 0
    end

    def generate_download_url(key:, expires_in: 300, filename: nil)
      expires_at = Time.now.to_i + expires_in
      payload = "#{key}:#{expires_at}:#{filename}"
      hmac = OpenSSL::HMAC.hexdigest('SHA256', @secret_key, payload)
      token = Base64.urlsafe_encode64("#{payload}:#{hmac}")
      "/api/storage/download?token=#{token}"
    end

    def generate_upload_url(key:, expires_in: 300, content_type: nil)
      expires_at = Time.now.to_i + expires_in
      payload = "#{key}:#{expires_at}:upload"
      hmac = OpenSSL::HMAC.hexdigest('SHA256', @secret_key, payload)
      token = Base64.urlsafe_encode64("#{payload}:#{hmac}")
      "/api/storage/upload?token=#{token}"
    end

    def verify_download_token(token)
      decoded = Base64.urlsafe_decode64(token) rescue nil
      return nil unless decoded
      parts = decoded.split(':')
      return nil if parts.size < 4
      hmac = parts.pop
      key = parts[0]
      expires_at = parts[1].to_i
      filename = parts[2]
      return nil if Time.now.to_i > expires_at

      expected_payload = "#{key}:#{expires_at}:#{filename}"
      expected_hmac = OpenSSL::HMAC.hexdigest('SHA256', @secret_key, expected_payload)
      return nil unless Rack::Utils.secure_compare(hmac, expected_hmac) rescue (hmac == expected_hmac)

      { key: key, filename: filename }
    end
  end
end
