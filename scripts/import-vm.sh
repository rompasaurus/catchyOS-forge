#!/bin/bash
# Import/restore a VM from an export created by export-vm.sh
# Uses kdialog for GUI pickers, terminal for progress output
# Works on a fresh CachyOS install or an existing one

set -uo pipefail

VIRSH="virsh -c qemu:///system"

# --- GUI helpers (pickers/confirmations only) ---
notify() { kdialog --passivepopup "$1" 5 --title "VM Import" 2>/dev/null; }
error_exit() { echo -e "\e[31m[ERROR]\e[0m $1" >&2; kdialog --error "$1" --title "VM Import" 2>/dev/null; exit 1; }
status() { echo -e "\e[36m[INFO]\e[0m $1"; }
success() { echo -e "\e[32m[OK]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }

# Global error trap
trap 'error_exit "Script failed at line $LINENO. Run with: bash -x import-vm.sh"' ERR

echo ""
echo "========================================="
echo "         VM Import Tool"
echo "========================================="
echo ""

# --- Pick export directory ---
status "Select the VM export folder..."
IMPORT_DIR=$(kdialog --getexistingdirectory "$HOME" --title "Select the VM export folder (contains .xml + .qcow2)") || true
[[ -z "$IMPORT_DIR" ]] && { echo "Cancelled."; exit 0; }
status "Source: ${IMPORT_DIR}"

# Validate it looks like an export
XML_FILE=$(find "$IMPORT_DIR" -maxdepth 1 -name "*.xml" -type f | head -1) || true
QCOW_FILE=$(find "$IMPORT_DIR" -maxdepth 1 -name "*.qcow2" -type f | head -1) || true

[[ -z "$XML_FILE" ]] && error_exit "No .xml VM definition found in: ${IMPORT_DIR}"
[[ -z "$QCOW_FILE" ]] && error_exit "No .qcow2 disk image found in: ${IMPORT_DIR}"

VM_NAME=$(basename "$XML_FILE" .xml)
success "Found VM: ${VM_NAME}"

# --- Check for conflicts ---
EXISTING=$($VIRSH list --all --name 2>/dev/null | grep -x "$VM_NAME" || true)
if [[ -n "$EXISTING" ]]; then
    EXISTING_STATE=$($VIRSH domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
    warn "VM '${VM_NAME}' already exists (${EXISTING_STATE})"
    kdialog --warningyesno "VM '${VM_NAME}' already exists (${EXISTING_STATE}).\n\nRemove and replace with backup?" --title "VM Import" || exit 0

    if [[ "$EXISTING_STATE" != "shutoff" ]]; then
        status "Shutting down existing ${VM_NAME}..."
        $VIRSH shutdown "$VM_NAME" 2>/dev/null || true
        for i in $(seq 1 30); do
            sleep 2
            STATE=$($VIRSH domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
            [[ "$STATE" == "shutoff" ]] && break
            if [[ $i -eq 30 ]]; then
                $VIRSH destroy "$VM_NAME" 2>/dev/null || true
                sleep 2
            fi
        done
    fi
    $VIRSH undefine "$VM_NAME" --nvram 2>/dev/null || $VIRSH undefine "$VM_NAME" 2>/dev/null || true
    success "Removed existing VM"
fi

# --- Gather files ---
NVRAM_FILE=$(find "$IMPORT_DIR" -maxdepth 1 -name "*.fd" -type f | head -1) || true
TPM_DIR=""
[[ -d "${IMPORT_DIR}/tpm" ]] && TPM_DIR="${IMPORT_DIR}/tpm"

mapfile -t QCOW_FILES < <(find "$IMPORT_DIR" -maxdepth 1 -name "*.qcow2" -type f)

# --- Pick destination for VM files ---
status "Select destination folder..."
DEST_PARENT=$(kdialog --getexistingdirectory "/var/lib/libvirt/images" --title "Select destination folder for VM files") || true
[[ -z "$DEST_PARENT" ]] && { echo "Cancelled."; exit 0; }
DEST="${DEST_PARENT}/${VM_NAME}"

# --- Print summary ---
echo ""
echo "========================================="
echo "  Import Summary"
echo "========================================="
echo "  VM:          ${VM_NAME}"
echo "  Source:      ${IMPORT_DIR}"
echo "  Destination: ${DEST}"
echo ""
echo "  Files:"
echo "    - $(basename "$XML_FILE") (VM config)"
for QC in "${QCOW_FILES[@]}"; do
    QSIZE=$(du -h "$QC" 2>/dev/null | cut -f1) || QSIZE="?"
    echo "    - $(basename "$QC") (${QSIZE})"
done
[[ -n "$NVRAM_FILE" ]] && echo "    - $(basename "$NVRAM_FILE") (UEFI vars)"
[[ -n "$TPM_DIR" ]] && echo "    - tpm/ (TPM state)"
echo "========================================="
echo ""

kdialog --warningyesno "Import VM '${VM_NAME}' to ${DEST}?\n\nThis will install dependencies if needed." --title "VM Import" || exit 0

# --- Install dependencies ---
DEPS=(qemu-full libvirt virt-manager swtpm edk2-ovmf rsync)
MISSING=()
for pkg in "${DEPS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    status "Installing: ${MISSING[*]}"
    sudo pacman -S --needed --noconfirm "${MISSING[@]}"
    success "Dependencies installed"
fi

# Enable libvirtd
if ! systemctl is-active --quiet libvirtd; then
    status "Enabling libvirtd..."
    sudo systemctl enable --now libvirtd
    success "libvirtd started"
fi

# --- Create destination ---
status "Creating ${DEST}..."
sudo mkdir -p "$DEST"

# --- Copy disk images with rsync progress ---
echo ""
for QC in "${QCOW_FILES[@]}"; do
    QNAME=$(basename "$QC")
    QSIZE=$(du -h "$QC" 2>/dev/null | cut -f1) || QSIZE="?"
    echo "-----------------------------------------"
    status "Copying ${QNAME} (${QSIZE})..."
    echo "-----------------------------------------"
    sudo rsync --progress --info=progress2 -- "$QC" "${DEST}/${QNAME}"
    success "Copied ${QNAME}"
    echo ""
done

# Copy UEFI vars
if [[ -n "$NVRAM_FILE" ]]; then
    status "Copying UEFI variables..."
    sudo cp -- "$NVRAM_FILE" "${DEST}/"
    success "UEFI vars copied"
fi

# Copy TPM state
if [[ -n "$TPM_DIR" ]]; then
    status "Copying TPM state..."
    sudo cp -r -- "$TPM_DIR" "${DEST}/tpm"
    success "TPM state copied"
fi

# --- Fix XML paths and define VM ---
status "Configuring VM definition..."

TEMP_XML=$(mktemp /tmp/vm-import-XXXX.xml)
cp "$XML_FILE" "$TEMP_XML"

# Update disk image paths
for QC in "${QCOW_FILES[@]}"; do
    QNAME=$(basename "$QC")
    sed -i "s|<source file='[^']*/${QNAME}'|<source file='${DEST}/${QNAME}'|g" "$TEMP_XML"
done

# Update NVRAM path
if [[ -n "$NVRAM_FILE" ]]; then
    NVRAM_NAME=$(basename "$NVRAM_FILE")
    sed -i "s|<nvram>[^<]*</nvram>|<nvram>${DEST}/${NVRAM_NAME}</nvram>|g" "$TEMP_XML"
fi

# Update TPM state path
if [[ -n "$TPM_DIR" ]]; then
    sed -i "s|<source path='[^']*tpm[^']*'|<source path='${DEST}/tpm'|g" "$TEMP_XML"
fi

# Fix ownership (Arch/CachyOS uses qemu:qemu, not libvirt-qemu)
QEMU_USER=$(grep -Po '^\s*user\s*=\s*"\K[^"]+' /etc/libvirt/qemu.conf 2>/dev/null || echo "qemu")
QEMU_GROUP=$(grep -Po '^\s*group\s*=\s*"\K[^"]+' /etc/libvirt/qemu.conf 2>/dev/null || echo "qemu")
status "Setting ownership to ${QEMU_USER}:${QEMU_GROUP}"
sudo chown -R "${QEMU_USER}:${QEMU_GROUP}" "${DEST}/"
success "Ownership set"

# Define the VM
status "Defining VM in libvirt..."
DEFINE_OUTPUT=$($VIRSH define "$TEMP_XML" 2>&1) || {
    rm -f "$TEMP_XML"
    error_exit "Failed to define VM:\n${DEFINE_OUTPUT}"
}
rm -f "$TEMP_XML"
success "${DEFINE_OUTPUT}"

# Set up default network
$VIRSH net-autostart default 2>/dev/null || true
$VIRSH net-start default 2>/dev/null || true

# Verify VM is visible
VM_STATE=$($VIRSH domstate "$VM_NAME" 2>&1) || {
    error_exit "VM was defined but not found. virsh says: ${VM_STATE}"
}
success "VM state: ${VM_STATE}"

# --- Done ---
echo ""
echo "========================================="
echo -e "  \e[32mVM '${VM_NAME}' imported successfully!\e[0m"
echo ""
echo "  Location: ${DEST}"
echo "  State:    ${VM_STATE}"
echo "  Owner:    ${QEMU_USER}:${QEMU_GROUP}"
echo "========================================="
echo ""

kdialog --yesno "VM '${VM_NAME}' imported successfully!\n\nStart the VM now?" --title "VM Import"
if [[ $? -eq 0 ]]; then
    status "Starting ${VM_NAME}..."
    $VIRSH start "$VM_NAME"
    success "${VM_NAME} is running."
fi
