#!/usr/bin/env bash
#
# Install & configure Window Gaps for KDE Plasma 6.
# Adds gaps around snapped/tiled windows. Based on nclarius/tile-gaps,
# ported to KWin 6 API.
#
# Usage:
#   bash scripts/setup-tile-gaps.sh              # Install with defaults
#   bash scripts/setup-tile-gaps.sh --configure  # Change gap values
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

CUR_LEFT=$(get_current gapLeft 16)
CUR_RIGHT=$(get_current gapRight 16)
CUR_TOP=$(get_current gapTop 52)
CUR_BOTTOM=$(get_current gapBottom 76)
CUR_MID=$(get_current gapMid 16)

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
    local left="$1" right="$2" top="$3" bottom="$4" mid="$5"

    kwriteconfig6 --file kwinrc --group Script-tilegaps --key gapLeft "$left"
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key gapRight "$right"
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key gapTop "$top"
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key gapBottom "$bottom"
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key gapMid "$mid"
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key panelTop false
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key panelBottom false
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key panelLeft false
    kwriteconfig6 --file kwinrc --group Script-tilegaps --key panelRight false
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
    echo "    Left:    ${1}px"
    echo "    Right:   ${2}px"
    echo "    Top:     ${3}px  (account for top panel)"
    echo "    Bottom:  ${4}px  (account for bottom panel)"
    echo "    Between: ${5}px  (gap between adjacent windows)"
    echo ""
}

configure() {
    echo -e "${CYAN}"
    echo "  ┌──────────────────────────────────────────┐"
    echo "  │    Window Gaps Configuration              │"
    echo "  │   Adjust gap sizes (in pixels)            │"
    echo "  └──────────────────────────────────────────┘"
    echo -e "${NC}"

    show_config "$CUR_LEFT" "$CUR_RIGHT" "$CUR_TOP" "$CUR_BOTTOM" "$CUR_MID"

    echo "  Enter new values (press Enter to keep current):"
    echo ""

    local new_left new_right new_top new_bottom new_mid

    prompt_value "Left gap"           "$CUR_LEFT"   new_left
    prompt_value "Right gap"          "$CUR_RIGHT"  new_right
    prompt_value "Top gap (panel)"    "$CUR_TOP"    new_top
    prompt_value "Bottom gap (panel)" "$CUR_BOTTOM" new_bottom
    prompt_value "Between windows"    "$CUR_MID"    new_mid

    echo ""
    info "Applying configuration..."
    apply_config "$new_left" "$new_right" "$new_top" "$new_bottom" "$new_mid"
    reload_kwin

    log "Configuration applied!"
    show_config "$new_left" "$new_right" "$new_top" "$new_bottom" "$new_mid"
}

# ─── Main ─────────────────────────────────────────────────────────────────

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │    Window Gaps — Tile Gap Manager         │"
echo "  │   Gaps for snapped/tiled windows          │"
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
        info "Applying default gap configuration..."
        apply_config "$CUR_LEFT" "$CUR_RIGHT" "$CUR_TOP" "$CUR_BOTTOM" "$CUR_MID"
        reload_kwin
        log "Window Gaps installed and active!"
        show_config "$CUR_LEFT" "$CUR_RIGHT" "$CUR_TOP" "$CUR_BOTTOM" "$CUR_MID"
        echo "  To adjust gaps:     bash scripts/setup-tile-gaps.sh --configure"
        echo "  To uninstall:       bash scripts/setup-tile-gaps.sh --uninstall"
        ;;
esac
