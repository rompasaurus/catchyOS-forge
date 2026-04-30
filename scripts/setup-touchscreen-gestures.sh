#!/usr/bin/env bash
# Install a KWin script that enables 3-finger touchscreen swipe to switch
# virtual desktops on KDE Plasma 6 Wayland.
#
# Swipe left  → next desktop
# Swipe right → previous desktop
#
# Usage: sudo ./setup-touchscreen-gestures.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)."
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
REAL_UID=$(id -u "$REAL_USER")

SCRIPT_ID="touchscreen-desktop-swipe"
SCRIPT_DIR="$REAL_HOME/.local/share/kwin/scripts/$SCRIPT_ID"

echo "Touchscreen gesture setup (3-finger swipe → switch desktops)"
echo "============================================================="
echo ""

# ============================================================
# 1. Install the KWin script
# ============================================================
echo "[1/2] Installing KWin script"

mkdir -p "$SCRIPT_DIR/contents/code"

cat > "$SCRIPT_DIR/metadata.json" << 'EOF'
{
    "KPackageStructure": "KWin/Script",
    "KPlugin": {
        "Name": "Touchscreen Desktop Swipe",
        "Description": "3-finger touchscreen swipe left/right to switch virtual desktops",
        "Id": "touchscreen-desktop-swipe",
        "Version": "1.0",
        "License": "MIT"
    },
    "X-Plasma-API": "javascript",
    "X-Plasma-API-Minimum-Version": "6.0",
    "X-Plasma-MainScript": "code/main.js"
}
EOF

cat > "$SCRIPT_DIR/contents/code/main.js" << 'EOF'
// 3-finger touchscreen swipe to switch virtual desktops.
// Left swipe  → next desktop
// Right swipe → previous desktop

registerTouchscreenSwipeShortcut(SwipeDirection.Left, 3, function () {
    workspace.currentDesktop = workspace.desktops[
        Math.min(
            workspace.desktops.indexOf(workspace.currentDesktop) + 1,
            workspace.desktops.length - 1
        )
    ];
});

registerTouchscreenSwipeShortcut(SwipeDirection.Right, 3, function () {
    workspace.currentDesktop = workspace.desktops[
        Math.max(
            workspace.desktops.indexOf(workspace.currentDesktop) - 1,
            0
        )
    ];
});
EOF

chown -R "$REAL_USER:$REAL_USER" "$SCRIPT_DIR"
echo "  Installed to $SCRIPT_DIR"

# ============================================================
# 2. Enable the script in KWin
# ============================================================
echo "[2/2] Enabling script in KWin"

sudo -u "$REAL_USER" kwriteconfig6 --file kwinrc --group Plugins --key "${SCRIPT_ID}Enabled" true
echo "  Enabled ${SCRIPT_ID} in kwinrc"

# Apply live if a session is running
if [[ -S "/run/user/$REAL_UID/bus" ]]; then
    sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$REAL_UID/bus" \
        dbus-send --session --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null && \
        echo "  KWin reconfigured — gestures are live" || \
        echo "  KWin not running — gestures will work on next login"
else
    echo "  No active session — gestures will work on next login"
fi

echo ""
echo "============================================================="
echo "Done!"
echo "  - Swipe left  with 3 fingers → next desktop"
echo "  - Swipe right with 3 fingers → previous desktop"
echo "  - To disable: kwriteconfig6 --file kwinrc --group Plugins --key ${SCRIPT_ID}Enabled false"
