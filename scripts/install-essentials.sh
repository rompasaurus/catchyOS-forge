#!/usr/bin/env bash
#
# Install essential CLI tools on CachyOS (Arch).
# Run with: bash scripts/install-essentials.sh
#
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
echo "  │   Install Essential CLI Tools             │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Pacman packages ─────────────────────────────────────────────────────────

info "Installing pacman packages..."
sudo pacman -S --needed --noconfirm \
    zsh \
    bat eza fd ripgrep fzf zoxide direnv btop duf trash-cli \
    tmux micro starship \
    jq dust \
    htop ncdu \
    git-delta tig \
    lazygit lazydocker \
    python-pipx \
    rust cargo \
    go

log "Pacman packages installed."

# ─── AUR packages ────────────────────────────────────────────────────────────

info "Installing AUR packages..."
paru -S --needed --noconfirm \
    doggo \
    tre-command \
    gum

log "AUR packages installed."

# ─── Oh My Zsh + plugins ──────────────────────────────────────────────────────

if [ -d "$HOME/.oh-my-zsh" ]; then
    log "Oh My Zsh already installed"
else
    info "Installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log "Oh My Zsh installed."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    log "zsh-autosuggestions plugin already installed"
else
    info "Installing zsh-autosuggestions plugin..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    log "zsh-autosuggestions installed."
fi

# ─── mise (version manager) ─────────────────────────────────────────────────

if command -v mise &>/dev/null; then
    log "mise already installed"
else
    info "Installing mise..."
    curl https://mise.run | sh
fi

# ─── thefuck (command corrector) ─────────────────────────────────────────────

if command -v thefuck &>/dev/null; then
    log "thefuck already installed"
else
    info "Installing thefuck via pipx..."
    pipx ensurepath
    pipx install thefuck
fi

# ─── Verify ──────────────────────────────────────────────────────────────────

echo ""
info "Verification:"
for cmd in zoxide fzf starship direnv mise thefuck bat eza fd dust duf rg tre btop doggo lazygit lazydocker; do
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $cmd"
    else
        echo -e "  ${YELLOW}✗${NC} $cmd (not found)"
    fi
done

echo ""
log "Done!"
