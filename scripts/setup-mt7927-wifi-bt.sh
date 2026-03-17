#!/usr/bin/env bash
#
# MediaTek MT7927 (Filogic 380) WiFi 7 + Bluetooth 5.4 Setup for CachyOS
#
# Hardware: MT7927 combo chip (WiFi PCI 14c3:7927 + BT USB 0489:e13a)
#   - WiFi side: architecturally MT7925, connects via PCIe
#   - BT side:   internally MT6639, connects via USB
#
# Based on: https://github.com/jetm/mediatek-mt7927-dkms
#
# Run with: bash scripts/setup-mt7927-wifi-bt.sh
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
echo "  │   MediaTek MT7927 WiFi + BT Setup        │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# Auto-detect kernel version from running kernel
RUNNING_KERNEL="$(uname -r)"           # e.g. 6.19.8-1-cachyos
KERNEL_VER="${RUNNING_KERNEL%%-*}"      # e.g. 6.19.8
KERNEL_MAJOR="${KERNEL_VER%%.*}"        # e.g. 6
DKMS_NAME="mediatek-mt7927"
DKMS_VER="2.4"
WORK_DIR="/tmp/mt7927-setup"
DKMS_SRC="/usr/src/${DKMS_NAME}-${DKMS_VER}"
REPO_DIR="/tmp/mediatek-mt7927-dkms"

# ASUS driver ZIP for firmware extraction
DRIVER_FILENAME="DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip"
DRIVER_SHA256="b377fffa28208bb1671a0eb219c84c62fba4cd6f92161b74e4b0909476307cc8"

info "Kernel: $(uname -r)"
echo ""

# --- Preflight checks ---
if ! lspci | grep -qi "14c3:7927"; then
    warn "No MT7927 WiFi device detected (PCI ID 14c3:7927)"
    warn "Continuing anyway in case device is disabled..."
fi

if ! lsusb | grep -q "0489:e13a"; then
    warn "No MT7927 Bluetooth device detected (USB ID 0489:e13a)"
fi

# --- Step 1: Install dependencies ---
echo ""
log "[1/8] Installing dependencies..."
sudo pacman -S --needed --noconfirm \
    dkms base-devel linux-cachyos-headers \
    git python3 curl libarchive xz patch

# --- Step 2: Clone the upstream DKMS repo ---
echo ""
log "[2/8] Cloning driver repository..."
if [ -d "$REPO_DIR" ]; then
    info "Repo already exists at $REPO_DIR, pulling latest..."
    git -C "$REPO_DIR" pull --ff-only 2>/dev/null || true
else
    git clone https://github.com/jetm/mediatek-mt7927-dkms.git "$REPO_DIR"
fi

# --- Step 3: Download kernel source tarball ---
echo ""
log "[3/8] Downloading kernel ${KERNEL_VER} source..."
mkdir -p "$WORK_DIR"

KERNEL_TARBALL="$WORK_DIR/linux-${KERNEL_VER}.tar.xz"
if [ ! -f "$KERNEL_TARBALL" ]; then
    curl -L -o "$KERNEL_TARBALL" \
        "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_VER}.tar.xz"
else
    info "Kernel tarball already downloaded."
fi

# --- Step 4: Download ASUS driver ZIP and extract firmware ---
echo ""
log "[4/8] Downloading ASUS driver package for firmware..."

DRIVER_ZIP="$WORK_DIR/${DRIVER_FILENAME}"
if [ ! -f "$DRIVER_ZIP" ]; then
    info "Fetching download token from ASUS CDN..."
    TOKEN_URL="https://cdnta.asus.com/api/v1/TokenHQ?filePath=https:%2F%2Fdlcdnta.asus.com%2Fpub%2FASUS%2Fmb%2F08WIRELESS%2F${DRIVER_FILENAME}%3Fmodel%3DROG%2520CROSSHAIR%2520X870E%2520HERO&systemCode=rog"

    TOKEN_JSON=$(curl -sf "$TOKEN_URL" -X POST -H 'Origin: https://rog.asus.com') || {
        err "Failed to get ASUS CDN token."
        err "You can manually download the driver from:"
        err "  https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-x870e-hero/helpdesk_download/"
        err "  Select: WiFi & Bluetooth -> MediaTek MT7925/MT7927 WiFi driver"
        err "  Place the ZIP at: $DRIVER_ZIP"
        exit 1
    }

    # Parse JSON without jq
    EXPIRES="${TOKEN_JSON#*\"expires\":\"}"
    EXPIRES="${EXPIRES%%\"*}"
    SIGNATURE="${TOKEN_JSON#*\"signature\":\"}"
    SIGNATURE="${SIGNATURE%%\"*}"
    KEY_PAIR_ID="${TOKEN_JSON#*\"keyPairId\":\"}"
    KEY_PAIR_ID="${KEY_PAIR_ID%%\"*}"

    DOWNLOAD_URL="https://dlcdnta.asus.com/pub/ASUS/mb/08WIRELESS/${DRIVER_FILENAME}?model=ROG%20CROSSHAIR%20X870E%20HERO&Signature=${SIGNATURE}&Expires=${EXPIRES}&Key-Pair-Id=${KEY_PAIR_ID}"

    info "Downloading ${DRIVER_FILENAME}..."
    curl -L -f -o "$DRIVER_ZIP" "$DOWNLOAD_URL"

    # Verify checksum
    info "Verifying checksum..."
    echo "${DRIVER_SHA256}  ${DRIVER_ZIP}" | sha256sum -c - || {
        err "SHA256 checksum mismatch!"
        rm -f "$DRIVER_ZIP"
        exit 1
    }
