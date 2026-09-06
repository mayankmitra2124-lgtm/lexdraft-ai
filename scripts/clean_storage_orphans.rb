# frozen_string_literal: true

require_relative '../db/database'
require_relative '../services/storage_service'
require 'time'
require 'fileutils'

module StorageOrphanCleaner
  def self.clean_orphans!(older_than_seconds: 86400, dry_run: false)
    puts "\n========================================================"
    puts "  LexDraft S3 Storage Orphan Object Cleanup"
    puts "  Threshold: Older than #{older_than_seconds}s (Dry Run: #{dry_run})"
    puts "========================================================"

    # Collect all valid storage keys from authoritative database
    db_keys = Database.query("SELECT storage_key FROM evidence_files WHERE storage_key IS NOT NULL").map { |r| r['storage_key'] }.compact.to_set
    puts "Active DB Storage Keys Tracked: #{db_keys.size}"

    orphans_found = 0
    reaped = 0

    # Scan through storage root / S3 keys
    adapter = StorageService.adapter
    if adapter.is_a?(StorageService::LocalStorageAdapter)
      storage_root = adapter.storage_root
      all_files = Dir.glob(File.join(storage_root, 'tenants/**/*')).select { |f| File.file?(f) && !f.end_with?('.meta.json') }
      cutoff_time = Time.now - older_than_seconds

      all_files.each do |file_path|
        # Derive relative key
        rel_key = file_path.sub(storage_root + File::SEPARATOR, '')
        next if db_keys.include?(rel_key)

        mtime = File.mtime(file_path)
        if mtime < cutoff_time
          orphans_found += 1
          puts " [Orphan Found] #{rel_key} (Modified: #{mtime.utc.iso8601})"
          unless dry_run
            adapter.delete_object(key: rel_key)
            reaped += 1
          end
        end
      end
    end

    puts "Orphan Objects Identified: #{orphans_found}"
    puts "Orphan Objects Purged:     #{reaped}"
    { orphans_found: orphans_found, reaped: reaped }
  end
end

if __FILE__ == $0
  StorageOrphanCleaner.clean_orphans!(dry_run: ARGV.include?('--dry-run'))
end
