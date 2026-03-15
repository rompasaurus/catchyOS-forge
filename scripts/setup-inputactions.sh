#!/usr/bin/env bash
#
# Install InputActions (KWin plugin) and configure mouse back/forward buttons
# to trigger KDE Overview and Desktop Grid — replicating 4-finger swipe gestures.
#
#   Mouse Back  (button 8) → Overview        (4-finger swipe up equivalent)
#   Mouse Fwd   (button 9) → Desktop Grid    (4-finger swipe down equivalent)
#
# Run with: bash scripts/setup-inputactions.sh
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
err()  { echo -e "${RED}[!]${NC} $*"; }

CONFIG_DIR="$HOME/.config/inputactions"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │   InputActions Installer                  │"
echo "  │   Mouse → Overview / Desktop Grid         │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Check for AUR helper ─────────────────────────────────────────────────────

AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
else
    err "No AUR helper found (paru or yay). Install one first."
    exit 1
fi
log "Using AUR helper: $AUR_HELPER"

# ─── Check Wayland ────────────────────────────────────────────────────────────

if [ "${XDG_SESSION_TYPE:-}" != "wayland" ]; then
    warn "Session is '${XDG_SESSION_TYPE:-unknown}', not wayland."
    warn "InputActions KWin plugin requires Wayland. Continuing anyway..."
fi

# ─── Check Plasma version ─────────────────────────────────────────────────────

if command -v plasmashell &>/dev/null; then
    PLASMA_VERSION=$(plasmashell --version 2>/dev/null | grep -oP '[\d.]+' || echo "unknown")
    info "Plasma version: $PLASMA_VERSION"
else
    warn "Could not detect Plasma version."
fi

# ─── Install inputactions-kwin from AUR ────────────────────────────────────────

if pacman -Qi inputactions-kwin &>/dev/null; then
    log "inputactions-kwin already installed"
else
    info "Installing inputactions-kwin from AUR..."
    $AUR_HELPER -S --needed inputactions-kwin
    log "inputactions-kwin installed."
fi

# ─── Write config ─────────────────────────────────────────────────────────────

if [ -f "$CONFIG_FILE" ]; then
    warn "Config already exists at $CONFIG_FILE"
    BACKUP="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP"
    warn "Backed up to $BACKUP"
fi

mkdir -p "$CONFIG_DIR"

info "Writing InputActions config..."
cat > "$CONFIG_FILE" << 'EOF'
# InputActions config — mouse back/forward → Overview / Desktop Grid
# Config location: ~/.config/inputactions/config.yaml
#
# Mouse Back  (extra1 = button 8) → KDE Overview
# Mouse Fwd   (extra2 = button 9) → KDE Desktop Grid
#
# Docs: https://wiki.inputactions.org

mouse:
  gestures:
    # ── Mouse Back Button → Overview (4-finger swipe up) ──────────────────
    - type: press
      mouse_buttons: [extra1]
      actions:
        - on: end
          command: >-
            qdbus6 org.kde.kglobalaccel /component/kwin
            org.kde.kglobalaccel.Component.invokeShortcut "Overview"

    # ── Mouse Forward Button → Desktop Grid (4-finger swipe down) ─────────
    - type: press
      mouse_buttons: [extra2]
      actions:
        - on: end
          command: >-
            qdbus6 org.kde.kglobalaccel /component/kwin
            org.kde.kglobalaccel.Component.invokeShortcut "ShowDesktopGrid"
EOF

log "Config written to $CONFIG_FILE"

# ─── Enable the KWin effect ───────────────────────────────────────────────────

info "Enabling InputActions KWin effect..."
if qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect kwin_gestures 2>/dev/null; then
    log "KWin effect loaded."
else
    warn "Could not load KWin effect via qdbus6."
    warn "Try enabling it manually: System Settings → Desktop Effects → InputActions"
fi

# ─── Reload config ─────────────────────────────────────────────────────────────

info "Reloading InputActions config..."
if command -v inputactions &>/dev/null; then
    inputactions config reload 2>/dev/null && log "Config reloaded." || warn "Config reload command failed. It may reload automatically."
else
    warn "inputactions CLI not found. Config will be picked up on next KWin restart."
fi

# ─── Done ──────────────────────────────────────────────────────────────────────

echo ""
log "InputActions setup complete!"
echo ""
echo "  Button mapping:"
echo "    Mouse Back    → KDE Overview        (like 4-finger swipe up)"
echo "    Mouse Forward → KDE Desktop Grid    (like 4-finger swipe down)"
echo ""
echo "  Config file:  $CONFIG_FILE"
echo "  Edit config:  \$EDITOR $CONFIG_FILE"
echo "  Reload:       inputactions config reload"
echo ""
echo "  Emergency disable: hold Backspace + Space + Enter for 2 seconds"
echo ""
warn "If buttons don't respond, try logging out and back in."
warn "If the button names are wrong for your mouse, check with: libinput debug-events"
echo "  (look for BTN_SIDE / BTN_EXTRA or BTN_BACK / BTN_FORWARD)"
