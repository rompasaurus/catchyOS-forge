#!/usr/bin/env bash
#
# setup-anki.sh — Install Anki spaced-repetition flashcards.
# Safe to run multiple times.
#
# Prefers the official upstream binary (anki-bin from AUR, most up to date),
# falling back to the official repo package (anki via pacman).
#
# Usage: bash scripts/setup-anki.sh
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

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │            Anki Flashcards Setup          │"
echo "  │      Spaced-Repetition Learning App       │"
echo "  │            CachyOS / Arch                 │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Already installed? ──────────────────────────────────────────────────────

if command -v anki &>/dev/null; then
    log "Anki already installed ($(anki --version 2>/dev/null | head -1 || echo 'version unknown'))"
    info "Launch it from your app menu or run: anki"
    exit 0
fi

# ─── Install ─────────────────────────────────────────────────────────────────

AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
fi

if [ -n "$AUR_HELPER" ]; then
    info "Installing official Anki binary (anki-bin) from AUR via $AUR_HELPER..."
    if "$AUR_HELPER" -S --needed --noconfirm anki-bin; then
        log "Anki installed (anki-bin)."
    else
        warn "anki-bin failed; falling back to official repo package (anki)..."
        sudo pacman -S --needed --noconfirm anki
        log "Anki installed (pacman)."
    fi
else
    warn "No AUR helper (yay/paru) found — using official repo package (anki)."
    info "Installing anki from the official repositories..."
    sudo pacman -S --needed --noconfirm anki
    log "Anki installed (pacman)."
fi

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
log "Anki setup complete!"
info "  Launch from your app menu or run: anki"
info "  Sync your decks with a free AnkiWeb account: https://ankiweb.net"
echo ""
