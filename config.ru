# frozen_string_literal: true

# LexDraft AI — Rack Application Entrypoint (Phase 2 Puma)
require_relative 'server'

# Enforce Production Topology Boundaries
if ENV['RACK_ENV'] == 'production'
  # If explicitly configured with invalid embedded worker flags, fail loudly
  if ENV['STANDALONE_WORKER'] == 'false' || ENV['DISABLE_EMBEDDED_WORKER'] == 'false'
    raise "[FATAL TOPOLOGY VIOLATION] Embedded in-process worker is strictly prohibited in production. " \
          "STANDALONE_WORKER=true and DISABLE_EMBEDDED_WORKER=true must be configured, " \
          "and bin/worker.rb must run as a dedicated background service."
  end

  if ENV['STANDALONE_WORKER'] == 'true' && ENV['DISABLE_EMBEDDED_WORKER'] == 'true'
    puts "[Topology Guard] Clustered topology verified: Dedicated background worker running externally."
  else
    puts "[Topology Mode] Single-service container topology detected: Spawning background worker daemon thread."
    Thread.new do
      require_relative 'bin/worker'
      BackgroundWorker.start_loop("embedded_worker_#{Process.pid}")
    end
  end
end

run LexDraftApp.new
