#!/bin/bash
set -e

echo "=========================================================="
echo " Starting LexDraft AI Cloud Container"
echo " Phase 2: Puma + PostgreSQL + S3 + Durable Job Queue"
echo "=========================================================="

# Ensure upload and archive directories exist
mkdir -p uploads archive/untracked_pre_phase2

# Web container manages background worker daemon based on topology
if [ "$DISABLE_EMBEDDED_WORKER" = "true" ]; then
  echo "[Topology Assertion] Dedicated worker tier active; worker daemon disabled in web container."
else
  echo "[Topology Assertion] Single-service container topology detected: launching background worker daemon..."
  ruby bin/worker.rb &
fi

# Launch Puma or fallback Ruby server
if bundle exec puma -v >/dev/null 2>&1; then
  echo "Launching Clustered Puma Web Server on port ${PORT:-8080}..."
  exec bundle exec puma -C config/puma.rb
else
  echo "Launching Canonical Ruby Web Server on port ${PORT:-8080}..."
  exec ruby server.rb
fi
