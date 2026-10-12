#!/usr/bin/env bash
#
# setup-zune.sh — Get a Zune HD (or classic Zune) working on CachyOS.
# Safe to run multiple times.
#
# Background: the Zune desktop software is Windows-only. It needs .NET,
# Windows Media components and a kernel-mode USB driver, so it does NOT run
# under Wine (WineHQ AppDB: never worked). The device itself speaks "MTPZ"
# (MTP + Zune certificate handshake), so plain MTP tools can't see it either.
# Microsoft's Zune servers were shut down in 2015 and the installer was pulled.
#
# Two ways to work around that — this script does both:
#
#   DEFAULT  Native Linux sync. libmtp on Arch is built with MTPZ support;
#            it just needs the Zune certificate blob at ~/.mtpz-data (extracted
#            from the Zune software by kbhomes/libmtp-zune). After that gMTP /
#            android-file-transfer / mtp-* can copy music to the Zune HD.
#            No Zune software needed. Does NOT do firmware updates, first-time
#            device setup, or Zune-format playlists.
#
#   --vm     The real Zune software 4.8 inside the existing "win11" KVM VM
#            (created by scripts/setup-win11-vm.sh). Downloads the archived
#            installer + the community Windows 11 driver fix onto an ISO,
#            attaches the ISO to the VM, and passes the Zune's USB ID through
#            to the VM so Windows sees it directly.
#
#   --attach / --detach   Just add/remove the USB passthrough on the VM.
#
# Usage: bash scripts/setup-zune.sh [--vm | --attach | --detach]
#
set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; exit 1; }

# ─── Config ──────────────────────────────────────────────────────────────────

# USB IDs (from libmtp's music-players.h)
ZUNE_VENDOR="045e"
ZUNE_HD_PRODUCT="063e"      # Zune HD
ZUNE_CLASSIC_PRODUCT="0710" # Zune 4/8/16/30/80/120

# MTPZ certificate/key blob extracted from the Zune software (kbhomes/libmtp-zune).
MTPZ_URL="https://raw.githubusercontent.com/kbhomes/libmtp-zune/master/src/.mtpz-data"
MTPZ_SHA256="76ccea4ea2df370d38e91b777e00e1abb1722d80d66a2ac1eb5e21458f488664"
MTPZ_FILE="${HOME}/.mtpz-data"
UDEV_RULE="/etc/udev/rules.d/69-zune-mtpz.rules"

# Zune software 4.8.2345.0 (final release, Aug 2011) — archived full offline installer.
ZUNE_PKG_URL="https://archive.org/download/zune-package_202204/ZunePackage.exe"
ZUNE_PKG_SHA1="31e0b5114d71b545b8199a458f776009f7898b4d"
ZUNE_PKG_SIZE="283639032"

# Community fix for the Windows 10/11 "Workstation error" that blocks the Zune driver.
DRIVER_FIX_URL="https://raw.githubusercontent.com/zunes/Zune-driver-fix---Windows-Workstation-error/main/Zune_Driver_Windows_11_FIX_-_Workstation_Error_-_0.5.1.bat"
DRIVER_FIX_NAME="Zune_Driver_Win11_Fix_0.5.1.bat"

VM_NAME="win11"
VM_DIR="/var/lib/libvirt/images/${VM_NAME}"
ZUNE_DIR="${VM_DIR}/zune"
ZUNE_ISO="${ZUNE_DIR}/zune-software.iso"
VM_CDROM_TARGET="sdb"   # the empty second SATA cdrom from setup-win11-vm.sh
VIRSH="virsh --connect qemu:///system"

MODE="native"
case "${1:-}" in
    "")          MODE="native" ;;
    --vm|-vm|vm)             MODE="vm" ;;
    --attach|-attach|attach) MODE="attach" ;;
    --detach|-detach|detach) MODE="detach" ;;
    -h|--help)   sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           err "Unknown option: $1 (try --help)" ;;
esac

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │              Zune HD Setup                │"
echo "  │   native MTPZ sync  +  Zune 4.8 in KVM    │"
echo "  │            CachyOS / Arch                  │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Helpers ─────────────────────────────────────────────────────────────────

zune_connected() {
    lsusb -d "${ZUNE_VENDOR}:${ZUNE_HD_PRODUCT}" &>/dev/null \
        || lsusb -d "${ZUNE_VENDOR}:${ZUNE_CLASSIC_PRODUCT}" &>/dev/null
}

