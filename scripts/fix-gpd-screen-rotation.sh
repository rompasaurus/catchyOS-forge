#!/usr/bin/env bash
# Fix screen rotation for GPD G1628-04 (Pocket 4) on CachyOS.
# Designed to be run on a fresh install to get rotation correct immediately.
#
# Fixes three layers:
#   1. Accelerometer mount matrix (udev hwdb) — so auto-rotation works correctly
#   2. KDE Plasma display config — sets correct base transform for the panel
#   3. Kernel cmdline (Limine) — fixes early-boot splash / framebuffer console
#
# Usage: sudo ./fix-gpd-screen-rotation.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)."
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
REAL_UID=$(id -u "$REAL_USER")

echo "GPD Pocket 4 (G1628-04) screen rotation fix"
echo "============================================="
echo ""

# ============================================================
# 1. Accelerometer mount matrix — fix auto-rotation direction
# ============================================================
# The upstream hwdb entry for GPD G1628-04 uses mount matrix:
#   -1, 0, 0; 0, 1, 0; 0, 0, 1
# This treats the portrait panel's native orientation as "normal", but
# the Pocket 4 is used in landscape. Rotating the matrix 90° CW maps
# the accelerometer axes to match the landscape panel orientation.
echo "[1/3] Accelerometer mount matrix"

HWDB_FILE="/etc/udev/hwdb.d/61-sensor-gpd-pocket4.hwdb"
cat > "$HWDB_FILE" << 'EOF'
# GPD Pocket 4 (G1628-04) — fix accelerometer orientation for landscape panel.
# The stock matrix assumes portrait-normal; this rotates it 90° CW so that
# the device's natural landscape position registers as "normal" for auto-rotation.
sensor:modalias:acpi:MXC6655:*:dmi:*:svnGPD:pnG1628-04:*
 ACCEL_MOUNT_MATRIX=0, 1, 0; 1, 0, 0; 0, 0, 1
EOF

echo "  Wrote $HWDB_FILE"

systemd-hwdb update
echo "  Rebuilt hwdb"

udevadm trigger -v -p DEVNAME=/dev/iio:device0 2>/dev/null || \
    udevadm trigger --subsystem-match=iio 2>/dev/null || true
echo "  Triggered udev reload"

# Restart sensor proxy so it picks up the new matrix immediately
if systemctl is-active --quiet iio-sensor-proxy 2>/dev/null; then
    systemctl restart iio-sensor-proxy
    echo "  Restarted iio-sensor-proxy"
fi

echo ""

# ============================================================
# 2. KDE Plasma display config — set correct transform
# ============================================================
# On a fresh install KDE may not have created kwinoutputconfig.json yet.
# If it exists, patch the transform. If not, create a minimal config
# for the eDP-1 panel so KDE starts with the correct rotation.
echo "[2/3] KDE Plasma display config"

KDE_CONF="$REAL_HOME/.config/kwinoutputconfig.json"
if [[ -f "$KDE_CONF" ]]; then
    if grep -q '"transform"' "$KDE_CONF"; then
        sed -i 's/"transform": *"[^"]*"/"transform": "Rotated90"/' "$KDE_CONF"
        echo "  Updated existing transform → Rotated90"
    else
        echo "  WARNING: No transform key found in $KDE_CONF"
        echo "  Set rotation manually: System Settings > Display & Monitor"
    fi
else
    # Fresh install — create the config so KDE starts in the right orientation
    mkdir -p "$REAL_HOME/.config"
    cat > "$KDE_CONF" << 'KDEEOF'
[
    {
        "data": [
            {
                "autoRotation": "Always",
                "connectorName": "eDP-1",
                "edidIdentifier": "HSX 804 8947848 0 2023 0",
                "mode": {
                    "height": 2560,
                    "refreshRate": 143999,
                    "width": 1600
                },
                "scale": 1.5,
                "transform": "Rotated90"
            }
        ],
        "name": "outputs"
    },
    {
        "data": [
            {
                "lidClosed": false,
                "outputs": [
                    {
                        "enabled": true,
                        "outputIndex": 0,
                        "position": {
                            "x": 0,
                            "y": 0
                        },
                        "priority": 1,
                        "replicationSource": ""
                    }
                ]
            }
        ],
        "name": "setups"
    }
]
KDEEOF
    chown "$REAL_USER:$REAL_USER" "$KDE_CONF"
    echo "  Created $KDE_CONF with Rotated90 transform"
fi

# Apply live if a KDE session is running
if [[ -S "/run/user/$REAL_UID/bus" ]]; then
    sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$REAL_UID/bus" \
        dbus-send --session --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null && \
        echo "  Sent reconfigure to KWin (live apply)" || \
        echo "  KWin not running — rotation will apply on next login"
else
    echo "  No active session — rotation will apply on next login"
fi

echo ""

# ============================================================
# 3. Kernel cmdline — fix early-boot splash / fbcon
# ============================================================
# fbcon=rotate:1       → 90° CW rotation for framebuffer console
# panel_orientation    → tells DRM the panel is mounted rotated
echo "[3/3] Kernel cmdline (boot splash)"

ROTATE_PARAMS="fbcon=rotate:1 video=eDP-1:panel_orientation=right_side_up"

LIMINE_CONF=""
for candidate in /boot/limine.conf /boot/limine/limine.conf /boot/EFI/limine/limine.conf; do
    if [[ -f "$candidate" ]]; then
        LIMINE_CONF="$candidate"
        break
    fi
done

if [[ -z "$LIMINE_CONF" ]]; then
    LIMINE_CONF=$(find /boot -name "limine.conf" -type f 2>/dev/null | head -1)
fi

if [[ -n "$LIMINE_CONF" ]]; then
    echo "  Found: $LIMINE_CONF"

    # Backup before modifying
    BACKUP="${LIMINE_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$LIMINE_CONF" "$BACKUP"
    echo "  Backup: $BACKUP"

    # Remove any old rotation params, then add correct ones
    sed -i 's/ *fbcon=rotate:[0-9]//g' "$LIMINE_CONF"
    sed -i 's/ *video=eDP-1:panel_orientation=[a-z_]*//g' "$LIMINE_CONF"
    sed -i "/^\s*cmdline:/ s/$/ ${ROTATE_PARAMS}/" "$LIMINE_CONF"

    echo "  Applied: $ROTATE_PARAMS"
else
    echo "  WARNING: No limine.conf found."
    echo "  If using a different bootloader, add to your kernel cmdline:"
    echo "    $ROTATE_PARAMS"
fi

echo ""
echo "============================================="
echo "Done!"
echo "  - Auto-rotation + desktop: working now (or after login)"
echo "  - Boot splash: requires reboot"
echo "  - To revert hwdb: sudo rm $HWDB_FILE && sudo systemd-hwdb update"
if [[ -n "${BACKUP:-}" ]]; then
    echo "  - To revert boot: sudo cp $BACKUP $LIMINE_CONF"
fi
