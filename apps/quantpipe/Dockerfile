# ============================================================================
# QUANTPIPE — Dockerfile
# ============================================================================
# Containerizes the existing QuantPipe Python pipeline WITHOUT code changes.
#
# What runs inside this container:
#   1. Cron: ingest_daily.py at 10pm ET weekdays (nightly market data pull)
#   2. Streamlit: health_dashboard.py on port 3001 (Caddy proxies this)
#   3. All Parquet data in /app/data/ (persisted via Docker volume)
#
# The build context is the QuantPipe repo root — clone it into
# apps/quantpipe/ or mount it. See docker-compose.yml for volume config.
# ============================================================================

FROM python:3.12-slim AS base

# ── System packages ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    cron \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# ── Install uv ────────────────────────────────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

# ── Install dependencies (cached layer — only re-runs if pyproject changes)
COPY pyproject.toml ./
RUN uv sync 2>/dev/null || true

# ── Copy full QuantPipe codebase ──────────────────────────────────────────
COPY . .

# ── Sync all dependency groups ────────────────────────────────────────────
RUN uv sync

# ── Create directories for runtime data ───────────────────────────────────
RUN mkdir -p /app/data /app/logs

# ── Set up cron for nightly ingestion ─────────────────────────────────────
# Runs ingest_daily.py at 10:00 PM ET (02:00 UTC next day) on weekdays.
# All env vars are written to /etc/environment so cron can read them.
COPY <<'CRONTAB' /etc/cron.d/quantpipe-ingest
# QuantPipe nightly ingestion — Mon-Fri at 10pm ET (02:00 UTC)
0 2 * * 1-5 root cd /app && /root/.local/bin/uv run python orchestration/ingest_daily.py >> /app/logs/ingest.log 2>&1
CRONTAB

RUN chmod 0644 /etc/cron.d/quantpipe-ingest && crontab /etc/cron.d/quantpipe-ingest

# ── Entrypoint: start cron + Streamlit ────────────────────────────────────
COPY <<'ENTRYPOINT' /app/entrypoint.sh
#!/bin/bash
set -e

# Export env vars so cron jobs can access them
printenv | grep -v "no_proxy" >> /etc/environment

# Start cron daemon in background
cron

echo "✓ Cron daemon started (nightly ingestion at 10pm ET)"
echo "✓ Starting Streamlit dashboard on port 3001..."

# Start Streamlit as the foreground process
exec uv run streamlit run reports/health_dashboard.py \
    --server.port=3001 \
    --server.address=0.0.0.0 \
    --server.headless=true \
    --browser.gatherUsageStats=false
ENTRYPOINT

RUN chmod +x /app/entrypoint.sh

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost:3001/_stcore/health || exit 1

CMD ["/app/entrypoint.sh"]
