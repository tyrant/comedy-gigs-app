# Multi-stage Dockerfile for Rails 8 + React + PostgreSQL app

# Base stage with common dependencies
FROM ruby:3.2-slim AS base

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y \
      build-essential \
      libpq-dev \
      curl \
      git && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gems stage - install Ruby dependencies
FROM base AS gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# Node dependencies stage
FROM base AS node_modules
COPY package*.json ./
RUN npm ci --only=production

# Assets stage - compile assets
FROM base AS assets
COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY --from=node_modules /app/node_modules /app/node_modules
COPY . .

# Precompile assets
RUN RAILS_ENV=production \
    SECRET_KEY_BASE=dummy \
    bundle exec rails assets:precompile

# Final production stage
FROM ruby:3.2-slim AS final

# Install only runtime dependencies
RUN apt-get update -qq && \
    apt-get install -y \
      libpq5 \
      curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy gems and compiled assets
COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY --from=assets /app/public /app/public
COPY . .

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Expose port
EXPOSE 3000

# Start the Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
