#!/usr/bin/env bash
#
# Xbox Wireless Controller — Bluetooth Fix for Steam on CachyOS
#
# Problem: Xbox Wireless Controller (045E:02FD) connected via Bluetooth may
#          fail to probe with xpadneo due to a buggy HID report descriptor
#          ("unbalanced collection" / parse failed / error -22).
#
# Fix:     1. Disable Bluetooth ERTM (required for Xbox BT controllers)
#          2. Install xpadneo-dkms-git (pre-release with descriptor fixes)
#          3. Fall back to a udev rule tagging the device as a joystick
#             if xpadneo still can't probe it
#
# Run with: bash scripts/setup-xbox-bt-controller.sh
#
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │   Xbox Bluetooth Controller Fix           │"
echo "  │   xpadneo + ERTM + udev fallback         │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── 1. Disable Bluetooth ERTM ────────────────────────────────────────────────
# Xbox controllers over BT require ERTM (Enhanced Retransmission Mode) disabled.
# Without this, connections are unstable or the controller won't work at all.

ERTM_CONF="/etc/modprobe.d/bluetooth-ertm.conf"
ERTM_LINE="options bluetooth disable_ertm=1"

if [[ -f "$ERTM_CONF" ]] && grep -qF "$ERTM_LINE" "$ERTM_CONF"; then
    log "ERTM already disabled."
else
    info "Disabling Bluetooth ERTM..."
    echo "$ERTM_LINE" | sudo tee "$ERTM_CONF" > /dev/null
    log "ERTM disable configured (takes effect after reboot)."
fi

# Apply immediately if possible
if [[ "$(cat /sys/module/bluetooth/parameters/disable_ertm 2>/dev/null)" == "N" ]]; then
    info "Applying ERTM disable for current session..."
    echo 1 | sudo tee /sys/module/bluetooth/parameters/disable_ertm > /dev/null 2>&1 || \
        warn "Could not apply live — will take effect after reboot."
fi

# ─── 2. Install dependencies ──────────────────────────────────────────────────

info "Installing dependencies..."
sudo pacman -S --needed --noconfirm dkms linux-cachyos-headers

# ─── 3. Install xpadneo (prefer git version for descriptor fixes) ─────────────

if pacman -Qi xpadneo-dkms-git &>/dev/null; then
    log "xpadneo-dkms-git already installed: $(pacman -Q xpadneo-dkms-git | awk '{print $2}')"
elif pacman -Qi xpadneo-dkms &>/dev/null; then
    info "Replacing xpadneo-dkms with xpadneo-dkms-git (has HID descriptor fixes)..."
    sudo pacman -Rdd --noconfirm xpadneo-dkms 2>/dev/null || true
    sudo pacman -S --needed --noconfirm xpadneo-dkms-git 2>/dev/null || {
        warn "xpadneo-dkms-git not available, reinstalling xpadneo-dkms..."
        sudo pacman -S --needed --noconfirm xpadneo-dkms
    }
    log "xpadneo installed."
else
    info "Installing xpadneo-dkms-git..."
    sudo pacman -S --needed --noconfirm xpadneo-dkms-git 2>/dev/null || {
        warn "xpadneo-dkms-git not available, falling back to xpadneo-dkms..."
        sudo pacman -S --needed --noconfirm xpadneo-dkms
    }
    log "xpadneo installed."
fi

# ─── 4. Load the module now ───────────────────────────────────────────────────

if lsmod | grep -q hid_xpadneo; then
    info "Reloading hid_xpadneo module..."
    sudo modprobe -r hid_xpadneo 2>/dev/null || true
fi
info "Loading hid_xpadneo module..."
sudo modprobe hid_xpadneo 2>/dev/null && log "Module loaded." || warn "Could not load module — a reboot may be needed."

# ─── 5. Udev fallback rule ────────────────────────────────────────────────────
# If xpadneo still can't parse the descriptor (buggy firmware), this udev rule
# ensures hid_generic at least tags the device as a joystick so Steam sees it.

UDEV_RULE="/etc/udev/rules.d/71-xbox-bt-gamepad.rules"
info "Installing udev fallback rule..."
sudo tee "$UDEV_RULE" > /dev/null <<'UDEVRULE'
# Xbox Wireless Controller over Bluetooth — joystick tag fallback
# If xpadneo probe fails, hid_generic handles the device but doesn't tag it.
# This rule ensures Steam/SDL see it as a gamepad regardless.

