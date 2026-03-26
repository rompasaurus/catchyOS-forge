#!/bin/bash
# Fix Bluetooth when the controller disappears and pairing stops working.
# Common after sleep/suspend on CachyOS.

set -euo pipefail

echo "=== Bluetooth Fix ==="

# Step 1: Try a simple service restart
echo "[1/3] Restarting bluetooth service..."
sudo systemctl restart bluetooth
sleep 2

if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "Controller is back and powered on."
    exit 0
fi

# Step 2: Reload the btusb kernel module
echo "[2/3] Reloading btusb kernel module..."
sudo modprobe -r btusb
sleep 1
sudo modprobe btusb
sleep 2
sudo systemctl restart bluetooth
sleep 2

if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "Controller is back after module reload."
    exit 0
fi

# Step 3: rfkill power cycle
echo "[3/3] Power cycling via rfkill..."
sudo rfkill block bluetooth
sleep 2
sudo rfkill unblock bluetooth
sleep 2
sudo systemctl restart bluetooth
sleep 2

if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "Controller is back after rfkill reset."
    exit 0
fi

echo "ERROR: Bluetooth controller still not available."
echo "You may need to reboot, or check 'dmesg | grep -i bluetooth' for hardware errors."
exit 1
