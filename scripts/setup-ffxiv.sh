#!/usr/bin/env bash
#
# setup-ffxiv.sh — Install Final Fantasy XIV (Windows client) via XIVLauncher.
# Safe to run multiple times (re-run to update XIVLauncher).
#
# XIVLauncher.Core is the community Linux launcher. It downloads & manages its
# own Wine + DXVK, logs in to Square Enix, installs/patches the Windows game
# client and launches it. Installed as a per-user Flatpak (no sudo needed).
#
# Works for both Square Enix (standalone) and Steam-purchased accounts —
# for Steam accounts tick "Use Steam service account" and keep Steam running.
#
# Usage: bash scripts/setup-ffxiv.sh
#
set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }

APP_ID="dev.goats.xivlauncher"
GAME_DIR="${HOME}/Games/FFXIV"
REQUIRED_GB=100

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │        Final Fantasy XIV Setup            │"
echo "  │   Windows client via XIVLauncher (Wine)   │"
echo "  │            CachyOS / Arch                  │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Checks ──────────────────────────────────────────────────────────────────

if ! command -v flatpak >/dev/null; then
    err "flatpak not installed. Run: sudo pacman -S flatpak"
    exit 1
fi

mkdir -p "$GAME_DIR"
free_gb=$(df -BG --output=avail "$GAME_DIR" | tail -1 | tr -dc '0-9')
if (( free_gb < REQUIRED_GB )); then
    warn "Only ${free_gb}GB free at ${GAME_DIR} — the full game needs ~${REQUIRED_GB}GB."
else
    log "${free_gb}GB free at ${GAME_DIR}."
fi

# ─── Install XIVLauncher ─────────────────────────────────────────────────────

info "Ensuring user Flathub remote..."
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

if flatpak info --user "$APP_ID" >/dev/null 2>&1; then
    info "XIVLauncher already installed — updating..."
    flatpak update --user -y "$APP_ID"
else
    info "Installing XIVLauncher..."
    flatpak install --user -y flathub "$APP_ID"
fi
log "XIVLauncher installed."

# Let the sandbox see the game directory (and Steam, for Steam accounts).
flatpak override --user "$APP_ID" \
    --filesystem="$GAME_DIR" \
    --filesystem="${HOME}/.local/share/Steam:ro"
log "Flatpak permissions set for ${GAME_DIR}."

# ─── Done ────────────────────────────────────────────────────────────────────

echo
log "Setup complete. Launch 'XIVLauncher' from the app menu, or run:"
echo "    flatpak run ${APP_ID}"
echo
info "First launch:"
echo "  1. Settings (gear) → Game → Game Path: ${GAME_DIR}"
echo "  2. Settings → Wine: leave 'Managed by XIVLauncher' (DXVK on, Esync/Fsync on)"
echo "  3. Log in with your Square Enix ID (Steam buyers: tick 'Use Steam service"
echo "     account' and have Steam running). It will offer to install the game."
echo "  4. The download is ~90GB+; patching happens inside the launcher."
