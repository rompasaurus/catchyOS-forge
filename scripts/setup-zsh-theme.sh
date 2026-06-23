#!/usr/bin/env bash
#
# setup-zsh-theme.sh — Slick prompt + icons for zsh.
#
# Deploys the Starship "Catppuccin Powerline" prompt (Mocha flavor) with the
# CachyOS logo and a two-line input row, installs the MesloLGS Nerd Font so
# every glyph renders (no "tofu" squares), and points VSCode (Code-OSS / Code /
# VSCodium) at that font. Ghostty's font + theme live in configs/ghostty and are
# applied by setup-ghostty.sh.
#
# The prompt is generated from Starship's OFFICIAL preset at runtime — so it
# stays current and the private-use powerline glyphs are never corrupted by
# copy/paste — then patched with our two tweaks:
#   a) the CachyOS icon (reusing the preset's own Arch glyph)
#   b) the two-line layout (input row drops under the powerline)
#
# Safe to run multiple times (idempotent).
#
# Usage: bash scripts/setup-zsh-theme.sh
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
echo "  │       Zsh Theme + Icons Setup             │"
echo "  │  Starship Catppuccin + MesloLGS Nerd Font │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

NERD_FONT_NAME="MesloLGS Nerd Font"
NERD_FONT_PKG="ttf-meslo-nerd"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
STARSHIP_PRESET="catppuccin-powerline"

# ─── 1. Starship prompt engine ────────────────────────────────────────────────

if command -v starship &>/dev/null; then
    log "starship already installed"
else
    info "Installing starship..."
    sudo pacman -S --needed --noconfirm starship
    log "starship installed."
fi

# ─── 2. Nerd Font (the icons) ─────────────────────────────────────────────────

if fc-list 2>/dev/null | grep -qiF "$NERD_FONT_NAME"; then
    log "$NERD_FONT_NAME already installed"
else
    info "Installing $NERD_FONT_NAME ($NERD_FONT_PKG)..."
    sudo pacman -S --needed --noconfirm "$NERD_FONT_PKG"
    fc-cache -f >/dev/null 2>&1 || true
    log "$NERD_FONT_NAME installed."
fi

# ─── 3. Deploy Starship prompt (official preset + our two tweaks) ─────────────

mkdir -p "$(dirname "$STARSHIP_CONFIG")"
if [ -f "$STARSHIP_CONFIG" ]; then
    cp "$STARSHIP_CONFIG" "$STARSHIP_CONFIG.bak"
    info "Backed up existing starship.toml to starship.toml.bak"
fi

info "Generating '$STARSHIP_PRESET' preset (Catppuccin Mocha)..."
starship preset "$STARSHIP_PRESET" -o "$STARSHIP_CONFIG"

# tweak a) add the CachyOS logo, reusing the EXACT Arch glyph from the preset
if ! grep -q '^CachyOS' "$STARSHIP_CONFIG"; then
    perl -CSD -i -pe 's/^(Arch = ")(.*)(")\s*$/CachyOS = "$2"\n$1$2$3\n/' "$STARSHIP_CONFIG"
    log "Added CachyOS icon to the OS segment"
else
    log "CachyOS icon already present"
fi

# tweak b) two-line prompt — input row drops under the powerline.
# (line_break is the only 'disabled = true' line in this preset.)
perl -i -pe 's/^disabled = true\s*$/disabled = false/' "$STARSHIP_CONFIG"
log "Enabled two-line prompt"

# ─── 4. Ensure starship initialises in ~/.zshrc ───────────────────────────────
# (setup-zshrc.sh already includes this; handled here too so the theme works
#  even if this script is run standalone.)

if [ -f "$HOME/.zshrc" ] && grep -q 'starship init zsh' "$HOME/.zshrc"; then
    log "starship init already present in ~/.zshrc"
else
    info "Adding starship init to ~/.zshrc..."
    {
        printf '\n# Starship prompt (catchyOS-forge)\n'
        printf 'command -v starship &>/dev/null && eval "$(starship init zsh)"\n'
    } >> "$HOME/.zshrc"
    log "starship init added."
fi

# ─── 5. Point VSCode at the Nerd Font (terminal renders icons too) ────────────

set_vscode_font() {
    local settings="$1"
    [ -d "$(dirname "$settings")" ] || return 0   # variant not installed → skip
    if ! command -v python3 &>/dev/null; then
        warn "python3 not found; skipping VSCode font ($settings)"
        return 0
    fi
    python3 - "$settings" "$NERD_FONT_NAME" <<'PY'
import json, sys, os
path, font = sys.argv[1], sys.argv[2]
data = {}
if os.path.isfile(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception:
        data = {}
data["terminal.integrated.fontFamily"] = font
data.setdefault("terminal.integrated.fontSize", 13)
with open(path, "w") as f:
    json.dump(data, f, indent=4)
    f.write("\n")
PY
    log "Set integrated-terminal font in $settings"
}

for variant in "Code - OSS" "Code" "VSCodium"; do
    set_vscode_font "$HOME/.config/$variant/User/settings.json"
done

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
log "Zsh theme + icons setup complete!"
info "  Prompt: Starship '$STARSHIP_PRESET' — Catppuccin Mocha, two-line, CachyOS logo"
info "  Font:   $NERD_FONT_NAME"
info "  Reload: exec zsh"
warn "  Point your terminal's font at '$NERD_FONT_NAME':"
warn "    • Ghostty → run setup-ghostty.sh (config ships the font)"
warn "    • VSCode  → set above; reload window to apply"
echo ""
