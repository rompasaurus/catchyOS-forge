#!/usr/bin/env bash
# setup-windows-snap.sh — Windows 11-style "Snap Layouts" on KDE Plasma (KWin).
#
# Gives you the Windows 11 behaviour: drag a window toward the top-center of the
# screen and a layout selector flyout appears; drop the window onto a placement
# to snap it there. Powered by the KZones KWin script's Zone Selector.
#
# Difference vs setup-kzones.sh: that script uses the Shift+drag trigger. This
# one enables the drag-to-top Zone Selector (no modifier key), matching Windows.
#
# Usage:  bash scripts/setup-windows-snap.sh
#
# Re-runnable: safe to run multiple times (config is rewritten in place).

set -euo pipefail

log()  { echo -e "\e[32m[✓]\e[0m $*"; }
info() { echo -e "\e[34m[i]\e[0m $*"; }
warn() { echo -e "\e[33m[!]\e[0m $*"; }

KZONES_REPO="https://github.com/gerritdevriese/kzones.git"
KZONES_DIR="/tmp/kzones-install"
KZONES_INSTALLED="$HOME/.local/share/kwin/scripts/kzones"

# Windows 11-style layouts shown in the top-center selector flyout.
LAYOUTS='[
    {
        "name": "Half & Half",
        "padding": 0,
        "zones": [
            { "x": 0,  "y": 0, "width": 50, "height": 100 },
            { "x": 50, "y": 0, "width": 50, "height": 100 }
        ]
    },
    {
        "name": "67 / 33",
        "padding": 0,
        "zones": [
            { "x": 0,  "y": 0, "width": 67, "height": 100 },
            { "x": 67, "y": 0, "width": 33, "height": 100 }
        ]
    },
    {
        "name": "Three Columns",
        "padding": 0,
        "zones": [
            { "x": 0,     "y": 0, "width": 33.33, "height": 100 },
            { "x": 33.33, "y": 0, "width": 33.34, "height": 100 },
            { "x": 66.67, "y": 0, "width": 33.33, "height": 100 }
        ]
    },
    {
        "name": "Focus + Right Stack",
        "padding": 0,
        "zones": [
            { "x": 0,  "y": 0,  "width": 67, "height": 100 },
            { "x": 67, "y": 0,  "width": 33, "height": 50  },
            { "x": 67, "y": 50, "width": 33, "height": 50  }
        ]
    },
    {
        "name": "Quadrants",
        "padding": 0,
        "zones": [
            { "x": 0,  "y": 0,  "width": 50, "height": 50 },
            { "x": 50, "y": 0,  "width": 50, "height": 50 },
            { "x": 0,  "y": 50, "width": 50, "height": 50 },
            { "x": 50, "y": 50, "width": 50, "height": 50 }
        ]
    },
    {
        "name": "Wide Center + Sides",
        "padding": 0,
        "zones": [
            { "x": 0,  "y": 0, "width": 25, "height": 100 },
            { "x": 25, "y": 0, "width": 50, "height": 100 },
            { "x": 75, "y": 0, "width": 25, "height": 100 }
        ]
    }
]'

echo "=== Windows 11-style Snap Layouts (KZones Zone Selector) ==="

# ── Step 1: ensure KZones is installed ───────────────────────────────────────
if [[ -d "$KZONES_INSTALLED" ]]; then
    log "[1/4] KZones already installed."
else
    info "[1/4] KZones not found — installing..."
    command -v git &>/dev/null || sudo pacman -S --needed --noconfirm git
    rm -rf "$KZONES_DIR"
    git clone "$KZONES_REPO" "$KZONES_DIR"
    ( cd "$KZONES_DIR" && make install )
    rm -rf "$KZONES_DIR"
    log "KZones installed."
fi

# ── Step 2: write Windows-style layouts ──────────────────────────────────────
info "[2/4] Writing layouts..."
LAYOUTS_ONELINE=$(echo "$LAYOUTS" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), separators=(',',':')))")
kwriteconfig6 --file kwinrc --group Script-kzones --key layoutsJson "$LAYOUTS_ONELINE"
log "6 Windows-style layouts written."

# ── Step 3: configure the drag-to-top Zone Selector ──────────────────────────
info "[3/4] Configuring the drag-to-top selector (Windows 11 behaviour)..."
# The Zone Selector is the top-center flyout that appears while dragging.
kwriteconfig6 --file kwinrc --group Script-kzones --key enableZoneSelector true
# How close to the top edge (in %) the window must reach to pop the selector.
# Bumped from the default 1 so it triggers a little before you hit the bezel.
kwriteconfig6 --file kwinrc --group Script-kzones --key zoneSelectorTriggerDistance 3
# Show the zone overlay (the highlighted target) only while dragging.
kwriteconfig6 --file kwinrc --group Script-kzones --key enableZoneOverlay true
kwriteconfig6 --file kwinrc --group Script-kzones --key zoneOverlayShowWhen 0
# Snap restores the window's previous size when you pull it back out of a zone.
kwriteconfig6 --file kwinrc --group Script-kzones --key rememberWindowGeometries true
# On-screen layout-switch messages.
kwriteconfig6 --file kwinrc --group Script-kzones --key showOsdMessages true
log "Zone Selector enabled."

# ── Step 4: enable the script and reload KWin ────────────────────────────────
info "[4/4] Enabling KZones and reloading KWin..."
kwriteconfig6 --file kwinrc --group Plugins --key kzonesEnabled true
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null \
    || warn "Could not reload KWin via DBus — log out/in to apply."
log "KWin reloaded."

echo ""
log "Done. Drag a window toward the TOP-CENTER of the screen — the snap-layout"
log "selector appears; drop the window onto a placement to snap it."
info "Layouts available: Half & Half · 67/33 · Three Columns · Focus+Stack ·"
info "                   Quadrants · Wide Center+Sides"
warn "Not working? Open System Settings → Window Management → KWin Scripts and"
warn "confirm 'KZones' is checked, then log out/in once."
