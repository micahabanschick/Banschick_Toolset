#!/usr/bin/env bash
# ============================================================================
# BANSCHICK TOOLSET — Backup Script
# ============================================================================
# Backs up all persistent data that lives on this server.
#
# WHAT THIS BACKS UP:
#   - QuantPipe Parquet data (the quantpipe_data Docker volume)
#   - Local PostgreSQL databases (for future apps)
#
# WHAT THIS DOES NOT BACK UP (handled externally):
#   - StudyBuddy data → stored in Supabase, which has its own backup system
#   - Code → stored in GitHub
#
# Cron setup (run once on the server):
#   crontab -e
#   0 3 * * * /path/to/banschick-toolset/scripts/backup.sh >> /var/log/banschick-backup.log 2>&1
#
# See: Master Build Plan, Section 11.1
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="/home/backups/banschick-toolset"
TIMESTAMP="$(date '+%Y-%m-%d_%H%M%S')"
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

echo "════════════════════════════════════════════════════════"
echo "  Banschick Toolset — Backup"
echo "  $TIMESTAMP"
echo "════════════════════════════════════════════════════════"

# ── Source .env for admin credentials ────────────────────────────────────
if [ -f "$REPO_DIR/.env" ]; then
    # shellcheck disable=SC1091
    source "$REPO_DIR/.env"
fi

# ── 1. QuantPipe Parquet Data ────────────────────────────────────────────
echo ""
echo "→ Backing up QuantPipe Parquet data..."

QP_BACKUP="$BACKUP_DIR/quantpipe_data_${TIMESTAMP}.tar.gz"

# Copy from the Docker volume via a temporary container
docker run --rm \
    -v quantpipe_data:/data:ro \
    -v "$BACKUP_DIR":/backup \
    alpine \
    tar czf "/backup/quantpipe_data_${TIMESTAMP}.tar.gz" -C /data .

SIZE=$(du -h "$QP_BACKUP" | cut -f1)
echo "  ✓ Saved: $QP_BACKUP ($SIZE)"

# ── 2. Local PostgreSQL (future apps) ───────────────────────────────────
# Only runs if there are databases beyond the default 'postgres' database
DB_LIST=$(docker exec postgres psql -U "${POSTGRES_ADMIN_USER:-banschick_admin}" -t -c \
    "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" \
    2>/dev/null | tr -d ' ' | grep -v '^$' || true)

if [ -n "$DB_LIST" ]; then
    echo ""
    echo "→ Backing up PostgreSQL databases..."
    for DB in $DB_LIST; do
        OUTFILE="$BACKUP_DIR/${DB}_${TIMESTAMP}.sql.gz"
        docker exec postgres pg_dump \
            -U "${POSTGRES_ADMIN_USER:-banschick_admin}" \
            -d "$DB" \
            --format=custom \
            --compress=6 \
            > "$OUTFILE"
        SIZE=$(du -h "$OUTFILE" | cut -f1)
        echo "  ✓ $DB → $OUTFILE ($SIZE)"
    done
else
    echo ""
    echo "→ No local PostgreSQL app databases to back up (expected — current apps use Parquet/Supabase)"
fi

# ── 3. StudyBuddy ────────────────────────────────────────────────────────
echo ""
echo "→ StudyBuddy: data lives in Supabase (external). No local backup needed."
echo "  Supabase dashboard: https://supabase.com/dashboard → project settings → backups"

# ── Clean up old backups ─────────────────────────────────────────────────
echo ""
echo "→ Removing backups older than $RETENTION_DAYS days..."
DELETED=$(find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.sql.gz" \) -mtime +"$RETENTION_DAYS" -delete -print 2>/dev/null | wc -l)
echo "  ✓ Removed $DELETED old backup(s)"

TOTAL=$(find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.sql.gz" \) | wc -l)
echo ""
echo "════════════════════════════════════════════════════════"
echo "  Backup complete. $TOTAL backup file(s) on disk."
echo "════════════════════════════════════════════════════════"
