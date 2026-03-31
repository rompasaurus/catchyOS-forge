#!/usr/bin/env bash
#
# setup-rounded-corners.sh — Install KDE Rounded Corners KWin effect.
# Rounds all four window corners (top & bottom) in KDE Plasma.
# Safe to run multiple times (rebuilds if already installed).
#
# Usage: bash scripts/setup-rounded-corners.sh
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
echo "  │      KDE Rounded Corners Setup            │"
echo "  │    Round all 4 window corners in Plasma   │"
echo "  │             CachyOS / Arch                │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Install build dependencies ──────────────────────────────────────────────

info "Installing build dependencies..."
sudo pacman -S --needed --noconfirm git cmake extra-cmake-modules kwin

# ─── Clone or update the repo ────────────────────────────────────────────────

BUILD_DIR="/tmp/KDE-Rounded-Corners"

if [ -d "$BUILD_DIR" ]; then
    info "Updating existing clone..."
    git -C "$BUILD_DIR" pull --ff-only || {
        warn "Pull failed, re-cloning..."
        rm -rf "$BUILD_DIR"
        git clone https://github.com/matinlotfali/KDE-Rounded-Corners.git "$BUILD_DIR"
    }
else
    info "Cloning KDE-Rounded-Corners..."
    git clone https://github.com/matinlotfali/KDE-Rounded-Corners.git "$BUILD_DIR"
fi

# ─── Build & install ─────────────────────────────────────────────────────────

info "Building..."
cd "$BUILD_DIR"
rm -rf build
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j"$(nproc)"

info "Installing (requires sudo)..."
sudo make install

# ─── Enable the KWin effect ──────────────────────────────────────────────────

info "Enabling ShapeCorners KWin effect..."
KWIN_CFG="$HOME/.config/kwinrc"

# Add the effect to the enabled list if not already present
if grep -q "shapecornersEnabled=true" "$KWIN_CFG" 2>/dev/null; then
    log "Effect already enabled in kwinrc"
else
    kwriteconfig6 --file kwinrc --group Plugins --key shapecornersEnabled true
    log "Effect enabled in kwinrc"
fi

# ─── Reload KWin ─────────────────────────────────────────────────────────────

info "Reloading KWin..."
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || warn "Could not reload KWin via DBus — log out and back in to apply."

# ─── Cleanup ─────────────────────────────────────────────────────────────────

rm -rf "$BUILD_DIR"
log "Cleaned up build directory"

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
log "KDE Rounded Corners setup complete!"
info "  All four window corners are now rounded."
info "  Configure radius: System Settings → Desktop Effects → ShapeCorners"
echo ""
