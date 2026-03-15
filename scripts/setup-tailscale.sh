#!/usr/bin/env bash
# Install and enable Tailscale on CachyOS (Arch).
# Run with: bash scripts/setup-tailscale.sh

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │        Tailscale Installer                │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Install Tailscale ───────────────────────────────────────────────────────

if command -v tailscale &>/dev/null; then
    warn "Tailscale is already installed: $(tailscale version | head -1)"
else
    info "Installing Tailscale..."
    sudo pacman -S --needed --noconfirm tailscale
    log "Tailscale installed."
fi

# ─── Enable and start the daemon ─────────────────────────────────────────────

if systemctl is-active --quiet tailscaled; then
    log "tailscaled is already running."
else
    info "Enabling and starting tailscaled..."
    sudo systemctl enable --now tailscaled
    log "tailscaled started."
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
log "Tailscale is ready!"
echo ""
echo "  Run 'sudo tailscale up' to join your tailnet."
echo "  Run 'tailscale status' to check connection."
