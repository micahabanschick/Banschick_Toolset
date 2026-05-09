#!/usr/bin/env bash
# ============================================================================
# BANSCHICK TOOLSET — Deploy Script
# ============================================================================
# Usage:
#   ./scripts/deploy.sh              Deploy all services
#   ./scripts/deploy.sh quantpipe    Deploy only QuantPipe
#   ./scripts/deploy.sh studybuddy   Deploy only StudyBuddy
#
# See: Master Build Plan, Section 8.3
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

APP="${1:-}"

echo "════════════════════════════════════════════════════════"
echo "  Banschick Toolset — Deployment"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "════════════════════════════════════════════════════════"

# Pull latest code
echo ""
echo "→ Pulling latest code from GitHub..."
git pull origin main

if [ "$APP" = "studybuddy" ]; then
    echo ""
    echo "→ Rebuilding and restarting: studybuddy-web studybuddy-ai"
    docker compose up -d --build studybuddy-web studybuddy-ai
elif [ -n "$APP" ]; then
    echo ""
    echo "→ Rebuilding and restarting: $APP"
    docker compose up -d --build "$APP"
else
    echo ""
    echo "→ Rebuilding and restarting all services..."
    docker compose up -d --build
fi

echo ""
echo "→ Current container status:"
docker compose ps

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Deployment complete."
echo "════════════════════════════════════════════════════════"
