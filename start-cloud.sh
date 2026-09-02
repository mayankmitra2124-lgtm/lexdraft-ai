#!/bin/bash
set -e

echo "=========================================================="
echo " Starting LexDraft AI Cloud Container"
echo "=========================================================="

# Launch Python FastAPI verification microservice if available
if [ -f "processor/venv/bin/activate" ]; then
  echo "[1/2] Launching Python FastAPI engine on port 8000..."
  source processor/venv/bin/activate
  uvicorn processor.main:app --host 0.0.0.0 --port 8000 &
elif command -v uvicorn &>/dev/null; then
  echo "[1/2] Launching Python FastAPI engine on port 8000..."
  uvicorn processor.main:app --host 0.0.0.0 --port 8000 &
else
  echo "[1/2] Python FastAPI engine optional; running built-in Ruby legal domain engine."
fi

# Launch Ruby Web Server
echo "[2/2] Launching Core Application Server on port ${PORT:-8080}..."
exec ruby server.rb
