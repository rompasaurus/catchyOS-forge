#!/bin/bash
# Import/restore a VM from an export created by export-vm.sh
# Uses kdialog for GUI prompts (KDE native)
# Works on a fresh CachyOS install or an existing one

set -euo pipefail

VIRSH="virsh -c qemu:///system"

# --- GUI helpers ---
notify() { kdialog --passivepopup "$1" 5 --title "VM Import" 2>/dev/null; }
error_dialog() { kdialog --error "$1" --title "VM Import"; exit 1; }
info_dialog() { kdialog --msgbox "$1" --title "VM Import"; }

# --- Pick export directory ---
IMPORT_DIR=$(kdialog --getexistingdirectory "$HOME" --title "Select the VM export folder (contains .xml + .qcow2)")
[[ -z "$IMPORT_DIR" ]] && exit 0

# Validate it looks like an export
XML_FILE=$(find "$IMPORT_DIR" -maxdepth 1 -name "*.xml" -type f | head -1)
QCOW_FILE=$(find "$IMPORT_DIR" -maxdepth 1 -name "*.qcow2" -type f | head -1)

[[ -z "$XML_FILE" ]] && error_dialog "No .xml VM definition found in:\n${IMPORT_DIR}"
[[ -z "$QCOW_FILE" ]] && error_dialog "No .qcow2 disk image found in:\n${IMPORT_DIR}"

VM_NAME=$(basename "$XML_FILE" .xml)

# --- Check for conflicts ---
EXISTING=$($VIRSH list --all --name 2>/dev/null | grep -x "$VM_NAME" || true)
if [[ -n "$EXISTING" ]]; then
    EXISTING_STATE=$($VIRSH domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
    kdialog --warningyesno "VM '${VM_NAME}' already exists (${EXISTING_STATE}).\n\nRemove the existing VM and replace it with the backup?" --title "VM Import"
    [[ $? -ne 0 ]] && exit 0

    if [[ "$EXISTING_STATE" != "shutoff" ]]; then
        notify "Shutting down existing ${VM_NAME}..."
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
fi

# --- Gather files ---
NVRAM_FILE=$(find "$IMPORT_DIR" -maxdepth 1 -name "*.fd" -type f | head -1)
TPM_DIR=""
[[ -d "${IMPORT_DIR}/tpm" ]] && TPM_DIR="${IMPORT_DIR}/tpm"
ALL_QCOW=$(find "$IMPORT_DIR" -maxdepth 1 -name "*.qcow2" -type f)

# --- Pick destination for VM files ---
DEST_DEFAULT="/var/lib/libvirt/images/${VM_NAME}"

DEST=$(kdialog --inputbox "Where should the VM files be stored?" "$DEST_DEFAULT" --title "VM Import")
[[ -z "$DEST" ]] && exit 0

# --- Build summary ---
SUMMARY="VM: ${VM_NAME}\nSource: ${IMPORT_DIR}\nDestination: ${DEST}\n\nFiles to import:"
SUMMARY+="\n  - $(basename "$XML_FILE") (VM config)"

for QC in $ALL_QCOW; do
    QSIZE=$(ls -lh "$QC" 2>/dev/null | awk '{print $5}')
    SUMMARY+="\n  - $(basename "$QC") (${QSIZE})"
done

[[ -n "$NVRAM_FILE" ]] && SUMMARY+="\n  - $(basename "$NVRAM_FILE") (UEFI vars)"
[[ -n "$TPM_DIR" ]] && SUMMARY+="\n  - tpm/ (TPM state)"

SUMMARY+="\n\nThis will install dependencies if needed.\nProceed?"

kdialog --warningyesno "$SUMMARY" --title "VM Import"
[[ $? -ne 0 ]] && exit 0

# --- Install dependencies ---
DEPS=(qemu-full libvirt virt-manager swtpm edk2-ovmf)
MISSING=()
for pkg in "${DEPS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    notify "Installing: ${MISSING[*]}"
    sudo pacman -S --needed --noconfirm "${MISSING[@]}"
fi

# Enable libvirtd
if ! systemctl is-active --quiet libvirtd; then
    sudo systemctl enable --now libvirtd
fi

# --- Import with progress ---
TOTAL_STEPS=$(($(echo "$ALL_QCOW" | wc -w) + 3))
DBUSREF=$(kdialog --progressbar "Importing VM '${VM_NAME}'..." "$TOTAL_STEPS")
qdbus $DBUSREF showCancelButton false 2>/dev/null || true
STEP=0

# Create destination
qdbus $DBUSREF setLabelText "Creating ${DEST}..." 2>/dev/null || true
sudo mkdir -p "$DEST"
qdbus $DBUSREF Set "" value $((++STEP)) 2>/dev/null || true

# Copy disk images
for QC in $ALL_QCOW; do
    QNAME=$(basename "$QC")
    QSIZE=$(ls -lh "$QC" 2>/dev/null | awk '{print $5}')
    qdbus $DBUSREF setLabelText "Copying ${QNAME} (${QSIZE})...\n(this is the slow part)" 2>/dev/null || true
    sudo cp "$QC" "${DEST}/${QNAME}"
    qdbus $DBUSREF Set "" value $((++STEP)) 2>/dev/null || true
done

# Copy UEFI vars
if [[ -n "$NVRAM_FILE" ]]; then
    qdbus $DBUSREF setLabelText "Copying UEFI variables..." 2>/dev/null || true
    sudo cp "$NVRAM_FILE" "${DEST}/"
fi
qdbus $DBUSREF Set "" value $((++STEP)) 2>/dev/null || true

# Copy TPM state
if [[ -n "$TPM_DIR" ]]; then
    qdbus $DBUSREF setLabelText "Copying TPM state..." 2>/dev/null || true
    sudo cp -r "$TPM_DIR" "${DEST}/tpm"
fi
qdbus $DBUSREF Set "" value $((++STEP)) 2>/dev/null || true

# --- Fix XML paths and define VM ---
qdbus $DBUSREF setLabelText "Configuring VM definition..." 2>/dev/null || true

TEMP_XML=$(mktemp /tmp/vm-import-XXXX.xml)
cp "$XML_FILE" "$TEMP_XML"

# Update disk image paths
for QC in $ALL_QCOW; do
    QNAME=$(basename "$QC")
    # Replace any source file path ending with this filename
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

# Fix ownership
sudo chown -R libvirt-qemu:libvirt-qemu "${DEST}/"

# Define the VM
$VIRSH define "$TEMP_XML" 2>/dev/null || sudo virsh -c qemu:///system define "$TEMP_XML"
rm -f "$TEMP_XML"

# Set up default network
$VIRSH net-autostart default 2>/dev/null || true
$VIRSH net-start default 2>/dev/null || true

qdbus $DBUSREF close 2>/dev/null || true

# --- Offer to start ---
kdialog --yesno "VM '${VM_NAME}' imported successfully!\n\nDestination: ${DEST}\n\nStart the VM now?" --title "VM Import"
if [[ $? -eq 0 ]]; then
    $VIRSH start "$VM_NAME"
    notify "${VM_NAME} is starting."
fi
