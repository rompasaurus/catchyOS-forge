#!/usr/bin/env bash
#
# Setup Claude Code CLI on CachyOS.
# Installs Node.js if missing, then installs Claude Code globally via npm.
#
# Run with: bash scripts/setup-claude-code.sh
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
err()  { echo -e "${RED}[✗]${NC} $*"; }

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │        Claude Code CLI Setup              │"
echo "  │           CachyOS / Arch                  │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Step 1: Ensure Node.js and npm are installed ────────────────────────────

if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    info "Installing Node.js and npm..."
    sudo pacman -S --needed --noconfirm nodejs npm
    log "Node.js $(node --version) installed."
else
    log "Node.js $(node --version) already installed."
fi

# ─── Step 2: Install Claude Code ─────────────────────────────────────────────

if command -v claude &>/dev/null; then
    CURRENT_VERSION=$(claude --version 2>/dev/null || echo "unknown")
    log "Claude Code already installed (${CURRENT_VERSION})."
    info "Checking for updates..."
    sudo npm update -g @anthropic-ai/claude-code
else
    info "Installing Claude Code..."
    sudo npm install -g @anthropic-ai/claude-code
fi

# ─── Step 3: Verify ─────────────────────────────────────────────────────────

echo ""
if command -v claude &>/dev/null; then
    INSTALLED_VERSION=$(claude --version 2>/dev/null || echo "unknown")
    log "Claude Code installed successfully!"
    echo -e "  Version: ${CYAN}${INSTALLED_VERSION}${NC}"
    echo -e "  Path:    ${CYAN}$(which claude)${NC}"
    echo ""
    echo "  Run ${CYAN}claude${NC} to start an interactive session."
    echo "  Run ${CYAN}claude --help${NC} for all options."
else
    err "Claude Code installation failed."
    echo "  Try manually: sudo npm install -g @anthropic-ai/claude-code"
    exit 1
fi

echo ""
log "Done!"