install_pkgs() {
    local to_install=()
    for pkg in "$@"; do
        pacman -Qi "$pkg" &>/dev/null || to_install+=("$pkg")
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
        log "Installing: ${to_install[*]}"
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
    else
        log "Packages already installed: $*"
    fi
}

require_vm() {
    command -v virsh &>/dev/null || err "virsh not found. Run scripts/setup-win11-vm.sh first."
    $VIRSH dominfo "$VM_NAME" &>/dev/null \
        || err "VM '$VM_NAME' not found. Run scripts/setup-win11-vm.sh first."
}

vm_running() { [[ "$($VIRSH domstate "$VM_NAME" 2>/dev/null)" == "running" ]]; }

hostdev_xml() {
    # startupPolicy=optional: VM still boots when the Zune is unplugged.
    cat <<EOF
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source startupPolicy='optional'>
    <vendor id='0x${ZUNE_VENDOR}'/>
    <product id='0x$1'/>
  </source>
</hostdev>
EOF
}

vm_has_hostdev() {
    $VIRSH dumpxml "$VM_NAME" --inactive 2>/dev/null \
        | grep -A3 "<hostdev mode='subsystem' type='usb'" \
        | grep -q "product id='0x$1'"
}

attach_zune_usb() {
    local tmp flags
    for product in "$ZUNE_HD_PRODUCT" "$ZUNE_CLASSIC_PRODUCT"; do
        if vm_has_hostdev "$product"; then
            log "USB passthrough for ${ZUNE_VENDOR}:${product} already on '$VM_NAME'."
            continue
        fi
        tmp=$(mktemp)
        hostdev_xml "$product" > "$tmp"
        flags=(--config)
        vm_running && flags=(--persistent)   # persistent = live + config
        if $VIRSH attach-device "$VM_NAME" "$tmp" "${flags[@]}" &>/dev/null; then
            log "Attached USB ${ZUNE_VENDOR}:${product} to '$VM_NAME' (${flags[*]})."
        else
            # Live attach fails when the device isn't plugged in; fall back to config only.
            $VIRSH attach-device "$VM_NAME" "$tmp" --config
            log "Attached USB ${ZUNE_VENDOR}:${product} to '$VM_NAME' (config; takes effect on next boot/plug)."
        fi
        rm -f "$tmp"
    done
}

detach_zune_usb() {
    local tmp flags
    for product in "$ZUNE_HD_PRODUCT" "$ZUNE_CLASSIC_PRODUCT"; do
        vm_has_hostdev "$product" || continue
        tmp=$(mktemp)
        hostdev_xml "$product" > "$tmp"
        flags=(--config)
        vm_running && flags=(--persistent)
        $VIRSH detach-device "$VM_NAME" "$tmp" "${flags[@]}" &>/dev/null \
            || $VIRSH detach-device "$VM_NAME" "$tmp" --config
        rm -f "$tmp"
        log "Detached USB ${ZUNE_VENDOR}:${product} from '$VM_NAME'."
    done
}

# ─── Mode: --attach / --detach ──────────────────────────────────────────────

if [[ "$MODE" == "attach" ]]; then
    require_vm; attach_zune_usb
    warn "While attached to the VM the Zune is invisible to Linux. Use --detach to get it back."
    exit 0
fi
if [[ "$MODE" == "detach" ]]; then
    require_vm; detach_zune_usb
    exit 0
fi

# ─── Native Linux sync (always) ──────────────────────────────────────────────

info "Installing MTP tooling (libmtp has MTPZ compiled in on Arch)..."
install_pkgs libmtp gmtp android-file-transfer usbutils

# MTPZ key blob
if [[ -f "$MTPZ_FILE" ]] && echo "${MTPZ_SHA256}  ${MTPZ_FILE}" | sha256sum -c --status 2>/dev/null; then
    log "MTPZ data already in place: $MTPZ_FILE"
else
    info "Downloading MTPZ certificate data to $MTPZ_FILE ..."
    TMP_MTPZ=$(mktemp)
    curl -fsSL --retry 3 -o "$TMP_MTPZ" "$MTPZ_URL"
    if ! echo "${MTPZ_SHA256}  ${TMP_MTPZ}" | sha256sum -c --status; then
        rm -f "$TMP_MTPZ"
        err "Checksum mismatch for .mtpz-data — upstream changed or download corrupted. Not installing."
    fi
    [[ "$(head -n1 "$TMP_MTPZ")" == "10001" ]] || { rm -f "$TMP_MTPZ"; err "Unexpected .mtpz-data format."; }
    install -m 600 "$TMP_MTPZ" "$MTPZ_FILE"
    rm -f "$TMP_MTPZ"
    log "MTPZ data installed (libmtp reads it automatically)."
