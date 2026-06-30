#!/bin/bash
set -uo pipefail

echo "=== Fixing win11 VM import ==="

echo "[1/4] Creating NVRAM vars..."
sudo mkdir -p /var/lib/libvirt/qemu/nvram
sudo cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /var/lib/libvirt/qemu/nvram/win11_VARS.fd

echo "[2/4] Copying TPM state..."
sudo mkdir -p /var/lib/libvirt/images/win11/tpm
sudo cp -r "/mnt/dookintel/Steam/VM Backup/win11-export/tpm/"* /var/lib/libvirt/images/win11/tpm/

echo "[3/4] Fixing ownership..."
sudo chown -R qemu:qemu /var/lib/libvirt/images/win11/

echo "[4/4] Defining VM..."
sudo virsh -c qemu:///system define /tmp/win11-import.xml

echo ""
virsh -c qemu:///system list --all
echo ""
echo "=== Done. win11 should now appear in virt-manager ==="
