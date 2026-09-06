# frozen_string_literal: true

require 'digest'
require 'securerandom'

module StorageService
  # Abstract Storage Adapter Base Class
  class StorageAdapter
    # Construct deterministic storage key decoupled from user-controlled filenames:
    # tenants/{tenant_id}/cases/{case_id}/evidence/{file_id}/{sha256}
    def self.build_storage_key(tenant_id:, case_id:, file_id:, sha256:)
      t_clean = tenant_id.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      c_clean = case_id.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      f_clean = file_id.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      h_clean = sha256.to_s.downcase.gsub(/[^a-f0-9]/, '')
      "tenants/#{t_clean}/cases/#{c_clean}/evidence/#{f_clean}/#{h_clean}"
    end

    def put_object(key:, io_or_string:, content_type: 'application/octet-stream', metadata: {})
      raise NotImplementedError, "#{self.class}#put_object is not implemented"
    end

    def get_object(key:)
      raise NotImplementedError, "#{self.class}#get_object is not implemented"
    end

    def delete_object(key:)
      raise NotImplementedError, "#{self.class}#delete_object is not implemented"
    end

    def object_exists?(key:)
      raise NotImplementedError, "#{self.class}#object_exists? is not implemented"
    end

    def object_size(key:)
      raise NotImplementedError, "#{self.class}#object_size is not implemented"
    end

    def generate_download_url(key:, expires_in: 300, filename: nil)
      raise NotImplementedError, "#{self.class}#generate_download_url is not implemented"
    end

    def generate_upload_url(key:, expires_in: 300, content_type: nil)
      raise NotImplementedError, "#{self.class}#generate_upload_url is not implemented"
    end
  end
end
