#!/usr/bin/env bash
#
# setup-touchpad-gestures.sh — Enable KDE Plasma 6 native 3-finger touchpad gestures.
# Plasma 6 has built-in gesture support — this script just ensures it's enabled
# and disables 4-finger gestures to avoid double-triggering.
#
# Default 3-finger gestures (natural/macOS direction):
#   3-finger swipe right → previous desktop (content follows finger)
#   3-finger swipe left  → next desktop
#   3-finger swipe up    → KDE Overview (all windows + desktops)
#   3-finger swipe down  → Show Desktop (minimize all)
#
# NOTE: On Wayland, KWin IS the compositor. Calling KWin.reconfigure with bad
# config can crash the session. This script avoids writing gesture action keys
# (Plasma 6 handles 3-finger mapping internally) and requires a logout/login
# instead of a live reconfigure to be safe.
#
# Run with: bash scripts/setup-touchpad-gestures.sh
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
echo "  │   Touchpad Gesture Setup                  │"
echo "  │   3-Finger Swipe → Desktop Actions        │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Check for kwriteconfig6 ────────────────────────────────────────────────

if ! command -v kwriteconfig6 &>/dev/null; then
    err "kwriteconfig6 not found. This script requires KDE Plasma 6."
    exit 1
fi

# ─── Stop and disable libinput-gestures if running (not needed) ──────────────

if command -v libinput-gestures-setup &>/dev/null; then
    info "Stopping libinput-gestures (using KDE native gestures instead)..."
    libinput-gestures-setup stop 2>/dev/null || true
    rm -f "$HOME/.config/autostart/libinput-gestures.desktop" 2>/dev/null
    log "libinput-gestures disabled (KDE native gestures are more reliable on Wayland)"
fi

# ─── Enable KDE touchpad gestures ───────────────────────────────────────────
# Plasma 6 handles 3-finger swipe actions internally (desktop switch, overview,
# show desktop). We only need to make sure the gesture system is turned on.

info "Enabling KDE touchpad gesture system..."
kwriteconfig6 --file kwinrc --group Wayland --key EnableTouchpadGestures "true"
kwriteconfig6 --file kwinrc --group Plugins --key kwin_gesturesEnabled "true"
log "KDE gesture system enabled"

# ─── Disable 4-finger gestures (avoid double-triggering) ────────────────────

info "Disabling 4-finger gestures to avoid conflicts..."
for dir in Up Down Left Right; do
    kwriteconfig6 --file kwinrc --group Gestures --key "TouchpadFourFingerSwipe${dir}" "None"
done
log "4-finger gestures disabled"

# ─── Clean up any stale 3-finger gesture keys ───────────────────────────────
# These keys are not valid KWin config — Plasma 6 handles 3-finger actions
# internally. Remove them if they exist from a previous run.

for dir in Left Right Up Down; do
    kwriteconfig6 --file kwinrc --group Gestures --key "TouchpadThreeFingerSwipe${dir}" --delete 2>/dev/null || true
done

# ─── Done (no live reconfigure — requires logout) ───────────────────────────
# Intentionally NOT calling org.kde.KWin.reconfigure here. On Wayland, KWin is
# the compositor and a reconfigure with unexpected config can crash the session.
# A logout/login is the safe way to pick up these changes.

echo ""
log "Touchpad gestures configured!"
echo ""
echo "  3-finger gestures (natural direction, Plasma 6 defaults):"
echo "    Swipe right → previous desktop"
echo "    Swipe left  → next desktop"
echo "    Swipe up    → KDE Overview (all windows + desktops)"
echo "    Swipe down  → Show Desktop (minimize all)"
echo ""
warn "Log out and back in for changes to take effect."
echo "  Config: ~/.config/kwinrc [Wayland] and [Plugins] sections"
echo ""
