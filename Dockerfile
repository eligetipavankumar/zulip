# Dockerfile
# Multi-stage build:
#  - stage "frontend": builds JS/CSS using pnpm (uses Node)
#  - stage "builder": installs Python deps and collects static (optional)
#  - final stage: runtime image

########################################
# Stage 1 - frontend build (pnpm)
########################################
FROM node:18-bullseye as frontend
WORKDIR /usr/src/app

# Install pnpm via corepack (node 18 includes corepack)
RUN corepack enable && corepack prepare pnpm@10.15.1 --activate

# Copy only package files for faster caching
COPY package.json pnpm-lock.yaml* ./
# If you use pnpm-workspace.yaml or patches, copy them as well
COPY pnpm-lock.yaml . || true

# Install front-end dependencies
RUN pnpm fetch || true
RUN pnpm install --frozen-lockfile --prefer-offline

# Copy frontend sources and build. Adjust path if frontend is in web/ or static/
COPY static/ ./static/        # optional: adjust to your repo layout
COPY web/ ./web/              # optional: adjust to your repo layout
# if your repo builds from root, copy rest of repo
COPY . .

# Run front-end build. Adjust script name if your build script differs
RUN if pnpm -s -v >/dev/null 2>&1; then \
      pnpm run build || true; \
    fi

########################################
# Stage 2 - python deps / builder
########################################
FROM python:3.11-slim as builder
WORKDIR /usr/src/app

# Install build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc libpq-dev git curl \
  && rm -rf /var/lib/apt/lists/*

# Copy requirements if present
COPY requirements.txt ./
RUN if [ -f requirements.txt ]; then pip install --upgrade pip && pip wheel --no-deps -w /wheels -r requirements.txt; fi

# Copy repo sources (copy everything so that Django manage.py etc. are available)
COPY . .

########################################
# Final runtime image
########################################
FROM python:3.11-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app

# System deps for runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
  && rm -rf /var/lib/apt/lists/*

# Copy python wheels from builder (if built) and install
COPY --from=builder /wheels /wheels
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages || true
# Fallback: if requirements.txt exists, install at runtime
COPY requirements.txt ./
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Copy application code
COPY . .

# Copy built frontend artifacts from frontend stage into static dir expected by Django
# Adjust the paths depending on your project (e.g., web/dist -> static/)
# Example: copy web/build into /app/static/
COPY --from=frontend /usr/src/app/web/dist /app/static || true
COPY --from=frontend /usr/src/app/static /app/static || true

# Create a non-root user
RUN useradd --create-home zulipuser && chown -R zulipuser:zulipuser /app
USER zulipuser

# Expose the port Zulip listens on (container-side). Adjust if different.
EXPOSE 9991

# Default CMD — use your usual start command (gunicorn/uwsgi/manage.py runserver)
# This is a placeholder: replace with your production start (gunicorn) or dev command.
CMD ["bash", "-lc", "python manage.py migrate --noinput && python manage.py collectstatic --noinput || true && gunicorn -b 0.0.0.0:9991 zproject.wsgi:application --workers 3"]





