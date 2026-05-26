#!/usr/bin/env bash
# Setup KZones KWin script with Windows 11-style snap layouts
set -euo pipefail

KZONES_REPO="https://github.com/gerritdevriese/kzones.git"
KZONES_DIR="/tmp/kzones-install"

LAYOUTS='[
    {
        "name": "Half & Half",
        "padding": 0,
        "zones": [
            { "x": 0, "y": 0, "width": 50, "height": 100 },
            { "x": 50, "y": 0, "width": 50, "height": 100 }
        ]
    },
    {
        "name": "67 / 33",
        "padding": 0,
        "zones": [
            { "x": 0, "y": 0, "width": 67, "height": 100 },
            { "x": 67, "y": 0, "width": 33, "height": 100 }
        ]
    },
    {
        "name": "Left + Right Stack",
        "padding": 0,
        "zones": [
            { "x": 0, "y": 0, "width": 50, "height": 100 },
            { "x": 50, "y": 0, "width": 50, "height": 50 },
            { "x": 50, "y": 50, "width": 50, "height": 50 }
        ]
    },
    {
        "name": "Three Columns",
        "padding": 0,
        "zones": [
            { "x": 0, "y": 0, "width": 33.33, "height": 100 },
            { "x": 33.33, "y": 0, "width": 33.34, "height": 100 },
            { "x": 66.67, "y": 0, "width": 33.33, "height": 100 }
        ]
    },
    {
        "name": "Wide Center + Sides",
        "padding": 0,
        "zones": [
            { "x": 0, "y": 0, "width": 25, "height": 100 },
            { "x": 25, "y": 0, "width": 50, "height": 100 },
            { "x": 75, "y": 0, "width": 25, "height": 100 }
        ]
    },
    {
        "name": "Quadrants",
        "padding": 0,
        "zones": [
            { "x": 0, "y": 0, "width": 50, "height": 50 },
            { "x": 50, "y": 0, "width": 50, "height": 50 },
            { "x": 0, "y": 50, "width": 50, "height": 50 },
            { "x": 50, "y": 50, "width": 50, "height": 50 }
        ]
    },
    {
        "name": "Focus + Right Stack",
        "padding": 0,
        "zones": [
            { "x": 0, "y": 0, "width": 67, "height": 100 },
            { "x": 67, "y": 0, "width": 33, "height": 50 },
            { "x": 67, "y": 50, "width": 33, "height": 50 }
        ]
    },
    {
        "name": "Focus + Grid",
        "padding": 0,
        "zones": [
            { "x": 0, "y": 0, "width": 50, "height": 100 },
            { "x": 50, "y": 0, "width": 25, "height": 50 },
            { "x": 75, "y": 0, "width": 25, "height": 50 },
            { "x": 50, "y": 50, "width": 25, "height": 50 },
            { "x": 75, "y": 50, "width": 25, "height": 50 }
        ]
    }
]'

echo "=== KZones Setup ==="

# Install git if missing
if ! command -v git &>/dev/null; then
    echo "Installing git..."
    sudo pacman -S --noconfirm git
fi

# Clone and install KZones
echo "Cloning KZones..."
rm -rf "$KZONES_DIR"
git clone "$KZONES_REPO" "$KZONES_DIR"

echo "Installing KZones KWin script..."
cd "$KZONES_DIR"
make install

# Write layouts to kwinrc
echo "Configuring layouts..."
KWINRC="$HOME/.config/kwinrc"

# Remove existing KZones config section if present
if grep -q '^\[Script-kzones\]' "$KWINRC" 2>/dev/null; then
    # Remove the section and its keys until the next section or EOF
    sed -i '/^\[Script-kzones\]/,/^\[/{/^\[Script-kzones\]/d;/^\[/!d}' "$KWINRC"
fi

# Compact the JSON to a single line for kwinrc
LAYOUTS_ONELINE=$(echo "$LAYOUTS" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), separators=(',',':')))")

# Append KZones config
cat >> "$KWINRC" << EOF

[Script-kzones]
layoutsJson=$LAYOUTS_ONELINE
EOF

# Enable the KWin script
echo "Enabling KZones..."
kwriteconfig6 --file kwinrc --group Plugins --key kzonesEnabled true

# Reload KWin to pick up changes
echo "Reloading KWin..."
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true

# Cleanup
rm -rf "$KZONES_DIR"

echo ""
echo "Done! KZones installed with 8 Windows 11-style layouts:"
echo "  1. Half & Half        [50 | 50]"
echo "  2. 67 / 33            [67 | 33]"
echo "  3. Left + Right Stack [50 | 50/50]"
echo "  4. Three Columns      [33 | 34 | 33]"
echo "  5. Wide Center + Sides[25 | 50 | 25]"
echo "  6. Quadrants          [2x2 grid]"
echo "  7. Focus + Right Stack[67 | 33/33]"
echo "  8. Focus + Grid       [50 | 2x2]"
echo ""
echo "Hold Shift + drag a window to snap into zones."
echo "Cycle layouts with: Meta+D (next) / Meta+Shift+D (prev)"
