#!/bin/bash
# Mount a Samba share from the win11 VM
# Usage: ./mount-win11-share.sh [mount_point]

set -euo pipefail

VM_NAME="win11"
MOUNT_POINT="${1:-/mnt/win11}"
NETWORK="default"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# Check if VM is running
if ! virsh list --state-running --name 2>/dev/null | grep -q "^${VM_NAME}$"; then
    error "VM '${VM_NAME}' is not running. Start it first: virsh start ${VM_NAME}"
fi

# Get VM IP from DHCP leases
info "Finding VM IP address..."
VM_IP=$(virsh net-dhcp-leases "$NETWORK" 2>/dev/null | grep -oP '(\d+\.\d+\.\d+\.\d+)' | head -1)

if [[ -z "$VM_IP" ]]; then
    # Fallback: try arp scan on virbr0 subnet
    warn "No DHCP lease found, trying ARP scan..."
    VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oP '(\d+\.\d+\.\d+\.\d+)' | head -1)
fi

if [[ -z "$VM_IP" ]]; then
    error "Could not determine VM IP. Make sure the VM is running and has a network connection."
fi

info "VM IP: ${VM_IP}"

# Discover available shares
info "Discovering shares on ${VM_IP}..."
echo ""

SHARES=$(smbclient -L "//${VM_IP}" -N 2>/dev/null | grep -i "Disk" | awk '{print $1}' || true)

if [[ -z "$SHARES" ]]; then
    warn "No shares found with anonymous access. Trying with credentials..."
    read -rp "Windows username: " WIN_USER
    read -rsp "Windows password: " WIN_PASS
    echo ""
    SHARES=$(smbclient -L "//${VM_IP}" -U "${WIN_USER}%${WIN_PASS}" 2>/dev/null | grep -i "Disk" | awk '{print $1}' || true)
fi

if [[ -z "$SHARES" ]]; then
    error "No shares found. Make sure you have shared a folder in Windows first."
fi

# Let user pick a share
echo ""
info "Available shares:"
IFS=$'\n' read -rd '' -a SHARE_ARRAY <<< "$SHARES" || true

for i in "${!SHARE_ARRAY[@]}"; do
    echo "  $((i+1))) ${SHARE_ARRAY[$i]}"
done

echo ""
read -rp "Select share number [1]: " CHOICE
CHOICE="${CHOICE:-1}"
SELECTED="${SHARE_ARRAY[$((CHOICE-1))]}"

info "Selected share: ${SELECTED}"

# Get credentials if we don't have them yet
if [[ -z "${WIN_USER:-}" ]]; then
    read -rp "Windows username: " WIN_USER
    read -rsp "Windows password: " WIN_PASS
    echo ""
fi

# Create mount point
if [[ ! -d "$MOUNT_POINT" ]]; then
    info "Creating mount point: ${MOUNT_POINT}"
    sudo mkdir -p "$MOUNT_POINT"
fi

# Unmount if already mounted
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    warn "Already mounted, unmounting first..."
    sudo umount "$MOUNT_POINT"
fi

# Mount the share
info "Mounting //${VM_IP}/${SELECTED} → ${MOUNT_POINT}"
sudo mount -t cifs "//${VM_IP}/${SELECTED}" "$MOUNT_POINT" \
    -o "username=${WIN_USER},password=${WIN_PASS},uid=$(id -u),gid=$(id -g),file_mode=0664,dir_mode=0775"

if mountpoint -q "$MOUNT_POINT"; then
    info "Mounted successfully!"
    echo ""
    ls "$MOUNT_POINT"
else
    error "Mount failed."
fi
