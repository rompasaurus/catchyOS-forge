#!/bin/bash
# Increase swap: zram (ram*2, zstd) + 16GB disk swap file

set -e

echo "=== Increasing zram swap (zstd, ram * 2) ==="
sudo cp /usr/lib/systemd/zram-generator.conf /etc/systemd/zram-generator.conf
sudo sed -i 's/zram-size = ram$/zram-size = ram * 2/' /etc/systemd/zram-generator.conf

echo "=== Creating 16GB disk swap file ==="
sudo dd if=/dev/zero of=/swapfile bs=1G count=16 status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

echo "=== Adding swap file to /etc/fstab ==="
if ! grep -q '/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw,pri=10 0 0' | sudo tee -a /etc/fstab
else
    echo "Swap file entry already exists in /etc/fstab, skipping."
fi

echo "=== Restarting zram ==="
sudo systemctl daemon-reexec
sudo swapoff /dev/zram0
sudo systemctl restart systemd-zram-setup@zram0.service

echo "=== Done! Current swap status ==="
swapon --show
free -h
