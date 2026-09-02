# Production Dockerfile for LexDraft AI (Render / Railway / Cloud VM)
FROM ruby:3.2-slim

# Install system dependencies
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libsqlite3-dev \
    sqlite3 \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Ruby dependencies
COPY Gemfile ./
RUN bundle install

# Install Python dependencies in a virtual environment
COPY processor/requirements.txt ./processor/
RUN python3 -m venv /app/processor/venv \
    && /app/processor/venv/bin/pip install --no-cache-dir -r ./processor/requirements.txt

# Copy application files
COPY . .

# Ensure startup scripts are executable
RUN chmod +x start-cloud.sh start.sh

# Expose default HTTP port
EXPOSE 8080

# Environment variables
ENV PORT=8080
ENV RACK_ENV=production

# Entrypoint
CMD ["./start-cloud.sh"]
