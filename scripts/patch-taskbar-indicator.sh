#!/usr/bin/env bash
#
# Patch the KDE Plasma taskbar indicator to use a uniform light gray
# instead of the accent-colored line on top of open apps.
#
# Creates a local theme override — does not modify system files.
# Run with: bash scripts/patch-taskbar-indicator.sh
#
set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

export INDICATOR_COLOR="#b0b0b0"   # light gray — change this to taste
export INDICATOR_OPACITY="0.60"    # uniform opacity for all states

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │   Taskbar Indicator Patch                 │"
echo "  │   Uniform light gray top line             │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Find the active Plasma desktop theme ────────────────────────────────────

SYSTEM_THEME_DIR="/usr/share/plasma/desktoptheme/default/widgets"
SOURCE_SVG="$SYSTEM_THEME_DIR/tasks.svgz"

if [ ! -f "$SOURCE_SVG" ]; then
    # Try breeze-dark
    SYSTEM_THEME_DIR="/usr/share/plasma/desktoptheme/breeze-dark/widgets"
    SOURCE_SVG="$SYSTEM_THEME_DIR/tasks.svgz"
fi

if [ ! -f "$SOURCE_SVG" ]; then
    echo "Could not find tasks.svgz in system theme directories."
    exit 1
fi

info "Source: $SOURCE_SVG"

# ─── Create local theme override directory ───────────────────────────────────

LOCAL_THEME_DIR="$HOME/.local/share/plasma/desktoptheme/default/widgets"
mkdir -p "$LOCAL_THEME_DIR"

# ─── Extract and patch the SVG ───────────────────────────────────────────────

WORK_DIR=$(mktemp -d)
cp "$SOURCE_SVG" "$WORK_DIR/tasks.svgz"
cd "$WORK_DIR"
gunzip -S .svgz tasks.svgz
mv tasks tasks.svg

info "Patching indicator color to $INDICATOR_COLOR (opacity $INDICATOR_OPACITY)..."

# Use awk for surgical edits — only modifies lines inside the target indicator
# groups. This avoids XML parsers mangling the SVG and avoids a global replace
# that would break other elements using currentColor.

awk -v color="$INDICATOR_COLOR" -v opacity="$INDICATOR_OPACITY" '
    /id="(focus-top|focus-topleft|focus-topright|normal-top|normal-topleft|normal-topright|hover-top|hover-topleft|hover-topright)"/ && !/north-|west-|east-/ {
        inside = 1
        patched++
        # Set opacity on the group element
        if (match($0, /opacity="[^"]*"/))
            $0 = substr($0, 1, RSTART-1) "opacity=\"" opacity "\"" substr($0, RSTART+RLENGTH)
        else
            sub(/>/, " opacity=\"" opacity "\">")
        # Replace fill="currentColor" on this line too
        gsub(/fill="currentColor"/, "fill=\"" color "\"")
        print
        next
    }
    inside && /<\/g>/ {
        inside = 0
    }
    inside {
        gsub(/fill="currentColor"/, "fill=\"" color "\"")
    }
    { print }
    END { print "Patched " patched " indicator elements" > "/dev/stderr" }
' tasks.svg > tasks_patched.svg

mv tasks_patched.svg tasks.svg

# ─── Recompress and install ──────────────────────────────────────────────────

gzip tasks.svg
mv tasks.svg.gz tasks.svgz
cp tasks.svgz "$LOCAL_THEME_DIR/tasks.svgz"

# Cleanup
rm -rf "$WORK_DIR"

log "Installed patched tasks.svgz to $LOCAL_THEME_DIR/"

# ─── Clear Plasma SVG cache and restart ──────────────────────────────────────

info "Clearing Plasma SVG cache..."
rm -f ~/.cache/plasma-svgelements-* ~/.cache/plasma_theme_default_*.kcache 2>/dev/null
find ~/.cache -name '*plasma*svg*' -delete 2>/dev/null || true
find ~/.cache -name '*tasks*' -delete 2>/dev/null || true

info "Restarting Plasma shell..."
killall plasmashell 2>/dev/null || true
sleep 1
plasmashell --replace &>/dev/null &disown

echo ""
log "Done! Taskbar indicators are now uniform light gray."
echo ""
echo "  To undo: rm \"$LOCAL_THEME_DIR/tasks.svgz\" and restart plasmashell"
echo "  To tweak: edit INDICATOR_COLOR and INDICATOR_OPACITY at top of this script"
