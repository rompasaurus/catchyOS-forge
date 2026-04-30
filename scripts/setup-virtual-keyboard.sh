#!/usr/bin/env bash
# Set up virtual keyboard with touchscreen support for GPD Pocket 4 on CachyOS.
# Installs plasma-keyboard if needed, configures KWin to use it, and enables
# tablet mode so tapping text fields and swiping from the bottom edge shows
# the on-screen keyboard.
#
# Usage: sudo ./setup-virtual-keyboard.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)."
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
REAL_UID=$(id -u "$REAL_USER")

echo "Virtual keyboard setup (GPD Pocket 4 / CachyOS)"
echo "================================================="
echo ""

# ============================================================
# 1. Install plasma-keyboard if not present
# ============================================================
echo "[1/3] Checking plasma-keyboard package"

if pacman -Qs plasma-keyboard &>/dev/null; then
    echo "  Already installed"
else
    echo "  Installing plasma-keyboard..."
    pacman -S --noconfirm plasma-keyboard
    echo "  Installed"
fi

echo ""

# ============================================================
# 2. Configure KWin to use plasma-keyboard as input method
# ============================================================
echo "[2/3] Configuring KWin virtual keyboard"

VK_DESKTOP="/usr/share/applications/org.kde.plasma.keyboard.desktop"
if [[ ! -f "$VK_DESKTOP" ]]; then
    echo "  WARNING: $VK_DESKTOP not found, searching..."
    VK_DESKTOP=$(find /usr/share/applications -name "*plasma*keyboard*" -type f 2>/dev/null | head -1)
    if [[ -z "$VK_DESKTOP" ]]; then
        echo "  ERROR: Could not find plasma-keyboard .desktop file"
        exit 1
    fi
fi

sudo -u "$REAL_USER" kwriteconfig6 --file kwinrc --group Wayland --key InputMethod "$VK_DESKTOP"
echo "  InputMethod → $VK_DESKTOP"

# Enable tablet mode so the VK auto-shows when tapping text fields
# and bottom-edge swipe gestures are active
sudo -u "$REAL_USER" kwriteconfig6 --file kwinrc --group Input --key TabletMode on
echo "  TabletMode → on"

echo ""

# ============================================================
# 3. Apply config live if a session is running
# ============================================================
echo "[3/3] Applying changes"

if [[ -S "/run/user/$REAL_UID/bus" ]]; then
    sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$REAL_UID/bus" \
        dbus-send --session --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null && \
        echo "  Sent reconfigure to KWin — changes are live" || \
        echo "  KWin not running — changes will apply on next login"
else
    echo "  No active session — changes will apply on next login"
fi

echo ""
echo "================================================="
echo "Done!"
echo "  - Tap any text field to show the keyboard"
echo "  - Swipe up from the bottom edge to trigger it"
echo "  - To disable tablet mode later:"
echo "      kwriteconfig6 --file kwinrc --group Input --key TabletMode auto"