fi

# udev: libmtp's hwdb doesn't list the Zune HD; tag it so you can open it without root
# and so desktop MTP browsers recognise it as a media player.
RULE_CONTENT="# Microsoft Zune HD / Zune — MTPZ devices (added by catchyOS-forge setup-zune.sh)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"${ZUNE_VENDOR}\", ATTR{idProduct}==\"${ZUNE_HD_PRODUCT}\", ENV{ID_MTP_DEVICE}=\"1\", ENV{ID_MEDIA_PLAYER}=\"1\", TAG+=\"uaccess\"
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"${ZUNE_VENDOR}\", ATTR{idProduct}==\"${ZUNE_CLASSIC_PRODUCT}\", ENV{ID_MTP_DEVICE}=\"1\", ENV{ID_MEDIA_PLAYER}=\"1\", TAG+=\"uaccess\""
if [[ -f "$UDEV_RULE" ]] && [[ "$(cat "$UDEV_RULE")" == "$RULE_CONTENT" ]]; then
    log "udev rule already present: $UDEV_RULE"
else
    info "Installing udev rule $UDEV_RULE ..."
    echo "$RULE_CONTENT" | sudo tee "$UDEV_RULE" >/dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=usb
    log "udev rule installed."
fi

# Device check
echo
if zune_connected; then
    log "Zune detected on USB:"
    lsusb -d "${ZUNE_VENDOR}:" | grep -i -E "${ZUNE_HD_PRODUCT}|${ZUNE_CLASSIC_PRODUCT}" | sed 's/^/      /'
    if [[ "$MODE" == "native" ]]; then
        info "Probing with mtp-detect (MTPZ handshake)..."
        if timeout 30 mtp-detect 2>&1 | grep -q -i -E 'friendly name|Model:|Zune'; then
            log "mtp-detect talked to the Zune. Native sync is working."
        else
            warn "mtp-detect could not open the device. Common causes:"
            warn "  • KDE/Dolphin grabbed it — eject it in Dolphin, or: kquitapp6 kiod6 ; then retry"
            warn "  • The Zune has never been set up — a brand-new Zune needs the Zune software once (use --vm)"
            warn "  • Zune is locked / showing a sync screen — unlock it and replug"
            warn "Debug with:  LIBMTP_DEBUG=0xFF mtp-detect"
        fi
    fi
else
    warn "No Zune found on USB right now (expected ID ${ZUNE_VENDOR}:${ZUNE_HD_PRODUCT})."
    warn "Make sure it is powered on and plugged in with a Zune (proprietary 30-pin) cable."
fi

echo
log "Native sync ready. Use one of:"
echo "      gmtp                     # GUI, drag & drop music/podcasts/pictures"
echo "      android-file-transfer    # alternate GUI (aft-mtp-mount for FUSE mount)"
echo "      mtp-detect | mtp-files | mtp-sendfile <file> <dest>"
echo "      In Dolphin: mtp:/ (unmount it before using gmtp — only one app can hold the device)"

# ─── Zune software in the win11 VM (--vm) ────────────────────────────────────

if [[ "$MODE" == "vm" ]]; then
    echo
    info "Setting up the Zune 4.8 software inside the '$VM_NAME' VM..."
    require_vm
    install_pkgs libisoburn virt-viewer

    sudo mkdir -p "$ZUNE_DIR"
    sudo chown "$USER:$USER" "$ZUNE_DIR"

    # 1. Zune software installer (~270 MB)
    PKG="${ZUNE_DIR}/ZunePackage.exe"
    if [[ -f "$PKG" ]] && echo "${ZUNE_PKG_SHA1}  ${PKG}" | sha1sum -c --status 2>/dev/null; then
        log "ZunePackage.exe already downloaded and verified."
    else
        info "Downloading Zune software 4.8.2345.0 from archive.org (~270 MB)..."
        curl -fL --retry 5 -C - --progress-bar -o "$PKG" "$ZUNE_PKG_URL"
        [[ "$(stat -c%s "$PKG")" == "$ZUNE_PKG_SIZE" ]] || err "Download size mismatch for ZunePackage.exe."
        echo "${ZUNE_PKG_SHA1}  ${PKG}" | sha1sum -c --status || err "SHA1 mismatch for ZunePackage.exe."
        log "ZunePackage.exe verified (sha1 ${ZUNE_PKG_SHA1:0:12}…)."
    fi

    # 2. Windows 11 driver fix
    FIX="${ZUNE_DIR}/${DRIVER_FIX_NAME}"
    if [[ ! -s "$FIX" ]]; then
        info "Downloading community Windows 11 Zune driver fix..."
        curl -fsSL --retry 3 -o "$FIX" "$DRIVER_FIX_URL"
        grep -q "Zune Driver Windows 11 FIX" "$FIX" || { rm -f "$FIX"; err "Driver fix script content unexpected."; }
        log "Driver fix downloaded."
    else
        log "Driver fix already downloaded."
    fi

    # 3. README for inside the VM
    cat > "${ZUNE_DIR}/README-INSTALL.txt" <<'EOF'
