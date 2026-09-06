# frozen_string_literal: true

# LexDraft AI — Rack Application Entrypoint (Phase 2 Puma)
require_relative 'server'

# Ensure Database and StorageService are initialized
Database.init
StorageService.init

# Enforce Production Topology Boundaries
if ENV['RACK_ENV'] == 'production'
  if ENV['STANDALONE_WORKER'] != 'true' || ENV['DISABLE_EMBEDDED_WORKER'] != 'true'
    raise "[FATAL TOPOLOGY VIOLATION] Embedded in-process worker is strictly prohibited in production. " \
          "STANDALONE_WORKER=true and DISABLE_EMBEDDED_WORKER=true must be configured, " \
          "and bin/worker.rb must run as a dedicated background service."
  end
  puts "[Topology Guard] Production topology verified: Web service running Puma only (embedded worker disabled)."
else
  # Development / Test local fallback only
  if ENV['STANDALONE_WORKER'] != 'true' && ENV['DISABLE_EMBEDDED_WORKER'] != 'true'
    puts "[Topology Notice] Non-production environment: Spawning embedded development worker thread."
    Thread.new do
      require_relative 'bin/worker'
      BackgroundWorker.start_loop("dev_embedded_worker_#{Process.pid}")
    end
  else
    puts "[Topology Notice] Embedded worker explicitly disabled via environment configuration."
  end
end

run LexDraftApp.new
