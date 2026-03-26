#!/usr/bin/env bash
#
# setup-printer.sh — Auto-discover and set up Samsung M288x network printer
#
# Installs:
#   - CUPS printing system + Avahi discovery
#   - Samsung printer drivers (splix)
#   - KDE print manager
#   - Auto-discovers and adds the printer
#
set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }

PRINTER_MODEL="Samsung-M288x"

# ─── Install dependencies ────────────────────────────────────────────────────

log "Installing printing packages..."
sudo pacman -S --needed --noconfirm \
    cups \
    cups-filters \
    avahi \
    nss-mdns \
    splix \
    print-manager \
    system-config-printer

# ─── Enable services ─────────────────────────────────────────────────────────

log "Enabling CUPS and Avahi services..."
sudo systemctl enable --now cups.service
sudo systemctl enable --now avahi-daemon.service

# ─── Configure mDNS resolution ───────────────────────────────────────────────

# Ensure mdns is in nsswitch.conf for .local hostname resolution
if ! grep -q 'mdns_minimal' /etc/nsswitch.conf; then
    warn "Adding mDNS support to nsswitch.conf..."
    sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files dns/' /etc/nsswitch.conf
    log "mDNS resolution configured"
else
    info "mDNS resolution already configured"
fi

# ─── Add user to printer groups ──────────────────────────────────────────────

log "Adding $USER to printer groups..."
sudo usermod -aG lp,sys "$USER"

# ─── Discover printer ────────────────────────────────────────────────────────

log "Scanning for network printers (this may take a few seconds)..."
echo ""

DISCOVERED=""

# Try DNS-SD / mDNS discovery first
if command -v avahi-browse &>/dev/null; then
    info "Searching via Avahi/mDNS..."
    AVAHI_RESULTS=$(avahi-browse -t -r _ipp._tcp 2>/dev/null || true)
    if [[ -n "$AVAHI_RESULTS" ]]; then
        echo "$AVAHI_RESULTS" | grep -E '(hostname|address|txt)' | head -20
        echo ""
    fi
fi

# Use CUPS backend discovery
info "Searching via CUPS backends..."
CUPS_RESULTS=$(sudo lpinfo -v 2>/dev/null | grep -iE 'network|socket|ipp|dnssd' || true)

if [[ -n "$CUPS_RESULTS" ]]; then
    echo "$CUPS_RESULTS"
    echo ""

    # Try to find the Samsung printer specifically
    SAMSUNG_URI=$(echo "$CUPS_RESULTS" | grep -i -m1 'samsung\|m288\|2880\|SL-M' | awk '{print $2}' || true)

    if [[ -n "$SAMSUNG_URI" ]]; then
        DISCOVERED="$SAMSUNG_URI"
        log "Found Samsung printer: $DISCOVERED"
    fi
else
    warn "No network printers found via CUPS backends"
fi

# ─── Find the right driver ───────────────────────────────────────────────────

info "Searching for compatible drivers..."
DRIVER=$(sudo lpinfo -m 2>/dev/null | grep -i -m1 'samsung.*m288\|samsung.*2880\|SL-M288' || true)

if [[ -z "$DRIVER" ]]; then
    # Fallback: try broader Samsung match or generic PCL/PS
    DRIVER=$(sudo lpinfo -m 2>/dev/null | grep -i -m1 'samsung' || true)
fi

if [[ -z "$DRIVER" ]]; then
    DRIVER_PPD="everywhere"
    warn "No Samsung-specific driver found — using driverless IPP Everywhere"
else
    DRIVER_PPD=$(echo "$DRIVER" | awk '{print $1}')
    info "Found driver: $DRIVER"
fi

# ─── Add the printer ─────────────────────────────────────────────────────────

if [[ -n "$DISCOVERED" ]]; then
    log "Adding printer as '$PRINTER_MODEL'..."
    sudo lpadmin -p "$PRINTER_MODEL" \
        -v "$DISCOVERED" \
        -m "$DRIVER_PPD" \
        -E \
        -o media=na_letter_8.5x11in

    # Set as default printer
    lpadmin -d "$PRINTER_MODEL"
    log "Printer '$PRINTER_MODEL' added and set as default!"
else
    warn "Could not auto-detect Samsung M288x on the network."
    echo ""
    info "You can add it manually using one of these methods:"
    echo ""
    echo "  Option 1 — KDE System Settings:"
    echo "    System Settings → Printers → Add Printer"
    echo ""
    echo "  Option 2 — CUPS Web UI:"
    echo "    Open http://localhost:631 → Administration → Add Printer"
    echo ""
    echo "  Option 3 — Command line (replace IP with your printer's IP):"
    echo "    sudo lpadmin -p $PRINTER_MODEL -v ipp://PRINTER_IP/ipp/print -m $DRIVER_PPD -E"
    echo "    sudo lpadmin -d $PRINTER_MODEL"
    echo ""
    info "To find your printer's IP, check your router's DHCP client list"
    info "or the printer's network configuration page."
fi

# ─── Verify ──────────────────────────────────────────────────────────────────

echo ""
log "Installed printers:"
lpstat -p 2>/dev/null || info "No printers configured yet"
echo ""
log "CUPS status:"
systemctl is-active cups.service

echo ""
log "Setup complete! If the printer was not auto-detected:"
info "  1. Ensure the printer is powered on and connected to your network"
info "  2. Re-run this script, or add manually via System Settings → Printers"
info "  3. CUPS web admin: http://localhost:631"
