#!/bin/bash
# Unblock UFW firewall ports for Steam game downloads

set -e

# Cache sudo credentials upfront (single password prompt)
sudo -v || { echo "Failed to authenticate. Exiting."; exit 1; }

echo "Opening Steam ports in UFW..."

# Allow all traffic from private LAN subnets (game transfers, LAN cache, etc.)
for subnet in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12; do
  sudo ufw allow from "$subnet" comment "LAN traffic ($subnet)"
  sudo ufw allow to "$subnet" comment "LAN traffic ($subnet)"
done

# Steam client & downloads
sudo ufw allow 27000:27100/udp comment "Steam game traffic & downloads"
sudo ufw allow 27015:27050/tcp comment "Steam client"
sudo ufw allow 3478:4380/udp comment "Steamworks P2P / voice chat"
sudo ufw allow 4380/udp comment "Steam client discovery"

# Content delivery (downloads)
sudo ufw allow out 80/tcp comment "Steam HTTP"
sudo ufw allow out 443/tcp comment "Steam HTTPS"

# Reload firewall
sudo ufw reload

echo "Steam ports opened. Current UFW status:"
sudo ufw status numbered
