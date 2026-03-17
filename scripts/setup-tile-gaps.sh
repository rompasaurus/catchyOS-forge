#!/usr/bin/env bash
#
# Install & configure Window Gaps for KDE Plasma 6.
# Adds gaps around snapped/tiled windows. Automatically detects panels
# and adds extra gap on those edges.
#
# Usage:
#   bash scripts/setup-tile-gaps.sh              # Install with defaults
#   bash scripts/setup-tile-gaps.sh --configure  # Change gap values
#   bash scripts/setup-tile-gaps.sh --uninstall  # Remove
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/tile-gaps"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

# ─── Read current values (defaults for fresh install) ─────────────────────

get_current() {
    kreadconfig6 --file kwinrc --group Script-tilegaps --key "$1" --default "$2" 2>/dev/null || echo "$2"
}

CUR_BASE=$(get_current gapBase 16)
CUR_MID=$(get_current gapMid 16)
CUR_PANEL_PAD=$(get_current panelPadding 10)

# ─── Functions ────────────────────────────────────────────────────────────

install_plugin() {
    info "Installing tile-gaps KWin script..."
    if kpackagetool6 --type=KWin/Script -i "$PLUGIN_DIR" 2>/dev/null; then
        log "Installed tile-gaps KWin script."
    else
        kpackagetool6 --type=KWin/Script -u "$PLUGIN_DIR" 2>/dev/null
        log "Updated tile-gaps KWin script."
    fi
}

apply_config() {
    local base="$1" mid="$2" panel_pad="$3"

    kwriteconfig6 --file kwinrc --group Script-tilegaps --key gapBase "$base"
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key gapMid "$mid"
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key panelPadding "$panel_pad"
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key includeMaximized false
}

reload_kwin() {
    info "Reloading KWin..."
    kwriteconfig6 --file kwinrc --group Plugins --key tilegapsEnabled false
    qdbus6 org.kde.KWin /KWin reconfigure
    sleep 1
    kwriteconfig6 --file kwinrc --group Plugins --key tilegapsEnabled true
    qdbus6 org.kde.KWin /KWin reconfigure
}

prompt_value() {
    local label="$1" current="$2" var_name="$3"
    read -rp "  $label [$current]: " input
    eval "$var_name=${input:-$current}"
}

show_config() {
    echo ""
    echo "  Current gap configuration:"
    echo "    Base gap:       ${1}px  (gap on all screen edges)"
    echo "    Between windows: ${2}px  (gap between adjacent windows)"
    echo "    Panel padding:  ${3}px  (extra gap around detected panels)"
    echo ""
    echo "  Panels are auto-detected per monitor."
    echo "  Monitors without panels get only the base gap."
    echo ""
}

configure() {
    echo -e "${CYAN}"
    echo "  ┌──────────────────────────────────────────┐"
    echo "  │    Window Gaps Configuration              │"
    echo "  │   Adjust gap sizes (in pixels)            │"
    echo "  └──────────────────────────────────────────┘"
    echo -e "${NC}"

    show_config "$CUR_BASE" "$CUR_MID" "$CUR_PANEL_PAD"

    echo "  Enter new values (press Enter to keep current):"
    echo ""

    local new_base new_mid new_panel_pad

    prompt_value "Base gap (all edges)"     "$CUR_BASE"      new_base
    prompt_value "Between windows"          "$CUR_MID"       new_mid
    prompt_value "Extra padding for panels" "$CUR_PANEL_PAD" new_panel_pad

    echo ""
    info "Applying configuration..."
    apply_config "$new_base" "$new_mid" "$new_panel_pad"
    reload_kwin

    log "Configuration applied!"
    show_config "$new_base" "$new_mid" "$new_panel_pad"
}

# ─── Main ─────────────────────────────────────────────────────────────────

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │    Window Gaps — Tile Gap Manager         │"
echo "  │   Auto-detects panels per monitor         │"
echo "  │          KDE Plasma 6                     │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

case "${1:-}" in
    --configure|-c)
        configure
        ;;
    --uninstall)
        info "Disabling tile-gaps..."
        kwriteconfig6 --file kwinrc --group Plugins --key tilegapsEnabled false
        kpackagetool6 --type=KWin/Script -r tilegaps 2>/dev/null || true
        qdbus6 org.kde.KWin /KWin reconfigure
        log "Window Gaps uninstalled."
        ;;
    *)
        install_plugin
        info "Applying gap configuration..."
        apply_config "$CUR_BASE" "$CUR_MID" "$CUR_PANEL_PAD"
        reload_kwin
        log "Window Gaps installed and active!"
        show_config "$CUR_BASE" "$CUR_MID" "$CUR_PANEL_PAD"
        echo "  To adjust gaps:     bash scripts/setup-tile-gaps.sh --configure"
        echo "  To uninstall:       bash scripts/setup-tile-gaps.sh --uninstall"
        ;;
esac
