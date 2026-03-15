#!/usr/bin/env bash
# Install JetBrains Toolbox App on CachyOS (Arch) via AUR.
# Run with: bash scripts/setup-jetbrains.sh

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
echo "  │    JetBrains Toolbox Installer            │"
echo "  │           CachyOS / Arch                  │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Dependencies ─────────────────────────────────────────────────────────────

info "Installing dependencies..."
sudo pacman -S --needed --noconfirm fuse2

# ─── Install JetBrains Toolbox from AUR ───────────────────────────────────────

if pacman -Qi jetbrains-toolbox &>/dev/null 2>&1; then
    warn "JetBrains Toolbox is already installed."
else
    info "Installing JetBrains Toolbox from AUR..."
    paru -S --needed --noconfirm jetbrains-toolbox
    log "JetBrains Toolbox installed."
fi

# ─── Launch Toolbox ──────────────────────────────────────────────────────────

echo ""
log "Launching JetBrains Toolbox..."
jetbrains-toolbox &>/dev/null &

echo ""
log "Done! From Toolbox you can install:"
echo "  - IntelliJ IDEA Ultimate  (Java, Kotlin, Spring)"
echo "  - WebStorm                (JavaScript, TypeScript)"
echo "  - PyCharm                 (Python)"
echo "  - CLion                   (C/C++, Rust)"
echo "  - GoLand                  (Go)"
echo "  - Rider                   (.NET, C#, Unity)"
echo "  - PhpStorm                (PHP)"
echo "  - RubyMine                (Ruby)"
echo "  - DataGrip                (SQL, Databases)"
echo "  - RustRover               (Rust)"
echo ""
echo "Toolbox auto-starts on login and keeps all IDEs updated."
echo "You'll need a JetBrains license to use the IDEs."
