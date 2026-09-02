#!/bin/bash
# Startup script for Case Evidence Organizer (Feature 1)

PORT=${PORT:-8080}
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure port is free
PID=$(lsof -ti :$PORT 2>/dev/null)
if [ ! -z "$PID" ]; then
  echo "Freeing port $PORT (terminating existing PID $PID)..."
  kill -9 $PID 2>/dev/null
  sleep 1
fi

echo "=========================================================="
echo " Starting Case Evidence Organizer (Feature 1)"
echo " Indian Legal Tech Evidence Ingestion & Synthesis Engine"
echo "=========================================================="
echo "Project Directory: $PROJECT_DIR"
echo "Listening on:      http://localhost:$PORT"
echo "=========================================================="

cd "$PROJECT_DIR"
ruby server.rb
