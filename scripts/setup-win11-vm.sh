#!/usr/bin/env bash
# Setup a Windows 11 QEMU/KVM VM on CachyOS (Arch).
# Installs deps, downloads VirtIO drivers, creates a VM with good defaults.
# Uses zenity file picker for ISO selection — minimal user input.
# Run with: bash scripts/setup-win11-vm.sh

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

echo -e "${CYAN}"
echo "  ┌────────────────────────────────────────────┐"
echo "  │     Windows 11 KVM/QEMU VM Installer       │"
echo "  │              CachyOS / Arch                 │"
echo "  └────────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Config ──────────────────────────────────────────────────────────────────

VM_DIR="/var/lib/libvirt/images/win11"
VM_NAME="win11"
DISK_SIZE="128G"
RAM="16384"          # 16 GB
CPUS="8"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
TPM_DIR="$VM_DIR/tpm"

# ─── Pre-flight checks ──────────────────────────────────────────────────────

if ! grep -qE '(vmx|svm)' /proc/cpuinfo 2>/dev/null; then
    err "CPU virtualization (VT-x/AMD-V) not available. Enable it in BIOS."
fi

KVM_LOADED=$(lsmod | grep -c kvm || true)
if [[ "$KVM_LOADED" -eq 0 ]]; then
    err "KVM modules not loaded. Try: sudo modprobe kvm kvm_amd"
fi

# ─── Install dependencies ───────────────────────────────────────────────────

info "Installing QEMU/KVM stack and dependencies..."
PKGS=(
    qemu-full
    libvirt
    virt-manager
    virt-viewer
    dnsmasq
    edk2-ovmf        # UEFI firmware (required for Win11 Secure Boot)
    swtpm             # Software TPM 2.0 (required for Win11)
    zenity            # GUI file dialogs
    wget
)

# Filter out already-installed packages
TO_INSTALL=()
for pkg in "${PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        TO_INSTALL+=("$pkg")
    fi
done

if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
    log "Installing: ${TO_INSTALL[*]}"
    sudo pacman -S --needed --noconfirm "${TO_INSTALL[@]}"
else
    log "All packages already installed."
fi

# ─── Enable libvirt ──────────────────────────────────────────────────────────

info "Enabling libvirt services..."
sudo systemctl enable --now libvirtd.service
sudo systemctl enable --now virtlogd.service

# Add user to libvirt group if not already
if ! groups "$USER" | grep -q libvirt; then
    warn "Adding $USER to libvirt group (re-login may be needed for virt-manager GUI)."
    sudo usermod -aG libvirt "$USER"
    sudo usermod -aG kvm "$USER"
fi

# Enable default NAT network (system connection)
VIRSH="sudo virsh --connect qemu:///system"
if ! $VIRSH net-info default &>/dev/null; then
    info "Defining default NAT network..."
    $VIRSH net-define /usr/share/libvirt/networks/default.xml || true
fi
$VIRSH net-start default 2>/dev/null || true
$VIRSH net-autostart default 2>/dev/null || true

# ─── Prepare VM directory ───────────────────────────────────────────────────

sudo mkdir -p "$VM_DIR" "$TPM_DIR"
sudo chown "$USER:$USER" "$VM_DIR" "$TPM_DIR"

# ─── Select Windows ISO ─────────────────────────────────────────────────────

info "Opening file picker for Windows 11 ISO..."
WIN_ISO=$(zenity --file-selection \
    --title="Select Windows 11 ISO" \
    --file-filter="ISO files|*.iso *.ISO" \
    --file-filter="All files|*" \
    2>/dev/null) || err "No ISO selected. Exiting."

[[ -f "$WIN_ISO" ]] || err "File not found: $WIN_ISO"
log "Windows ISO: $WIN_ISO"

# ─── Download VirtIO drivers ────────────────────────────────────────────────

VIRTIO_ISO="$VM_DIR/virtio-win.iso"
if [[ -f "$VIRTIO_ISO" ]]; then
    log "VirtIO drivers ISO already downloaded."
else
    info "Downloading VirtIO drivers ISO (this may take a minute)..."
    wget -q --show-progress -O "$VIRTIO_ISO" "$VIRTIO_URL"
    log "VirtIO drivers downloaded."
fi

# ─── Create disk image ──────────────────────────────────────────────────────

DISK_IMG="$VM_DIR/win11.qcow2"
if [[ -f "$DISK_IMG" ]]; then
    warn "Disk image already exists: $DISK_IMG"
    if ! zenity --question --title="Disk exists" \
        --text="$DISK_IMG already exists.\n\nKeep existing disk?" \
        --ok-label="Keep" --cancel-label="Recreate" 2>/dev/null; then
        info "Recreating disk image..."
        rm -f "$DISK_IMG"
        qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
        log "Created $DISK_SIZE qcow2 disk."
    else
        log "Keeping existing disk."
    fi
