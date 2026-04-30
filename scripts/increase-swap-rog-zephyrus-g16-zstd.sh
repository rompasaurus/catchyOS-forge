#!/bin/bash
# Increase swap on ROG Zephyrus G16 (32GB RAM, ext4, NVMe):
#   - zram: ram * 2 with zstd  (high-prio, primary)
#   - 32GB disk swapfile       (low-prio, overflow for big compiles / updates)
# Re-runnable: skips work that's already been done.

set -euo pipefail

SWAPFILE=/swapfile
SWAPFILE_SIZE_GB=32

echo "=== Configuring zram (ram * 2, zstd) ==="
if [ ! -f /etc/systemd/zram-generator.conf ]; then
    sudo cp /usr/lib/systemd/zram-generator.conf /etc/systemd/zram-generator.conf
fi
# Force zram-size = ram * 2 regardless of prior value (ram, ram/2, etc.)
sudo sed -i -E 's/^[[:space:]]*zram-size[[:space:]]*=.*/zram-size = ram * 2/' \
    /etc/systemd/zram-generator.conf
# Ensure zstd is the algorithm
if ! grep -qE '^[[:space:]]*compression-algorithm[[:space:]]*=[[:space:]]*zstd' \
        /etc/systemd/zram-generator.conf; then
    sudo sed -i -E 's/^[[:space:]]*compression-algorithm[[:space:]]*=.*/compression-algorithm = zstd/' \
        /etc/systemd/zram-generator.conf
fi

echo "=== Creating ${SWAPFILE_SIZE_GB}GB disk swapfile at ${SWAPFILE} ==="
if [ -f "${SWAPFILE}" ]; then
    echo "${SWAPFILE} already exists, skipping creation."
else
    # fallocate is instant on ext4 (root FS here is ext4); no zero-fill needed.
    sudo fallocate -l "${SWAPFILE_SIZE_GB}G" "${SWAPFILE}"
    sudo chmod 600 "${SWAPFILE}"
    sudo mkswap "${SWAPFILE}"
fi

if ! swapon --show=NAME --noheadings | grep -qx "${SWAPFILE}"; then
    sudo swapon -p 10 "${SWAPFILE}"
fi

echo "=== Adding swapfile to /etc/fstab ==="
if ! grep -qE "^${SWAPFILE}[[:space:]]" /etc/fstab; then
    echo "${SWAPFILE} none swap sw,pri=10 0 0" | sudo tee -a /etc/fstab
else
    echo "fstab entry for ${SWAPFILE} already exists, skipping."
fi

echo "=== Restarting zram with new config ==="
sudo systemctl daemon-reload
if swapon --show=NAME --noheadings | grep -qx /dev/zram0; then
    sudo swapoff /dev/zram0
fi
sudo systemctl restart systemd-zram-setup@zram0.service

echo "=== Done. Current swap state ==="
swapon --show
free -h
echo
echo "Tunables (CachyOS default vm.swappiness=150 already favors zram heavily;"
echo "disk swapfile at prio 10 will only engage once zram is saturated)."
