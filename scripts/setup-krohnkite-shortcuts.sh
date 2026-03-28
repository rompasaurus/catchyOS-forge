#!/usr/bin/env bash
#
# setup-krohnkite-shortcuts.sh — Set up vim-style Krohnkite tiling shortcuts.
#
# Shortcuts:
#   Meta + H/J/K/L          — Focus left/down/up/right
#   Meta+Shift + H/J/K/L    — Move window left/down/up/right
#   Meta+Ctrl + H/J/K/L     — Resize (shrink width / shrink height / grow height / grow width)
#   Meta+Ctrl + [ / ]       — Cycle previous/next layout
#
# Run with: bash scripts/setup-krohnkite-shortcuts.sh
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
echo "  │   Krohnkite Shortcut Setup                │"
echo "  │   Vim-style Tiling Window Management      │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

if ! command -v kwriteconfig6 &>/dev/null; then
    warn "kwriteconfig6 not found — are you running KDE Plasma 6?"
    exit 1
fi

# ─── Focus: Meta + H/J/K/L ──────────────────────────────────────────────────

info "Setting focus shortcuts (Meta + H/J/K/L)..."
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteFocusLeft "Meta+H,none,Krohnkite: Focus Left"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteFocusDown "Meta+J,none,Krohnkite: Focus Down"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteFocusUp "Meta+K,none,Krohnkite: Focus Up"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteFocusRight "Meta+L,none,Krohnkite: Focus Right"
log "Focus shortcuts set"

# ─── Move: Meta+Shift + H/J/K/L ─────────────────────────────────────────────

info "Setting move shortcuts (Meta+Shift + H/J/K/L)..."
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteShiftLeft "Meta+Shift+H,none,Krohnkite: Move Left"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteShiftDown "Meta+Shift+J,none,Krohnkite: Move Down/Next"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteShiftUp "Meta+Shift+K,none,Krohnkite: Move Up/Prev"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteShiftRight "Meta+Shift+L,none,Krohnkite: Move Right"
log "Move shortcuts set"

# ─── Resize: Meta+Ctrl + H/J/K/L ────────────────────────────────────────────

info "Setting resize shortcuts (Meta+Ctrl + H/J/K/L)..."
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteShrinkWidth "Meta+Ctrl+H,none,Krohnkite: Shrink Width"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteShrinkHeight "Meta+Ctrl+J,none,Krohnkite: Shrink Height"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteGrowHeight "Meta+Ctrl+K,none,Krohnkite: Grow Height"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkitegrowWidth "Meta+Ctrl+L,none,Krohnkite: Grow Width"
log "Resize shortcuts set"

# ─── Layout cycle: Meta+Ctrl + [ / ] ────────────────────────────────────────

info "Setting layout cycle shortcuts (Meta+Ctrl + [ / ])..."
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkitePreviousLayout "Meta+Ctrl+[,none,Krohnkite: Previous Layout"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key KrohnkiteNextLayout "Meta+Ctrl+],none,Krohnkite: Next Layout"
log "Layout cycle shortcuts set"

# ─── Remove Meta+L conflict with Lock Session ───────────────────────────────

info "Removing Meta+L from Lock Session to avoid conflict..."
kwriteconfig6 --file kglobalshortcutsrc --group ksmserver --key "Lock Session" "Screensaver,Meta+L\tScreensaver,Lock Session"
log "Lock Session now uses Screensaver key only"

# ─── Reload shortcuts ───────────────────────────────────────────────────────

info "Reloading shortcuts..."
dbus-send --session --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:8 int32:0
log "KWin reconfigured"

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
log "Krohnkite shortcuts configured!"
echo ""
echo "  Focus:   Meta + H/J/K/L"
echo "  Move:    Meta+Shift + H/J/K/L"
echo "  Resize:  Meta+Ctrl + H/J/K/L"
echo "  Layout:  Meta+Ctrl + [ / ]"
echo ""
warn "If shortcuts don't work immediately, log out and back in."
echo ""
