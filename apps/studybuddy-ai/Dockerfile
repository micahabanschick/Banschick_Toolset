# ============================================================================
# STUDYBUDDY-AI — Dockerfile
# ============================================================================
# FastAPI service handling RAG, embeddings, quiz generation, and
# science-specific tooling (chem structures, math rendering).
# Connects to Supabase (external) for vector storage (pgvector).
#
# The build context is the StudyBuddy repo's ai/ directory.
# ============================================================================

FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# ── Install uv ────────────────────────────────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

# ── Install dependencies (cached layer) ───────────────────────────────────
COPY pyproject.toml ./
RUN uv sync 2>/dev/null || true

# ── Copy full AI service codebase ─────────────────────────────────────────
COPY . .
RUN uv sync

EXPOSE 3003

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost:3003/health || exit 1

CMD ["uv", "run", "--no-sync", "fastapi", "run", "app/main.py", "--host", "0.0.0.0", "--port", "3003"]
