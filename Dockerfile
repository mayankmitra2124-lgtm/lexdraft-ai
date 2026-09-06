# Production Dockerfile for LexDraft AI (Phase 2 Puma + PostgreSQL + S3)
FROM ruby:3.2-slim

# Install system dependencies (including libpq for PostgreSQL)
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    postgresql-client \
    libsqlite3-dev \
    sqlite3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Ruby dependencies
COPY Gemfile ./
RUN bundle install

# Copy application files (excluding archived/submodule items via .dockerignore)
COPY . .

# Ensure storage directories exist
RUN mkdir -p uploads archive/untracked_pre_phase2

# Ensure startup scripts are executable
RUN chmod +x start-cloud.sh start.sh bin/worker.rb

# Expose default HTTP port
EXPOSE 8080

# Environment variables
ENV PORT=8080
ENV RACK_ENV=production
ENV STORAGE_BACKEND=s3
ENV STORAGE_ADAPTER=s3

# Entrypoint
CMD ["./start-cloud.sh"]
