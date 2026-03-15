#!/usr/bin/env bash
#
# Replace the Code - OSS green icon with the VS Code blue icon.
#
# Run with: bash scripts/setup-vscode-icon.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_SRC="$SCRIPT_DIR/../configs/icons/vscode.svg"
ICON_DST="$HOME/.local/share/icons/hicolor/scalable/apps/com.visualstudio.code.oss.svg"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }

info "Installing VS Code blue icon..."
mkdir -p "$(dirname "$ICON_DST")"
cp "$ICON_SRC" "$ICON_DST"

# Update icon cache
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

log "VS Code blue icon installed."
log "You may need to log out and back in for the icon to update everywhere."
