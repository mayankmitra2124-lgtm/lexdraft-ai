#!/bin/bash
set -e

echo "=========================================================="
echo " Starting LexDraft AI Cloud Container"
echo " Indian Legal Tech Evidence Ingestion & Synthesis Engine"
echo "=========================================================="

# Ensure upload directory exists
mkdir -p uploads

# Launch Canonical Ruby Web Server
echo "Launching Core Legal Application Server on port ${PORT:-8080}..."
exec ruby server.rb
