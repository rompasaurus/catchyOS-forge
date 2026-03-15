#!/usr/bin/env bash
# Install Docker Engine + Docker Desktop on CachyOS (Arch).
# Run with: bash scripts/setup-docker.sh

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

echo -e "${CYAN}"
echo "  ┌────────────────────────────────────────────┐"
echo "  │   Docker Engine + Docker Desktop Installer  │"
echo "  │              CachyOS / Arch                 │"
echo "  └────────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Install Docker Engine ────────────────────────────────────────────────────

if command -v docker &>/dev/null; then
    warn "Docker is already installed: $(docker --version)"
else
    info "Installing Docker Engine..."
    sudo pacman -S --needed --noconfirm docker docker-compose docker-buildx
    sudo systemctl enable --now docker.service
    log "Docker Engine installed: $(docker --version)"
fi

# ─── Add user to docker group ─────────────────────────────────────────────────

if ! groups "$USER" | grep -qw docker; then
    info "Adding $USER to the docker group..."
    sudo usermod -aG docker "$USER"
    warn "You'll need to log out and back in for group changes to take effect."
else
    log "$USER is already in the docker group."
fi

# ─── Install Docker Desktop (AUR) ────────────────────────────────────────────

if pacman -Qi docker-desktop &>/dev/null 2>&1; then
    warn "Docker Desktop is already installed. Skipping."
else
    # Docker Desktop bundles its own compose — remove the standalone plugin
    # to avoid the package conflict.
    if pacman -Qi docker-compose &>/dev/null 2>&1; then
        info "Removing docker-compose (Docker Desktop bundles its own)..."
        sudo pacman -Rdd --noconfirm docker-compose
    fi

    # Install qemu-base as the qemu provider (lightest option) then Desktop.
    info "Installing qemu-base dependency..."
    sudo pacman -S --needed --noconfirm qemu-base

    info "Installing Docker Desktop from AUR..."
    paru -S --needed --noconfirm docker-desktop
    log "Docker Desktop installed."
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
log "All done! Next steps:"
echo "  1. Log out and back in (for docker group permissions)"
echo "  2. Launch Docker Desktop from your app menu or run:"
echo "     systemctl --user start docker-desktop"
