#!/usr/bin/env bash
#
# Full Zsh environment setup: Oh My Zsh, plugins, and zshrc config.
# Safe to run multiple times.
#
# Usage: bash scripts/setup-zshrc.sh
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
echo "  │        Zsh Environment Setup              │"
echo "  │   Oh My Zsh + Plugins + Config Deploy     │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Ensure zsh is installed ──────────────────────────────────────────────────

if ! command -v zsh &>/dev/null; then
    info "Installing zsh..."
    sudo pacman -S --needed --noconfirm zsh
    log "zsh installed."
else
    log "zsh already installed"
fi

# ─── Install Oh My Zsh ───────────────────────────────────────────────────────

if [ -d "$HOME/.oh-my-zsh" ]; then
    log "Oh My Zsh already installed"
else
    info "Installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log "Oh My Zsh installed."
fi

# ─── Install zsh-autosuggestions plugin ───────────────────────────────────────

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    log "zsh-autosuggestions plugin already installed"
else
    info "Installing zsh-autosuggestions plugin..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    log "zsh-autosuggestions installed."
fi

# ─── Deploy zshrc config ─────────────────────────────────────────────────────

if [ -f "$CONFIGS/zshrc" ]; then
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
        info "Backed up existing .zshrc to .zshrc.bak"
    fi
    cp "$CONFIGS/zshrc" "$HOME/.zshrc"
    log "Deployed .zshrc from forge configs"
else
    err "configs/zshrc not found in forge repo!"
    exit 1
fi

# ─── Set zsh as default shell ─────────────────────────────────────────────────

CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
ZSH_PATH="$(which zsh)"

if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
    log "zsh is already the default shell"
else
    info "Setting zsh as default shell..."
    chsh -s "$ZSH_PATH"
    log "Default shell changed to zsh"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
log "Zsh environment setup complete!"
info "  Run: exec zsh   (to reload)"
echo ""
