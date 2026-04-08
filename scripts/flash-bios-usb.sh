#!/usr/bin/env bash
set -euo pipefail

# Prep a USB drive for ASUS BIOS Flashback (ROG Crosshair X870E Hero)
# Usage: sudo ./flash-bios-usb.sh /dev/sdX [path-to-bios.zip]

USB_DEV="${1:-}"
BIOS_ZIP="${2:-$(ls -t ~/Downloads/*X870E*HERO*2103*.ZIP ~/Downloads/*x870e*hero*2103*.zip ~/Downloads/*CROSSHAIR*2103*.ZIP 2>/dev/null | head -1)}"

if [[ -z "$USB_DEV" ]]; then
    echo "Available removable drives:"
    lsblk -dno NAME,SIZE,TRAN,MODEL | grep usb || echo "  (none found)"
    echo ""
    echo "Usage: sudo $0 /dev/sdX [path-to-bios-zip]"
    echo "Example: sudo $0 /dev/sdb ~/Downloads/ROG-CROSSHAIR-X870E-HERO-ASUS-2103.ZIP"
    exit 1
fi

if [[ -z "$BIOS_ZIP" || ! -f "$BIOS_ZIP" ]]; then
    echo "ERROR: Could not find BIOS zip file."
    echo "Download BIOS 2103 from:"
    echo "  https://www.asus.com/us/supportonly/rog%20crosshair%20x870e%20hero/helpdesk_bios/"
    echo "Then run: sudo $0 $USB_DEV ~/Downloads/<bios-file>.ZIP"
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Must run as root (sudo)"
    exit 1
fi

# Safety check - make sure it's a removable device
if [[ ! -b "$USB_DEV" ]]; then
    echo "ERROR: $USB_DEV is not a block device"
    exit 1
fi

REMOVABLE=$(cat "/sys/block/$(basename "$USB_DEV")/removable" 2>/dev/null || echo "0")
if [[ "$REMOVABLE" != "1" ]]; then
    echo "WARNING: $USB_DEV does not appear to be a removable device!"
    read -rp "Are you SURE this is your USB drive? (yes/no): " confirm
    [[ "$confirm" == "yes" ]] || exit 1
fi

echo "=== ASUS BIOS Flashback USB Prep ==="
echo "USB device: $USB_DEV"
echo "BIOS zip:   $BIOS_ZIP"
echo ""
echo "This will ERASE ALL DATA on $USB_DEV"
read -rp "Continue? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || exit 1

# Unmount any existing partitions
echo "[1/5] Unmounting existing partitions..."
umount "${USB_DEV}"* 2>/dev/null || true

# Create MBR partition table with single FAT32 partition
echo "[2/5] Creating FAT32 partition..."
parted -s "$USB_DEV" mklabel msdos
parted -s "$USB_DEV" mkpart primary fat32 1MiB 100%
sleep 1

# Format as FAT32
PART="${USB_DEV}1"
# Handle nvme-style naming
[[ -b "${USB_DEV}p1" ]] && PART="${USB_DEV}p1"
echo "[3/5] Formatting ${PART} as FAT32..."
mkfs.vfat -F 32 "$PART"

# Mount and extract
MOUNT_DIR=$(mktemp -d)
echo "[4/5] Extracting BIOS..."
mount "$PART" "$MOUNT_DIR"

WORK_DIR=$(mktemp -d)
unzip -o "$BIOS_ZIP" -d "$WORK_DIR"

# Find and rename the CAP file
CAP_FILE=$(find "$WORK_DIR" -iname "*.CAP" | head -1)
if [[ -z "$CAP_FILE" ]]; then
    echo "ERROR: No .CAP file found in the zip"
    umount "$MOUNT_DIR"
    rm -rf "$WORK_DIR" "$MOUNT_DIR"
    exit 1
fi

# The flashback filename for X870E Hero is A5558.CAP
# Check if BIOSRenamer gave us the right name, otherwise rename
cp "$CAP_FILE" "$MOUNT_DIR/A5558.CAP"

echo "[5/5] Verifying..."
ls -lh "$MOUNT_DIR/A5558.CAP"
sync
umount "$MOUNT_DIR"
rm -rf "$WORK_DIR" "$MOUNT_DIR"

echo ""
echo "=== DONE ==="
echo "USB is ready for BIOS Flashback."
echo ""
echo "To flash:"
echo "  1. Power off PC completely"
echo "  2. Plug USB into the BIOS Flashback port (check manual for which USB port)"
echo "  3. Hold the BIOS Flashback button ~3 seconds until LED blinks"
echo "  4. Wait until LED stops blinking (do NOT unplug or power on)"
echo "  5. Done - power on and enter BIOS to verify version 2103"
