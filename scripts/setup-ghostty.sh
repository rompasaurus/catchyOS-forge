#!/usr/bin/env bash
#
# setup-ghostty.sh — Install Ghostty and deploy keybind config.
# Safe to run multiple times.
#
# Usage: bash scripts/setup-ghostty.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIGS="$PROJECT_DIR/configs"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │        Ghostty Terminal Setup             │"
echo "  │     Install + Keybind Config Deploy       │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Install Ghostty ────────────────────────────────────────────────────────

if command -v ghostty &>/dev/null; then
    log "Ghostty already installed"
else
    info "Installing Ghostty from AUR..."
    if command -v yay &>/dev/null; then
        yay -S --needed --noconfirm ghostty
    elif command -v paru &>/dev/null; then
        paru -S --needed --noconfirm ghostty
    else
        err "No AUR helper found (yay or paru). Install one first."
        exit 1
    fi
    log "Ghostty installed."
fi

# ─── Deploy Ghostty config ─────────────────────────────────────────────────

GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
GHOSTTY_CONFIG="$GHOSTTY_CONFIG_DIR/config"
FORGE_CONFIG="$CONFIGS/ghostty/config"

if [ ! -f "$FORGE_CONFIG" ]; then
    err "configs/ghostty/config not found in forge repo!"
    exit 1
fi

mkdir -p "$GHOSTTY_CONFIG_DIR"

if [ -f "$GHOSTTY_CONFIG" ]; then
    cp "$GHOSTTY_CONFIG" "$GHOSTTY_CONFIG.bak"
    info "Backed up existing config to config.bak"
fi

cp "$FORGE_CONFIG" "$GHOSTTY_CONFIG"
log "Deployed Ghostty config from forge"

# ─── Done ───────────────────────────────────────────────────────────────────

echo ""
log "Ghostty setup complete!"
info "  Config: ~/.config/ghostty/config"
info "  Restart Ghostty to pick up new keybinds."
echo ""