# Xbox One S controller (BT mode)
KERNEL=="input*", ATTRS{id/vendor}=="045e", ATTRS{id/product}=="02fd", ENV{ID_INPUT_JOYSTICK}="1", TAG+="uaccess"
KERNEL=="input*", ATTRS{id/vendor}=="045e", ATTRS{id/product}=="0b22", ENV{ID_INPUT_JOYSTICK}="1", TAG+="uaccess"
KERNEL=="input*", ATTRS{id/vendor}=="045e", ATTRS{id/product}=="0b13", ENV{ID_INPUT_JOYSTICK}="1", TAG+="uaccess"
KERNEL=="input*", ATTRS{id/vendor}=="045e", ATTRS{id/product}=="0b05", ENV{ID_INPUT_JOYSTICK}="1", TAG+="uaccess"
KERNEL=="input*", ATTRS{id/vendor}=="045e", ATTRS{id/product}=="02e0", ENV{ID_INPUT_JOYSTICK}="1", TAG+="uaccess"
KERNEL=="input*", ATTRS{id/vendor}=="045e", ATTRS{id/product}=="028e", ENV{ID_INPUT_JOYSTICK}="1", TAG+="uaccess"
UDEVRULE
sudo udevadm control --reload-rules
sudo udevadm trigger
log "Udev fallback rule installed."

# ─── 6. Reconnect controller ─────────────────────────────────────────────────
# Disconnect and reconnect to force re-probe with the new module/rules

XBOX_MAC=$(bluetoothctl devices 2>/dev/null | grep -i "xbox" | awk '{print $2}')
if [[ -n "$XBOX_MAC" ]]; then
    info "Reconnecting Xbox controller ($XBOX_MAC)..."
    bluetoothctl disconnect "$XBOX_MAC" 2>/dev/null || true
    sleep 2
    bluetoothctl connect "$XBOX_MAC" 2>/dev/null || warn "Could not auto-connect — press the Xbox button on the controller."
    sleep 3
fi

# ─── 7. Verify ────────────────────────────────────────────────────────────────

echo ""
info "Verification:"

if dkms status 2>/dev/null | grep -qi "xpadneo"; then
    echo -e "  ${GREEN}✓${NC} xpadneo installed (DKMS)"
else
    echo -e "  ${YELLOW}✗${NC} xpadneo not found in DKMS"
fi

if lsmod | grep -q hid_xpadneo; then
    echo -e "  ${GREEN}✓${NC} hid_xpadneo module loaded"
else
    echo -e "  ${YELLOW}✗${NC} hid_xpadneo not loaded — reboot required"
fi

ERTM_VAL=$(cat /sys/module/bluetooth/parameters/disable_ertm 2>/dev/null)
if [[ "$ERTM_VAL" == "Y" ]]; then
    echo -e "  ${GREEN}✓${NC} Bluetooth ERTM disabled"
else
    echo -e "  ${YELLOW}✗${NC} ERTM still enabled — reboot required"
fi

if [[ -f "$UDEV_RULE" ]]; then
    echo -e "  ${GREEN}✓${NC} Udev fallback rule in place"
fi

# Check for joystick device
sleep 1
JS_DEV=$(find /dev/input -name 'js*' 2>/dev/null | head -1 || true)
if [[ -n "$JS_DEV" ]]; then
    echo -e "  ${GREEN}✓${NC} Joystick device found: ${JS_DEV}"
else
    echo -e "  ${YELLOW}·${NC} No joystick device yet — reboot and reconnect controller"
fi

# Check for event device tagged as joystick
EVDEV=$(find /dev/input -name 'event*' 2>/dev/null -exec udevadm info {} \; 2>/dev/null | grep -B20 "ID_INPUT_JOYSTICK=1" | grep "DEVNAME" | head -1 | cut -d= -f2 || true)
if [[ -n "$EVDEV" ]]; then
    echo -e "  ${GREEN}✓${NC} Joystick-tagged event device: ${EVDEV}"
fi

echo ""
warn "A REBOOT is strongly recommended for all changes to take effect."
echo ""
log "After reboot:"
echo "  1. Turn on Xbox controller and connect via Bluetooth"
echo "  2. Open Steam → Settings → Controller"
echo "  3. Enable 'Xbox Extended Feature Support' if prompted"
echo "  4. The controller should appear as an Xbox gamepad"
echo ""
echo "  If it still doesn't work after reboot, update the controller"
echo "  firmware using the 'Xbox Accessories' app on Windows or Xbox console."
echo ""
