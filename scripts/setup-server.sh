#!/usr/bin/env bash
# ============================================================================
# BANSCHICK TOOLSET — Initial Server Setup
# ============================================================================
# Run ONCE on a fresh Hetzner Ubuntu 24.04 server to bring it to a state
# where docker compose up -d starts the full toolset.
#
# What this script does (see Master Build Plan, Section 8.1):
#   1. System update + security packages
#   2. UFW firewall (ports 22, 80, 443 only)
#   3. SSH hardening (key-only auth)
#   4. Docker + Docker Compose plugin
#   5. Clone banschick-toolset infrastructure repo
#   6. Clone app repos into apps/ directories
#   7. Scaffold .env files from .env.examples
#   8. Register daily backup cron job
#   9. First docker compose up -d
#
# Usage:
#   ssh root@<server-ip>
#   curl -fsSL https://raw.githubusercontent.com/micahabanschick/banschick-toolset/main/scripts/setup-server.sh | bash
#
#   OR clone the repo first and run:
#   bash scripts/setup-server.sh
#
# IMPORTANT: Fill in all .env files BEFORE running docker compose up -d.
# The script will pause and prompt you before starting containers.
# ============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓ $*${NC}"; }
warn() { echo -e "${YELLOW}  ! $*${NC}"; }
die()  { echo -e "${RED}  ✗ $*${NC}"; exit 1; }
step() { echo ""; echo -e "→ $*"; }

# ── Config ───────────────────────────────────────────────────────────────────
TOOLSET_REPO="git@github.com:micahabanschick/banschick-toolset.git"
QUANTPIPE_REPO="git@github.com:micahabanschick/QuantPipe.git"
STUDYBUDDY_REPO="git@github.com:micahabanschick/StudyBuddy.git"
STUDYBUDDY_BRANCH="claude/study-aid-app-lIjfv"

INSTALL_DIR="/opt/banschick-toolset"
BACKUP_DIR="/home/backups/banschick-toolset"
LOG_FILE="/var/log/banschick-setup.log"

# ── Guard: must be root ───────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    die "This script must be run as root. Use: sudo bash $0"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Banschick Toolset — Initial Server Setup"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "════════════════════════════════════════════════════════"

exec > >(tee -a "$LOG_FILE") 2>&1

# ── 1. System update ─────────────────────────────────────────────────────────
step "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl \
    wget \
    git \
    ufw \
    unattended-upgrades \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release
ok "System packages updated"

# ── 2. UFW Firewall ───────────────────────────────────────────────────────────
step "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH"
ufw allow 80/tcp comment "HTTP (Caddy redirects to HTTPS)"
ufw allow 443/tcp comment "HTTPS"
ufw allow 443/udp comment "HTTPS QUIC/HTTP3"
ufw --force enable
ok "Firewall active — ports 22, 80, 443 open"

# ── 3. SSH hardening ─────────────────────────────────────────────────────────
step "Hardening SSH (key-only auth)..."
SSHD_CFG="/etc/ssh/sshd_config"

# Only harden if authorized_keys exists — prevents accidental lockout
if [ -f "/root/.ssh/authorized_keys" ] && [ -s "/root/.ssh/authorized_keys" ]; then
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CFG"
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CFG"
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CFG"
    systemctl reload ssh
    ok "SSH key-only authentication enabled"
else
    warn "No authorized_keys found — skipping SSH hardening to prevent lockout"
    warn "Add your public key to /root/.ssh/authorized_keys, then re-run this block manually"
fi

# ── 4. Unattended upgrades (security patches) ────────────────────────────────
step "Enabling automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades-banschick <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF
systemctl enable unattended-upgrades --quiet
ok "Automatic security updates enabled"

# ── 5. Docker ────────────────────────────────────────────────────────────────
step "Installing Docker..."
if command -v docker &>/dev/null; then
    ok "Docker already installed ($(docker --version))"
else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker --quiet
    systemctl start docker
    ok "Docker installed ($(docker --version))"
fi