else
    info "Creating $DISK_SIZE qcow2 disk image..."
    qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
    log "Disk created."
fi

# ─── Prepare UEFI vars copy ─────────────────────────────────────────────────

VARS_COPY="$VM_DIR/OVMF_VARS.4m.fd"
if [[ ! -f "$VARS_COPY" ]]; then
    cp "$OVMF_VARS" "$VARS_COPY"
    log "Copied OVMF_VARS for this VM."
fi

# ─── Setup software TPM ─────────────────────────────────────────────────────

info "Initializing software TPM 2.0..."
swtpm_setup --tpmstate "$TPM_DIR" --tpm2 --createek 2>/dev/null || true
log "TPM state ready at $TPM_DIR"

# ─── Create the VM via virt-install ─────────────────────────────────────────

info "Creating VM '$VM_NAME' with virt-install..."
info "  CPUs: $CPUS  |  RAM: $((RAM / 1024)) GB  |  Disk: $DISK_SIZE"

# Remove existing VM definition if present (keep disk)
if $VIRSH dominfo "$VM_NAME" &>/dev/null; then
    warn "VM '$VM_NAME' already defined. Removing old definition (disk preserved)..."
    $VIRSH destroy "$VM_NAME" 2>/dev/null || true
    $VIRSH undefine "$VM_NAME" --nvram --tpm 2>/dev/null || true
fi

virt-install \
    --connect qemu:///system \
    --name "$VM_NAME" \
    --ram "$RAM" \
    --vcpus "$CPUS" \
    --cpu host-passthrough \
    --os-variant win11 \
    --machine q35 \
    --boot uefi,firmware.feature0.name=enrolled-keys,firmware.feature0.enabled=no,firmware.feature1.name=secure-boot,firmware.feature1.enabled=yes \
    --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
    --disk path="$DISK_IMG",bus=virtio,cache=writeback,discard=unmap \
    --cdrom "$WIN_ISO" \
    --disk path="$VIRTIO_ISO",device=cdrom \
    --network type=direct,source=eno1,source_mode=bridge,model=virtio \
    --graphics spice,listen=none \
    --video qxl \
    --channel spicevmc \
    --sound default \
    --controller type=usb,model=qemu-xhci \
    --controller type=scsi,model=virtio-scsi \
    --features smm.state=on,kvm_hidden=on,hyperv.relaxed.state=on,hyperv.vapic.state=on,hyperv.spinlocks.state=on,hyperv.spinlocks.retries=8191 \
    --clock hypervclock_present=yes \
    --memballoon model=virtio \
    --noautoconsole

log "VM '$VM_NAME' created successfully!"

# ─── Print summary ──────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}  ┌────────────────────────────────────────────┐"
echo -e "  │           VM Setup Complete!                │"
echo -e "  └────────────────────────────────────────────┘${NC}"
echo ""
echo -e "  ${GREEN}VM Name:${NC}    $VM_NAME"
echo -e "  ${GREEN}Disk:${NC}       $DISK_IMG"
echo -e "  ${GREEN}RAM:${NC}        $((RAM / 1024)) GB"
echo -e "  ${GREEN}CPUs:${NC}       $CPUS"
echo -e "  ${GREEN}TPM:${NC}        Software TPM 2.0"
echo -e "  ${GREEN}UEFI:${NC}       Secure Boot enabled"
echo ""
echo -e "  ${CYAN}Start the VM:${NC}"
echo -e "    sudo virsh --connect qemu:///system start $VM_NAME"
echo ""
echo -e "  ${CYAN}Open display:${NC}"
echo -e "    virt-viewer --connect qemu:///system $VM_NAME"
echo -e "    ${YELLOW}or use${NC} virt-manager ${YELLOW}for full GUI${NC}"
echo ""
echo -e "  ${CYAN}Windows Install Tips:${NC}"
echo -e "    1. Boot will open the Windows installer"
echo -e "    2. If no disks visible, click 'Load driver'"
echo -e "       Browse to VirtIO CD > viostor > w11 > amd64"
echo -e "    3. After install, mount VirtIO CD in Windows"
echo -e "       Run virtio-win-guest-tools.exe for all drivers"
echo ""
echo -e "  ${CYAN}Manage VM:${NC}"
echo -e "    sudo virsh --connect qemu:///system shutdown $VM_NAME    # graceful shutdown"
echo -e "    sudo virsh --connect qemu:///system destroy $VM_NAME     # force stop"
echo -e "    sudo virsh --connect qemu:///system snapshot-create-as $VM_NAME clean-install"
echo ""