else
    info "Driver ZIP already downloaded."
fi

# Extract mtkwlan.dat from the ZIP
info "Extracting mtkwlan.dat..."
bsdtar -xf "$DRIVER_ZIP" -C "$WORK_DIR" mtkwlan.dat 2>/dev/null || \
    bsdtar -xf "$DRIVER_ZIP" -C "$WORK_DIR" '*/mtkwlan.dat' 2>/dev/null || {
    bsdtar -xf "$DRIVER_ZIP" -C "$WORK_DIR"
    MTKWLAN=$(find "$WORK_DIR" -name "mtkwlan.dat" -type f | head -1)
    if [ -z "$MTKWLAN" ]; then
        err "Could not find mtkwlan.dat in the driver ZIP"
        exit 1
    fi
    cp "$MTKWLAN" "$WORK_DIR/mtkwlan.dat"
}

# Handle case where mtkwlan.dat might be nested
if [ ! -f "$WORK_DIR/mtkwlan.dat" ]; then
    MTKWLAN=$(find "$WORK_DIR" -name "mtkwlan.dat" -type f | head -1)
    if [ -n "$MTKWLAN" ]; then
        cp "$MTKWLAN" "$WORK_DIR/mtkwlan.dat"
    fi
fi

# Extract firmware blobs
info "Extracting firmware blobs..."
mkdir -p "$WORK_DIR/firmware"
python3 "$REPO_DIR/extract_firmware.py" "$WORK_DIR/mtkwlan.dat" "$WORK_DIR/firmware"

# --- Step 5: Extract and patch kernel source ---
echo ""
log "[5/8] Extracting and patching kernel source..."

# Extract mt76 WiFi source
info "Extracting mt76 source from kernel ${KERNEL_VER}..."
mkdir -p "$WORK_DIR/mt76"
tar -xf "$KERNEL_TARBALL" \
    --strip-components=6 \
    -C "$WORK_DIR/mt76" \
    "linux-${KERNEL_VER}/drivers/net/wireless/mediatek/mt76"

# Extract bluetooth source
info "Extracting bluetooth source..."
mkdir -p "$WORK_DIR/bluetooth"
tar -xf "$KERNEL_TARBALL" \
    --strip-components=3 \
    -C "$WORK_DIR/bluetooth" \
    "linux-${KERNEL_VER}/drivers/bluetooth"

# Install missing kernel headers that the 6.19 mt76 source requires
# CachyOS headers are under /usr/lib/modules/$(uname -r)/build/include
HEADERS_DIR="/usr/lib/modules/$(uname -r)/build/include"
if [ -d "$HEADERS_DIR" ] && [ ! -f "$HEADERS_DIR/linux/soc/airoha/airoha_offload.h" ]; then
    info "Installing missing airoha_offload.h header for kernel compat..."
    sudo mkdir -p "$HEADERS_DIR/linux/soc/airoha"
    tar -xf "$KERNEL_TARBALL" \
        --strip-components=1 \
        -C "$WORK_DIR/" \
        "linux-${KERNEL_VER}/include/linux/soc/airoha/airoha_offload.h"
    sudo cp "$WORK_DIR/include/linux/soc/airoha/airoha_offload.h" \
        "$HEADERS_DIR/linux/soc/airoha/"
fi

# Apply WiFi patches
info "Applying mt7902-wifi patch..."
cd "$WORK_DIR/mt76"
patch -p1 < "$REPO_DIR/mt7902-wifi-6.19.patch"

info "Applying MT7927 WiFi patches..."
for p in "$REPO_DIR"/mt7927-wifi-*.patch; do
    info "  $(basename "$p")"
    patch -p1 < "$p"
done

# Create Kbuild files for out-of-tree mt76 build
cat > "$WORK_DIR/mt76/Kbuild" <<'EOF'
obj-m += mt76.o
obj-m += mt76-connac-lib.o
obj-m += mt792x-lib.o
obj-m += mt7921/
obj-m += mt7925/

