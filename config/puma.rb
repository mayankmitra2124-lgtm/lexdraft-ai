# frozen_string_literal: true

# LexDraft AI — Production Puma Configuration (Phase 2)
# Concurrency Model: 2 Worker Processes x 4..8 Threads = Max 16 concurrent HTTP requests
# Database Pool: 10 connections per worker = Max 20 DB connections for web layer

max_threads_count = Integer(ENV.fetch('RAILS_MAX_THREADS', 8))
min_threads_count = Integer(ENV.fetch('RAILS_MIN_THREADS', 4))
threads min_threads_count, max_threads_count

port        Integer(ENV.fetch('PORT', 8080))
environment ENV.fetch('RACK_ENV', 'production')

# Clustered mode for container durability
workers Integer(ENV.fetch('WEB_CONCURRENCY', 2))

# Preload application code before forking workers for memory savings
preload_app!

# Process tagging and graceful shutdown
tag 'lexdraft-core'
shutdown_timeout 30

on_worker_boot do
  # Initialize database pool per forked worker process
  Database.init_pool if defined?(Database)
end

before_fork do
  # Disconnect database before master process forks workers
  Database.disconnect_pool if defined?(Database)
end
