########################################
# Stage 1 - Frontend build (Node + pnpm)
########################################
FROM node:18-bullseye AS frontend
WORKDIR /usr/src/app

RUN corepack enable && corepack prepare pnpm@10.15.1 --activate
COPY package.json pnpm-lock.yaml* pnpm-workspace.yaml* ./
RUN pnpm fetch || true
RUN pnpm install --frozen-lockfile --prefer-offline

COPY static/ ./static/ 2>/dev/null || true
COPY web/ ./web/ 2>/dev/null || true
COPY . .

RUN if pnpm -s -v >/dev/null 2>&1; then pnpm run build || true; fi

########################################
# Stage 2 - Python deps / builder
########################################
FROM python:3.11-slim AS builder
WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc libpq-dev git curl \
  && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml poetry.lock* ./
RUN pip install --upgrade pip && pip install poetry && \
    poetry config virtualenvs.create false && poetry install --no-dev --no-interaction --no-ansi

COPY . .

########################################
# Stage 3 - Final runtime image
########################################
FROM python:3.11-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages || true
COPY . .

COPY --from=frontend /usr/src/app/web/dist /app/static 2>/dev/null || true
COPY --from=frontend /usr/src/app/static /app/static 2>/dev/null || true

RUN useradd --create-home zulipuser && chown -R zulipuser:zulipuser /app
USER zulipuser
EXPOSE 9991

CMD ["bash", "-lc", "python manage.py migrate --noinput && python manage.py collectstatic --noinput || true && gunicorn -b 0.0.0.0:9991 zproject.wsgi:application --workers 3"]
<<<<<<< HEAD






=======
>>>>>>> 0ccc7b5f4c81a17d4a68947853c6f3fa6b7dbd34

