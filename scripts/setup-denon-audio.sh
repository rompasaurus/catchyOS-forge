#!/usr/bin/env bash
#
# setup-denon-audio.sh — Configure HDMI audio output to DENON-AVR (7.1 surround)
#
# Installs:
#   - Fix script at ~/.local/bin/fix-denon-audio
#   - Desktop menu entry for quick access
#   - WirePlumber config for automatic routing on boot
#   - Systemd user service as fallback
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }

CARD="alsa_card.pci-0000_0a_00.0"
PROFILE="output:hdmi-surround71-extra1"

# ─── Install fix script ─────────────────────────────────────────────────────

log "Installing fix-denon-audio script..."
mkdir -p ~/.local/bin

cat > ~/.local/bin/fix-denon-audio << 'SCRIPT'
#!/bin/bash
# Fix audio output to DENON-AVR via HDMI 2 (7.1 surround)

CARD="alsa_card.pci-0000_0a_00.0"
PROFILE="output:hdmi-surround71-extra1"

echo "Setting audio profile to 7.1 surround on DENON-AVR..."
pactl set-card-profile "$CARD" "$PROFILE"

# Wait for sink to appear
sleep 1

# Get the new sink name (pactl ID)
SINK_PACTL=$(pactl list sinks short | grep "hdmi-surround71-extra1" | awk '{print $1}')
# Get the WirePlumber object ID
SINK_WPCTL=$(wpctl status | grep -oP '\d+(?=\.\s+HDA Intel PCH Digital Surround 7\.1 \(HDMI 2\))')

if [ -z "$SINK_PACTL" ] || [ -z "$SINK_WPCTL" ]; then
    echo "ERROR: Could not find Denon sink. Is the HDMI cable connected?"
    exit 1
fi

# Set as default using WirePlumber ID
wpctl set-default "$SINK_WPCTL"
wpctl set-volume "$SINK_WPCTL" 0.75

# Move all active streams to the Denon using pactl ID
pactl list sink-inputs short | awk '{print $1}' | while read -r INPUT; do
    pactl move-sink-input "$INPUT" "$SINK_PACTL" 2>/dev/null
done

echo "Audio routed to DENON-AVR (7.1 surround, HDMI 2)"
echo "Volume set to 75%"

# Verify
wpctl status | grep -A2 "Sinks:"
SCRIPT

chmod +x ~/.local/bin/fix-denon-audio
log "Installed ~/.local/bin/fix-denon-audio"

# ─── Install desktop entry ──────────────────────────────────────────────────

log "Installing desktop menu entry..."
mkdir -p ~/.local/share/applications

cat > ~/.local/share/applications/fix-denon-audio.desktop << 'DESKTOP'
[Desktop Entry]
Name=Fix Denon Audio
Comment=Route audio to DENON-AVR via HDMI (7.1 surround)
Exec=/home/rompasaurus/.local/bin/fix-denon-audio
Icon=audio-speakers
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Settings;
Keywords=denon;audio;hdmi;surround;fix;
DESKTOP

log "Installed desktop entry (search 'Fix Denon Audio' in launcher)"

# ─── Install WirePlumber config ──────────────────────────────────────────────

log "Installing WirePlumber config for auto-routing on boot..."
mkdir -p ~/.config/wireplumber/wireplumber.conf.d

cat > ~/.config/wireplumber/wireplumber.conf.d/50-denon-default.conf << 'WPCONF'
monitor.alsa.rules = [
  {
    matches = [
      {
        device.name = "alsa_card.pci-0000_0a_00.0"
      }
    ]
    actions = {
      update-props = {
        api.alsa.use-acp = true
      }
      set-profile = "output:hdmi-surround71-extra1"
    }
  }
]

node.rules = [
  {
    matches = [
      {
        node.name = "alsa_output.pci-0000_0a_00.0.hdmi-surround71-extra1"
      }
    ]
    actions = {
      update-props = {
        node.description = "DENON-AVR 7.1 Surround"
        priority.session = 2000
        priority.driver = 2000
      }
    }
  }
]
WPCONF

log "Installed WirePlumber config"

# ─── Install systemd user service (fallback) ────────────────────────────────

log "Installing systemd user service..."
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/fix-denon-audio.service << 'SERVICE'
[Unit]
Description=Fix Denon AVR HDMI audio output
After=pipewire.service wireplumber.service
Wants=pipewire.service wireplumber.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 3
ExecStart=/home/rompasaurus/.local/bin/fix-denon-audio
RemainAfterExit=yes

[Install]
WantedBy=graphical-session.target
SERVICE

systemctl --user daemon-reload
systemctl --user enable fix-denon-audio.service
log "Enabled fix-denon-audio.service"

# ─── Apply now ───────────────────────────────────────────────────────────────

info "Applying audio fix now..."
~/.local/bin/fix-denon-audio

echo ""
log "Denon audio setup complete!"
info "Audio will auto-route to DENON-AVR on every boot."
info "If it ever stops, run: fix-denon-audio"
info "Or search 'Fix Denon Audio' in the app launcher."