# ── 6. Clone infrastructure repo ─────────────────────────────────────────────
step "Cloning banschick-toolset infrastructure repo..."
if [ -d "$INSTALL_DIR/.git" ]; then
    ok "Repo already cloned at $INSTALL_DIR — pulling latest"
    git -C "$INSTALL_DIR" pull origin main
else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$TOOLSET_REPO" "$INSTALL_DIR"
    ok "Cloned to $INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# ── 7. Clone app repos ────────────────────────────────────────────────────────
step "Cloning QuantPipe app repo..."
if [ -d "apps/quantpipe/.git" ]; then
    ok "QuantPipe already cloned — pulling latest"
    git -C apps/quantpipe pull origin main
else
    git clone "$QUANTPIPE_REPO" apps/quantpipe
    ok "QuantPipe cloned"
fi

step "Cloning StudyBuddy app repo..."
TMP_SB="/tmp/studybuddy-clone"
rm -rf "$TMP_SB"
git clone -b "$STUDYBUDDY_BRANCH" "$STUDYBUDDY_REPO" "$TMP_SB"

mkdir -p apps/studybuddy-web apps/studybuddy-ai

# Copy web and ai directories (preserve existing .env if present)
rsync -a --exclude='.env' "$TMP_SB/web/" apps/studybuddy-web/
rsync -a --exclude='.env' "$TMP_SB/ai/"  apps/studybuddy-ai/

rm -rf "$TMP_SB"
ok "StudyBuddy web and AI services populated"

# ── 8. Scaffold .env files ────────────────────────────────────────────────────
step "Scaffolding .env files from .env.examples..."

scaffold_env() {
    local example="$1"
    local target="$2"
    if [ -f "$target" ]; then
        warn "$target already exists — skipping (will not overwrite)"
    else
        cp "$example" "$target"
        ok "Created $target"
    fi
}

scaffold_env ".env.example"                            ".env"
scaffold_env "apps/quantpipe/.env.example"             "apps/quantpipe/.env"
scaffold_env "apps/studybuddy-web/.env.example"        "apps/studybuddy-web/.env"
scaffold_env "apps/studybuddy-ai/.env.example"         "apps/studybuddy-ai/.env"

# ── 9. Backup cron ────────────────────────────────────────────────────────────
step "Registering daily backup cron job..."
mkdir -p "$BACKUP_DIR"
CRON_LINE="0 3 * * * root bash $INSTALL_DIR/scripts/backup.sh >> /var/log/banschick-backup.log 2>&1"
CRON_FILE="/etc/cron.d/banschick-backup"

if [ -f "$CRON_FILE" ] && grep -qF "$INSTALL_DIR/scripts/backup.sh" "$CRON_FILE"; then
    ok "Backup cron already registered"
else
    echo "$CRON_LINE" > "$CRON_FILE"
    chmod 0644 "$CRON_FILE"
    ok "Backup cron registered: daily at 3am → $BACKUP_DIR"
fi

# ── 10. First launch ─────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  SETUP COMPLETE — Next steps before going live:"
echo ""
echo "  1. Edit ALL .env files and fill in real credentials:"
echo "       $INSTALL_DIR/.env"
echo "       $INSTALL_DIR/apps/quantpipe/.env"
echo "       $INSTALL_DIR/apps/studybuddy-web/.env"
echo "       $INSTALL_DIR/apps/studybuddy-ai/.env"
echo ""
echo "  2. In Cloudflare, create A records pointing these"
echo "     subdomains to this server's IP:"
echo "       quantpipe.banschick.com → $(curl -s ifconfig.me 2>/dev/null || echo '<server-ip>')"
echo "       studybuddy.banschick.com → same IP"
echo "     Enable Cloudflare proxy (orange cloud) on each."
echo ""
echo "  3. When ready, start everything:"
echo "       cd $INSTALL_DIR && docker compose up -d"
echo ""
echo "  4. Tail logs to confirm all containers are healthy:"
echo "       docker compose ps"
echo "       docker compose logs -f"
echo ""
echo "  5. Enable Cloudflare Access for QuantPipe (Zero Trust"
echo "     → Access → Applications → Add quantpipe.banschick.com)"
echo "════════════════════════════════════════════════════════"
