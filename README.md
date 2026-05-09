# Banschick Toolset

Personal application suite for Micah Banschick. Each app runs as an isolated Docker container, routed through Caddy via subdomains under `banschick.com`.

## Applications

| App | Subdomain | Stack | Data Storage |
|-----|-----------|-------|--------------|
| QuantPipe | quantpipe.banschick.com | Python 3.12, Polars, DuckDB, Streamlit | Parquet files (Docker volume) |
| StudyBuddy | studybuddy.banschick.com | Next.js 16 + FastAPI | Supabase (external) |

## Quick Start

```bash
# 1. Clone this repo and the app repos
git clone git@github.com:micahbanschick/banschick-toolset.git
cd banschick-toolset

# 2. Clone each app into its apps/ directory
git clone git@github.com:micahabanschick/QuantPipe.git apps/quantpipe
git clone -b claude/study-aid-app-lIjfv git@github.com:micahabanschick/StudyBuddy.git /tmp/studybuddy
cp -r /tmp/studybuddy/web/* apps/studybuddy-web/
cp -r /tmp/studybuddy/ai/* apps/studybuddy-ai/

# 3. Create environment files
cp .env.example .env                              # Root (Postgres admin)
cp apps/quantpipe/.env.example apps/quantpipe/.env # QuantPipe secrets
cp apps/studybuddy-web/.env.example apps/studybuddy-web/.env
cp apps/studybuddy-ai/.env.example apps/studybuddy-ai/.env
# Edit each .env and fill in real values

# 4. Start everything
docker compose up -d

# 5. Verify
docker compose ps
```

## Architecture

```
User device
    → Cloudflare DNS/CDN
    → Caddy (HTTPS + subdomain routing)
    ├── quantpipe.banschick.com   → QuantPipe container (Streamlit :3001)
    └── studybuddy.banschick.com  → StudyBuddy-Web container (Next.js :3002)
                                       ↕ internal network
                                    StudyBuddy-AI container (FastAPI :3003)
```

## Common Commands

```bash
./scripts/deploy.sh                 # Pull + rebuild all
./scripts/deploy.sh quantpipe       # Rebuild just QuantPipe
./scripts/backup.sh                 # Backup Parquet data + any local DBs
docker compose logs -f quantpipe    # Tail logs
docker compose exec quantpipe bash  # Shell into QuantPipe container
```

## Adding a New App

See `Banschick_Toolset_Master_Build_Plan.docx`, Section 8.2.

## Documentation

Full architecture, security model, cost projections, and Claude instructions are in the Master Build Plan document stored in this project.
