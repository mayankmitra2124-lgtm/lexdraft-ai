# Production Dockerfile for LexDraft AI (Render / Railway / Cloud VM)
FROM ruby:3.2-slim

# Install system dependencies
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
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
RUN mkdir -p uploads

# Ensure startup scripts are executable
RUN chmod +x start-cloud.sh start.sh

# Expose default HTTP port
EXPOSE 8080

# Environment variables
ENV PORT=8080
ENV RACK_ENV=production

# Entrypoint
CMD ["./start-cloud.sh"]