mt76-y := \
	mmio.o util.o trace.o dma.o mac80211.o debugfs.o eeprom.o \
	tx.o agg-rx.o mcu.o wed.o scan.o channel.o pci.o

mt76-connac-lib-y := mt76_connac_mcu.o mt76_connac_mac.o mt76_connac3_mac.o

mt792x-lib-y := mt792x_core.o mt792x_mac.o mt792x_trace.o \
		mt792x_debugfs.o mt792x_dma.o mt792x_acpi_sar.o

CFLAGS_trace.o := -I$(src)
CFLAGS_mt792x_trace.o := -I$(src)
EOF

cat > "$WORK_DIR/mt76/mt7921/Kbuild" <<'EOF'
obj-m += mt7921-common.o
obj-m += mt7921e.o

mt7921-common-y := mac.o mcu.o main.o init.o debugfs.o
mt7921e-y := pci.o pci_mac.o pci_mcu.o
EOF

cat > "$WORK_DIR/mt76/mt7925/Kbuild" <<'EOF'
obj-m += mt7925-common.o
obj-m += mt7925e.o

mt7925-common-y := mac.o mcu.o regd.o main.o init.o debugfs.o
mt7925e-y := pci.o pci_mac.o pci_mcu.o
EOF

cd - > /dev/null

# Apply Bluetooth patch (was missing — BT source was used unpatched)
info "Applying MT6639 Bluetooth patch..."
cd "$WORK_DIR/bluetooth"
# Try common strip levels: the patch may use a/drivers/bluetooth/file (-p3)
# or a/file (-p1) depending on how it was generated
if ! patch --dry-run -p1 < "$REPO_DIR/mt6639-bt-6.19.patch" >/dev/null 2>&1; then
    if ! patch --dry-run -p3 < "$REPO_DIR/mt6639-bt-6.19.patch" >/dev/null 2>&1; then
        if ! patch --dry-run -p4 < "$REPO_DIR/mt6639-bt-6.19.patch" >/dev/null 2>&1; then
            err "BT patch does not apply at -p1, -p3, or -p4. Check patch format."
            err "Trying -p1 anyway..."
            patch -p1 < "$REPO_DIR/mt6639-bt-6.19.patch"
        else
            patch -p4 < "$REPO_DIR/mt6639-bt-6.19.patch"
        fi
    else
        patch -p3 < "$REPO_DIR/mt6639-bt-6.19.patch"
    fi
else
    patch -p1 < "$REPO_DIR/mt6639-bt-6.19.patch"
fi
cd - > /dev/null

# --- Step 6: Set up DKMS ---
echo ""
log "[6/8] Setting up DKMS..."

# Clean previous installations
for mod in "mediatek-bt-only" "mediatek-mt7927-wifi" "mediatek-mt7927"; do
    sudo dkms remove -m "$mod" --all 2>/dev/null || true
    sudo rm -rf "/usr/src/${mod}-"*
done
sudo rm -rf "/var/lib/dkms/${DKMS_NAME}" 2>/dev/null || true

# Create DKMS source directory
sudo mkdir -p "$DKMS_SRC"

# Copy DKMS config
sudo cp "$REPO_DIR/dkms.conf" "$DKMS_SRC/"

# Copy pre-patched bluetooth source + Makefile
sudo mkdir -p "$DKMS_SRC/drivers/bluetooth"
sudo cp "$WORK_DIR/bluetooth/"*.{c,h} "$DKMS_SRC/drivers/bluetooth/" 2>/dev/null || true
sudo cp "$REPO_DIR/bluetooth.Makefile" "$DKMS_SRC/drivers/bluetooth/Makefile"

# Copy patched mt76 WiFi source + Kbuild files from repo
sudo mkdir -p "$DKMS_SRC/mt76/mt7921" "$DKMS_SRC/mt76/mt7925"
sudo cp "$WORK_DIR/mt76/"*.{c,h} "$DKMS_SRC/mt76/" 2>/dev/null || true
sudo cp "$REPO_DIR/mt76.Kbuild" "$DKMS_SRC/mt76/Kbuild"
sudo cp "$WORK_DIR/mt76/mt7921/"*.{c,h} "$DKMS_SRC/mt76/mt7921/" 2>/dev/null || true
sudo cp "$REPO_DIR/mt7921.Kbuild" "$DKMS_SRC/mt76/mt7921/Kbuild"
sudo cp "$WORK_DIR/mt76/mt7925/"*.{c,h} "$DKMS_SRC/mt76/mt7925/" 2>/dev/null || true
sudo cp "$REPO_DIR/mt7925.Kbuild" "$DKMS_SRC/mt76/mt7925/Kbuild"

# Build and install DKMS modules
info "Adding DKMS module..."
sudo dkms add -m "$DKMS_NAME" -v "$DKMS_VER"

