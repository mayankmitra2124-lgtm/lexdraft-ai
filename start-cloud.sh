#!/bin/bash
set -e

echo "=========================================================="
echo " Starting LexDraft AI Cloud Container"
echo " Phase 2: Puma + PostgreSQL + S3 + Durable Job Queue"
echo "=========================================================="

# Ensure upload and archive directories exist
mkdir -p uploads archive/untracked_pre_phase2

# Web container strictly runs Puma only when DISABLE_EMBEDDED_WORKER is set
if [ "$DISABLE_EMBEDDED_WORKER" = "true" ]; then
  echo "[Topology Assertion] Embedded worker disabled for production Web tier."
elif [ "$STANDALONE_WORKER" = "false" ] || [ -z "$STANDALONE_WORKER" ]; then
  echo "Launching in-process background worker daemon for development..."
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
