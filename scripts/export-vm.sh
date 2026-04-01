#!/bin/bash
# Export a libvirt VM (disk, config, UEFI vars, TPM) to a chosen directory
# Uses kdialog for GUI prompts (KDE native)

set -euo pipefail

# --- GUI helpers ---
notify() { kdialog --passivepopup "$1" 5 --title "VM Export" 2>/dev/null; }
error_dialog() { kdialog --error "$1" --title "VM Export"; exit 1; }
info_dialog() { kdialog --msgbox "$1" --title "VM Export"; }

# --- Pick VM ---
VM_LIST=$(virsh list --all --name 2>/dev/null | grep -v '^$' || true)
[[ -z "$VM_LIST" ]] && error_dialog "No VMs found in libvirt."

if [[ $(echo "$VM_LIST" | wc -l) -eq 1 ]]; then
    VM_NAME="$VM_LIST"
else
    VM_NAME=$(echo "$VM_LIST" | tr '\n' ' ' | xargs -n1 | awk '{print $1 " " $1}' | xargs kdialog --menu "Select VM to export:" --title "VM Export")
    [[ -z "$VM_NAME" ]] && exit 0
fi

# --- Check VM is shut off ---
VM_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
if [[ "$VM_STATE" != "shutoff" ]]; then
    kdialog --warningyesno "VM '$VM_NAME' is currently ${VM_STATE}.\n\nIt must be shut down for a clean export.\nShut it down now?" --title "VM Export"
    if [[ $? -eq 0 ]]; then
        notify "Shutting down ${VM_NAME}..."
        virsh shutdown "$VM_NAME" 2>/dev/null
        # Wait for shutdown (max 120s)
        for i in $(seq 1 60); do
            sleep 2
            STATE=$(virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
            [[ "$STATE" == "shutoff" ]] && break
            if [[ $i -eq 60 ]]; then
                error_dialog "VM did not shut down in time. Try: virsh destroy ${VM_NAME}"
            fi
        done
        notify "VM shut down."
    else
        error_dialog "Cannot export a running VM safely."
    fi
fi

# --- Pick destination ---
DEST_DIR=$(kdialog --getexistingdirectory "$HOME" --title "Choose export destination for '${VM_NAME}'")
[[ -z "$DEST_DIR" ]] && exit 0

EXPORT_DIR="${DEST_DIR}/${VM_NAME}-export"
if [[ -d "$EXPORT_DIR" ]]; then
    kdialog --warningyesno "Directory already exists:\n${EXPORT_DIR}\n\nOverwrite?" --title "VM Export"
    [[ $? -ne 0 ]] && exit 0
fi
mkdir -p "$EXPORT_DIR"

# --- Find VM disk and files ---
# Get XML config
VM_XML=$(sudo virsh dumpxml "$VM_NAME" --inactive 2>/dev/null)
if [[ -z "$VM_XML" ]]; then
    error_dialog "Failed to dump VM XML. Do you have sudo access?"
fi

# Save XML
echo "$VM_XML" > "${EXPORT_DIR}/${VM_NAME}.xml"

# Extract disk image paths from XML
DISK_PATHS=$(echo "$VM_XML" | grep -oP "source file='\K[^']+")

# Extract NVRAM (UEFI vars) path
NVRAM_PATH=$(echo "$VM_XML" | grep -oP "<nvram>\K[^<]+" || true)

# Extract TPM state path
TPM_PATH=$(echo "$VM_XML" | grep -oP "source path='\K[^']+/tpm[^']*" | head -1 || true)
# Also check for the parent dir containing tpm state
if [[ -n "$TPM_PATH" ]] && [[ -d "$TPM_PATH" ]]; then
    TPM_DIR="$TPM_PATH"
elif [[ -n "$DISK_PATHS" ]]; then
    # TPM state is usually next to the disk image
    FIRST_DISK=$(echo "$DISK_PATHS" | head -1)
    DISK_DIR=$(dirname "$FIRST_DISK")
    if [[ -d "${DISK_DIR}/tpm" ]]; then
        TPM_DIR="${DISK_DIR}/tpm"
    fi
fi

# --- Calculate total size ---
TOTAL_SIZE=0
for DISK in $DISK_PATHS; do
    if [[ -f "$DISK" ]]; then
        SIZE=$(stat -c %s "$DISK" 2>/dev/null || echo 0)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    fi
done

TOTAL_HUMAN=$(numfmt --to=iec $TOTAL_SIZE 2>/dev/null || echo "${TOTAL_SIZE} bytes")

# --- Confirm ---
SUMMARY="VM: ${VM_NAME}\nDestination: ${EXPORT_DIR}\n\nFiles to export:"
SUMMARY+="\n  - VM config (${VM_NAME}.xml)"

for DISK in $DISK_PATHS; do
    DNAME=$(basename "$DISK")
    DSIZE=$(stat -c %s "$DISK" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
    SUMMARY+="\n  - ${DNAME} (${DSIZE}, will be compressed)"
done

[[ -n "${NVRAM_PATH:-}" ]] && [[ -f "$NVRAM_PATH" ]] && SUMMARY+="\n  - $(basename $NVRAM_PATH) (UEFI vars)"
[[ -n "${TPM_DIR:-}" ]] && [[ -d "$TPM_DIR" ]] && SUMMARY+="\n  - tpm/ (TPM state)"

SUMMARY+="\n\nThis may take a while for large disks.\nProceed?"

kdialog --warningyesno "$SUMMARY" --title "VM Export"
[[ $? -ne 0 ]] && exit 0

# --- Export with progress ---
DBUSREF=$(kdialog --progressbar "Exporting VM '${VM_NAME}'..." $(($(echo "$DISK_PATHS" | wc -w) + 3)))
qdbus $DBUSREF showCancelButton false 2>/dev/null || true
STEP=0

# Export XML
qdbus $DBUSREF setLabelText "Saving VM configuration..." 2>/dev/null || true
qdbus $DBUSREF Set "" value $((++STEP)) 2>/dev/null || true

# Export UEFI vars
if [[ -n "${NVRAM_PATH:-}" ]] && [[ -f "$NVRAM_PATH" ]]; then
    qdbus $DBUSREF setLabelText "Copying UEFI variables..." 2>/dev/null || true
    sudo cp "$NVRAM_PATH" "${EXPORT_DIR}/"
    qdbus $DBUSREF Set "" value $((++STEP)) 2>/dev/null || true
fi

# Export TPM state
if [[ -n "${TPM_DIR:-}" ]] && [[ -d "$TPM_DIR" ]]; then
    qdbus $DBUSREF setLabelText "Copying TPM state..." 2>/dev/null || true
    sudo cp -r "$TPM_DIR" "${EXPORT_DIR}/tpm"
    qdbus $DBUSREF Set "" value $((++STEP)) 2>/dev/null || true
fi

# Export and compress disk images
for DISK in $DISK_PATHS; do
    DNAME=$(basename "$DISK")
    qdbus $DBUSREF setLabelText "Compressing ${DNAME}...\n(this is the slow part)" 2>/dev/null || true

    sudo qemu-img convert -O qcow2 -c -p "$DISK" "${EXPORT_DIR}/${DNAME}" 2>&1 | \
    while IFS= read -r line; do
        # qemu-img -p outputs progress like (45.23/100%)
        PCT=$(echo "$line" | grep -oP '[\d.]+(?=/100%)' | head -1 || true)
        if [[ -n "$PCT" ]]; then
            qdbus $DBUSREF setLabelText "Compressing ${DNAME}... ${PCT}%" 2>/dev/null || true
        fi
    done

    qdbus $DBUSREF Set "" value $((++STEP)) 2>/dev/null || true
done

# Fix ownership so user can move the files
sudo chown -R "$(id -u):$(id -g)" "${EXPORT_DIR}"

qdbus $DBUSREF close 2>/dev/null || true

# --- Write import script ---
cat > "${EXPORT_DIR}/import-vm.sh" << 'IMPORT_SCRIPT'
#!/bin/bash
# Import VM on a fresh CachyOS machine
# Run from the directory containing the exported files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_XML=$(ls "$SCRIPT_DIR"/*.xml | head -1)
VM_NAME=$(basename "$VM_XML" .xml)
DEST="/var/lib/libvirt/images/${VM_NAME}"

echo "[+] Installing dependencies..."
sudo pacman -S --needed --noconfirm qemu-full libvirt virt-manager swtpm edk2-ovmf

echo "[+] Enabling libvirt..."
sudo systemctl enable --now libvirtd

echo "[+] Creating ${DEST}..."
sudo mkdir -p "$DEST"

echo "[+] Copying disk image(s)..."
for QCOW in "$SCRIPT_DIR"/*.qcow2; do
    echo "    $(basename "$QCOW")"
    sudo cp "$QCOW" "$DEST/"
done

echo "[+] Copying UEFI variables..."
for FD in "$SCRIPT_DIR"/*.fd; do
    [[ -f "$FD" ]] && sudo cp "$FD" "$DEST/"
done

if [[ -d "$SCRIPT_DIR/tpm" ]]; then
    echo "[+] Copying TPM state..."
    sudo cp -r "$SCRIPT_DIR/tpm" "$DEST/"
fi

echo "[+] Fixing paths in VM config..."
# Update paths in XML to point to new location
TEMP_XML=$(mktemp)
sed "s|/var/lib/libvirt/images/${VM_NAME}/|${DEST}/|g" "$VM_XML" > "$TEMP_XML"
# Also fix any other absolute paths to the disk/nvram/tpm
sed -i "s|<source file='[^']*/${VM_NAME}\.qcow2'|<source file='${DEST}/${VM_NAME}.qcow2'|g" "$TEMP_XML"
sed -i "s|<nvram>[^<]*</nvram>|<nvram>${DEST}/$(ls "$SCRIPT_DIR"/*.fd 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo OVMF_VARS.4m.fd)</nvram>|g" "$TEMP_XML"

echo "[+] Setting ownership..."
sudo chown -R libvirt-qemu:libvirt-qemu "$DEST/"

echo "[+] Defining VM..."
sudo virsh define "$TEMP_XML"
rm "$TEMP_XML"

echo "[+] Setting up default network..."
sudo virsh net-autostart default 2>/dev/null || true
sudo virsh net-start default 2>/dev/null || true

echo ""
echo "[+] Done! Start with: virsh start ${VM_NAME}"
echo "    Or open virt-manager."
IMPORT_SCRIPT

chmod +x "${EXPORT_DIR}/import-vm.sh"

# --- Summary ---
FINAL_SIZE=$(dust -s -d0 "$EXPORT_DIR" 2>/dev/null || echo "?")
info_dialog "Export complete!\n\nSaved to: ${EXPORT_DIR}\n\nContents:\n$(ls -lh "$EXPORT_DIR" | tail -n+2)\n\nTo import on a new machine, copy the folder and run:\n  ./import-vm.sh"
