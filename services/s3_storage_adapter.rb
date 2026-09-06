# frozen_string_literal: true

require 'digest'
require 'time'
require_relative 'storage_adapter'

module StorageService
  class S3StorageAdapter < StorageAdapter
    attr_reader :bucket, :region, :endpoint, :client

    def initialize(options = {})
      @bucket = options[:bucket] || ENV['R2_BUCKET'] || ENV['S3_BUCKET'] || ENV['S3_BUCKET_NAME'] || 'lexdraft-evidence-prod'
      @region = options[:region] || ENV['R2_REGION'] || ENV['S3_REGION'] || ENV['AWS_REGION'] || 'auto'
      @endpoint = options[:endpoint] || ENV['R2_ENDPOINT'] || ENV['S3_ENDPOINT'] || ENV['AWS_ENDPOINT_URL']
      @force_path_style = options.key?(:force_path_style) ? options[:force_path_style] : (ENV['S3_FORCE_PATH_STYLE'] != 'false')
      
      init_client
    end

    def init_client
      begin
        require 'aws-sdk-s3'
        access_key = ENV['R2_ACCESS_KEY_ID'] || ENV['AWS_ACCESS_KEY_ID']
        secret_key = ENV['R2_SECRET_ACCESS_KEY'] || ENV['AWS_SECRET_ACCESS_KEY']
        client_opts = {
          region: @region,
          access_key_id: access_key,
          secret_access_key: secret_key
        }
        client_opts[:endpoint] = @endpoint if @endpoint && !@endpoint.empty?
        client_opts[:force_path_style] = @force_path_style
        @client = Aws::S3::Client.new(client_opts)
        @s3_resource = Aws::S3::Resource.new(client: @client)
      rescue => e
        puts "[S3StorageAdapter] Init failed: #{e.class} - #{e.message}"
        @client = nil
        @s3_resource = nil
      end
    end

    def s3_available?
      !@client.nil?
    end

    def put_object(key:, io_or_string:, content_type: 'application/octet-stream', metadata: {})
      body = io_or_string.is_a?(String) ? io_or_string : (io_or_string.respond_to?(:read) ? io_or_string.read : io_or_string.to_s)
      io_or_string.rewind if io_or_string.respond_to?(:rewind)

      digest = Digest::SHA256.hexdigest(body)

      if s3_available?
        meta_formatted = {}
        metadata.each { |k, v| meta_formatted[k.to_s.tr('_', '-')] = v.to_s }
        meta_formatted['sha256'] = digest

        put_params = {
          bucket: @bucket,
          key: key,
          body: body,
          content_type: content_type,
          metadata: meta_formatted
        }
        # Server-side encryption: AWS requires AES256 if enforced by policy, whereas Cloudflare R2
        # encrypts all objects automatically at rest and does not require explicit SSE headers.
        if ENV['S3_SERVER_SIDE_ENCRYPTION'] == 'AES256' || (@endpoint.nil? || !@endpoint.include?('r2.cloudflarestorage.com'))
          put_params[:server_side_encryption] = 'AES256'
        end

        begin
          @client.put_object(put_params)
          puts "[S3StorageAdapter] Successfully stored #{key} (#{body.bytesize} bytes) in bucket '#{@bucket}'"
        rescue => e
          puts "[S3StorageAdapter Error] Failed to put_object #{key} to #{@bucket}: #{e.class} - #{e.message}"
          raise e
        end
      else
        puts "[S3StorageAdapter Warning] s3_available? is false; #{key} not uploaded to R2"
      end

      {
        key: key,
        sha256: digest,
        bytesize: body.bytesize,
        content_type: content_type
      }
    end

    def get_object(key:)
      return nil unless s3_available?
      resp = @client.get_object(bucket: @bucket, key: key)
      resp.body.read
    rescue => e
      nil
    end

    def delete_object(key:)
      return unless s3_available?
      @client.delete_object(bucket: @bucket, key: key)
    rescue => e
      nil
    end

    def object_exists?(key:)
      return false unless s3_available?
      @client.head_object(bucket: @bucket, key: key)
      true
    rescue => e
      false
    end

    def object_size(key:)
      return 0 unless s3_available?
      resp = @client.head_object(bucket: @bucket, key: key)
      resp.content_length
    rescue => e
      0
    end

    def generate_download_url(key:, expires_in: 300, filename: nil)
      if s3_available?
        signer = Aws::S3::Presigner.new(client: @client)
        params = {
          bucket: @bucket,
          key: key,
          expires_in: expires_in
        }
        if filename && !filename.empty?
          safe_name = filename.to_s.gsub(/["\r\n]/, '_')
          params[:response_content_disposition] = "attachment; filename=\"#{safe_name}\""
        end
        signer.presigned_url(:get_object, params)
      else
        # Emulation fallback if running in dev without live AWS connection
        "/api/storage/s3-mock-download?key=#{key}"
      end
    end

    def generate_upload_url(key:, expires_in: 300, content_type: nil)
      if s3_available?
        signer = Aws::S3::Presigner.new(client: @client)
        params = {
          bucket: @bucket,
          key: key,
          expires_in: expires_in
        }
        params[:content_type] = content_type if content_type
        signer.presigned_url(:put_object, params)
      else
        "/api/storage/s3-mock-upload?key=#{key}"
      end
    end
  end
end
