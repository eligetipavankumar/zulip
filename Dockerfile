########################################
# Stage 1 - Frontend build (Node + pnpm)
########################################
FROM node:18-bullseye AS frontend
WORKDIR /usr/src/app

# Enable pnpm via corepack
RUN corepack enable && corepack prepare pnpm@10.15.1 --activate

# Copy only package files for caching
COPY package.json pnpm-lock.yaml* pnpm-workspace.yaml* ./

# Install dependencies
RUN pnpm fetch || true
RUN pnpm install --frozen-lockfile --prefer-offline

# Copy frontend sources and build
COPY static/ ./static 2>/dev/null || true
COPY web/ ./web 2>/dev/null || true
COPY . .

# Build frontend
RUN if pnpm -s -v >/dev/null 2>&1; then pnpm run build || true; fi

########################################
# Stage 2 - Python deps / builder
########################################
FROM python:3.11-slim AS builder
WORKDIR /usr/src/app

# Install build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc libpq-dev git curl \
  && rm -rf /var/lib/apt/lists/*

# Copy project dependencies
COPY pyproject.toml poetry.lock* ./

# Install Python dependencies via Poetry
RUN pip install --upgrade pip && pip install poetry && \
    poetry config virtualenvs.create false && \
    poetry install --no-dev --no-interaction --no-ansi

# Copy project source
COPY . .

########################################
# Stage 3 - Final runtime image
########################################
FROM python:3.11-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app

# Install runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
  && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages || true

# Copy application code
COPY . .

# Copy built frontend artifacts
COPY --from=frontend /usr/src/app/web/dist /app/static 2>/dev/null || true
COPY --from=frontend /usr/src/app/static /app/static 2>/dev/null || true

# Create non-root user
RUN useradd --create-home zulipuser && chown -R zulipuser:zulipuser /app
USER zulipuser

# Expose Zulip port
EXPOSE 9991

# Start command
CMD ["bash", "-lc", "python manage.py migrate --noinput && python manage.py collectstatic --noinput || true && gunicorn -b 0.0.0.0:9991 zproject.wsgi:application --workers 3"]