Zune software 4.8 on Windows 11 (inside the KVM VM)
===================================================

1. Optional features first (Win+R -> optionalfeatures):
     [x] .NET Framework 3.5 (includes 2.0/3.0)
     [x] .NET Framework 4.8 Advanced Services
     [x] Media Features -> Windows Media Player Legacy
   Reboot if Windows asks.

2. Run ZunePackage.exe from this disc. If setup refuses to start,
   right-click -> Properties -> Compatibility -> Windows 7, run as admin.

3. Plug in the Zune. It is passed straight through to this VM from the
   Linux host, so Windows should see "Zune" in Device Manager.

4. If the Zune software never shows the device / Device Manager shows a
   driver error ("Workstation error"), run
       Zune_Driver_Win11_Fix_0.5.1.bat
   as Administrator (it self-elevates; a blue PowerShell window is normal).
   It deletes blocked driver files, copies the Zune driver .mui files and
   re-installs the device. It WILL remove existing Zune/WP7 entries from
   Device Manager first. Source: github.com/zunes/Zune-driver-fix---Windows-Workstation-error

5. Sign-in / Marketplace / Social are dead (Microsoft shut the servers in
   2015). Skip sign-in; local library sync and firmware-less use works.
   Community revival of the services + mods (video sync fix for Win10+):
       https://github.com/ZuneDev/ZuneModdingHelper
       https://zunes.me

Tip: the Zune reconnects a few times during first setup / firmware checks.
Give it 30 s before assuming it failed.
EOF

    # 4. Build ISO
    info "Building ISO with installer + fix..."
    xorriso -as mkisofs -quiet -r -J -V "ZUNE48" -o "$ZUNE_ISO" \
        "$PKG" "$FIX" "${ZUNE_DIR}/README-INSTALL.txt" 2>/dev/null
    log "ISO ready: $ZUNE_ISO"

    # 5. Insert ISO into the VM's spare cdrom
    if $VIRSH dumpxml "$VM_NAME" --inactive | grep -q "$ZUNE_ISO"; then
        log "ISO already inserted in '$VM_NAME' ($VM_CDROM_TARGET)."
    else
        FLAG="--config"; vm_running && FLAG="--current"
        if $VIRSH change-media "$VM_NAME" "$VM_CDROM_TARGET" "$ZUNE_ISO" --insert --force $FLAG &>/dev/null \
           || $VIRSH change-media "$VM_NAME" "$VM_CDROM_TARGET" "$ZUNE_ISO" --update --force $FLAG &>/dev/null; then
            log "Inserted ISO into cdrom '$VM_CDROM_TARGET' of '$VM_NAME'."
        else
            warn "Couldn't insert into '$VM_CDROM_TARGET'. Attach manually in virt-manager: $ZUNE_ISO"
        fi
    fi

    # 6. USB passthrough
    attach_zune_usb

    # 7. Boot it
    echo
    if vm_running; then
        log "VM '$VM_NAME' is running."
    else
        info "Starting VM '$VM_NAME'..."
        $VIRSH start "$VM_NAME"
    fi
    if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        nohup virt-viewer --connect qemu:///system "$VM_NAME" >/dev/null 2>&1 &
        log "virt-viewer launched."
    fi

    echo
    log "Inside Windows: open the ZUNE48 disc (D: or E:) and follow README-INSTALL.txt."
    warn "While the Zune is passed through to the VM, Linux cannot see it. Run:"
    warn "    bash scripts/setup-zune.sh --detach     to give it back to Linux/gMTP."
fi

echo
log "Done."
