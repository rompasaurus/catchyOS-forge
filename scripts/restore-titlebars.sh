#!/usr/bin/env bash
# restore-titlebars.sh — Re-enable title bars on tiled windows (Krohnkite).
#
# Krohnkite's "noTileBorder" option hides title bars on tiled windows.
# This script sets it back to false and reloads KWin.
#
# Usage:  bash scripts/restore-titlebars.sh

set -euo pipefail

log()  { echo -e "\e[32m[✓]\e[0m $*"; }
info() { echo -e "\e[34m[i]\e[0m $*"; }

KWIN_CFG="$HOME/.config/kwinrc"

info "Setting noTileBorder=false in kwinrc..."
kwriteconfig6 --file kwinrc --group Script-krohnkite --key noTileBorder false
log "kwinrc updated."

info "Reloading KWin..."
if qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null; then
    log "KWin reloaded — title bars should be visible now."
else
    echo -e "\e[33m[!]\e[0m Could not reload KWin via DBus — log out and back in to apply."
fi
