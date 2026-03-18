#!/bin/bash
# Open firewall ports for Steam's "Local Network Game Transfer" feature
# Allows downloading games from another PC on the same LAN instead of the internet
# Run this on BOTH PCs

# Steam LAN discovery (UDP broadcast)
sudo ufw allow 27031:27036/udp comment "Steam LAN discovery"

# Steam LAN transfer data ports (both reported by Valve - conflicting docs)
sudo ufw allow 27040/tcp comment "Steam LAN game transfer"
sudo ufw allow 24070/tcp comment "Steam LAN game transfer (alt port)"

# Steam download range
sudo ufw allow 27014:27050/tcp comment "Steam downloads"

sudo ufw reload

echo ""
echo "Done. Make sure both PCs have:"
echo "  1. Steam > Settings > Downloads > 'Transfer files over local network' enabled"
echo "  2. Both PCs on the same subnet"
echo "  3. This script run on BOTH machines"