echo ""
log "[7/8] Building DKMS module (this may take a few minutes)..."
sudo dkms build -m "$DKMS_NAME" -v "$DKMS_VER" -k "$(uname -r)"

info "Installing DKMS module..."
sudo dkms install -m "$DKMS_NAME" -v "$DKMS_VER" -k "$(uname -r)" --force

# --- Step 8: Install firmware and reload ---
echo ""
log "[8/8] Installing firmware and loading drivers..."

# Install BT firmware
sudo mkdir -p /lib/firmware/mediatek/mt6639
sudo cp "$WORK_DIR/firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin" \
    /lib/firmware/mediatek/mt6639/
sudo cp "$WORK_DIR/firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin" \
    /lib/firmware/mediatek/

# Install WiFi firmware
sudo mkdir -p /lib/firmware/mediatek/mt7927
sudo cp "$WORK_DIR/firmware/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin" \
    /lib/firmware/mediatek/mt7927/
sudo cp "$WORK_DIR/firmware/WIFI_RAM_CODE_MT6639_2_1.bin" \
    /lib/firmware/mediatek/mt7927/
# Also copy to mt6639 directory (some driver versions look here)
sudo mkdir -p /lib/firmware/mediatek/mt6639
sudo cp "$WORK_DIR/firmware/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin" \
    /lib/firmware/mediatek/mt6639/
sudo cp "$WORK_DIR/firmware/WIFI_RAM_CODE_MT6639_2_1.bin" \
    /lib/firmware/mediatek/mt6639/

# Regenerate initramfs (CachyOS uses mkinitcpio)
info "Regenerating initramfs..."
sudo mkinitcpio -P

# Reload modules
info "Reloading kernel modules..."
sudo systemctl stop bluetooth 2>/dev/null || true
sudo modprobe -r mt7925e mt7921e mt7925_common mt7921_common \
    mt792x_lib mt76_connac_lib mt76 btusb btmtk 2>/dev/null || true

# Unblock radios
sudo rfkill unblock bluetooth 2>/dev/null || true
sudo rfkill unblock wlan 2>/dev/null || true

# Load new modules
sudo modprobe mt7925e
sudo modprobe btusb
sudo systemctl start bluetooth 2>/dev/null || true

echo ""
echo -e "${GREEN}=========================================================="
echo " Installation complete!"
echo "==========================================================${NC}"
echo ""
info "Waiting for drivers to initialize (10 seconds)..."
sleep 10

echo ""
info "Checking status..."
echo ""

# Verify WiFi
echo "--- WiFi ---"
if ip link show | grep -q "wl"; then
    WIFI_IF=$(ip link show | grep -o "wl[a-z0-9]*" | head -1)
    echo "  Interface: $WIFI_IF"
    WIFI_STATE=$(nmcli -t -f DEVICE,STATE device status 2>/dev/null | grep "$WIFI_IF" | cut -d: -f2)
    echo "  State:     ${WIFI_STATE:-unknown}"
    echo ""
    echo "  Connect with: nmcli device wifi connect \"YourSSID\" password \"YourPassword\""
else
    warn "No WiFi interface detected yet."
    warn "A reboot may be needed: sudo reboot"
fi

echo ""
echo "--- Bluetooth ---"
if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    BT_ADDR=$(bluetoothctl show 2>/dev/null | grep "Controller" | awk '{print $2}')
    echo "  Adapter:  UP"
    echo "  Address:  $BT_ADDR"
    echo ""
    echo "  Pair with: bluetoothctl scan on"
elif bluetoothctl show 2>/dev/null | grep -q "Controller"; then
    info "Adapter found but not powered, attempting to power on..."
    bluetoothctl power on 2>/dev/null || true
    sleep 2
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        BT_ADDR=$(bluetoothctl show 2>/dev/null | grep "Controller" | awk '{print $2}')
        echo "  Status:   UP"
        echo "  Address:  $BT_ADDR"
    else
        warn "Not ready yet -- a reboot should fix this"
    fi
else
    warn "Not detected yet -- a reboot should fix this"
fi

echo ""
echo "--- Loaded Modules ---"
lsmod | grep -E "^(mt76|mt79|mt7925|btusb|btmtk)" | awk '{printf "  %-20s %s\n", $1, $3 " dependents"}' || true

echo ""
echo "--- DKMS ---"
dkms status 2>/dev/null | grep mediatek || true

echo ""
echo -e "${GREEN}=========================================================="
echo " Done! If anything isn't working, reboot: sudo reboot"
echo "==========================================================${NC}"
echo ""
echo "Troubleshooting:"
echo "  dmesg | grep -i -e mt79 -e mt66 -e btmtk -e btusb | tail -20"
echo "  sudo dkms status"
echo ""
