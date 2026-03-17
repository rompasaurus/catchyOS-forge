#!/usr/bin/env bash
#
# Install Easy Swipe — Mac-like mouse gestures for GNOME/Wayland.
# Hold mouse back button + swipe to switch workspaces, open Activities, etc.
#
# Run with: bash scripts/setup-easy-swipe.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH="$HOME/.local/bin/mouse-workspace-swipe.py"
SERVICE_PATH="$HOME/.config/systemd/user/mouse-workspace-swipe.service"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │    Easy Swipe Installer                   │"
echo "  │   Mouse Gesture Workspace Switching       │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Install python-evdev ────────────────────────────────────────────────────

if pacman -Qi python-evdev &>/dev/null; then
    log "python-evdev already installed"
else
    info "Installing python-evdev..."
    sudo pacman -S --needed --noconfirm python-evdev
    log "python-evdev installed."
fi

# ─── Add user to input group ────────────────────────────────────────────────

if groups "$USER" | grep -qw input; then
    log "$USER is already in the input group"
else
    info "Adding $USER to input group..."
    sudo usermod -aG input "$USER"
    warn "You'll need to log out and back in for the input group to take effect."
fi

# ─── Install swipe script ───────────────────────────────────────────────────

info "Installing swipe script..."
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/easy-swipe/mouse-workspace-swipe.py" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
log "Installed to $INSTALL_PATH"

# ─── Install systemd service ────────────────────────────────────────────────

info "Setting up systemd service..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Mouse back button workspace swipe
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $HOME/.local/bin/mouse-workspace-swipe.py
Restart=on-failure
RestartSec=3
# Import the DBus session so qdbus6 can talk to KWin
Environment=QT_QPA_PLATFORM=wayland

[Install]
WantedBy=graphical-session.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now mouse-workspace-swipe.service
log "Systemd service enabled and started."

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
log "Easy Swipe installed and started!"
echo ""
echo "  Gestures:"
echo "    Back + swipe right → next desktop (creates new one if on last)"
echo "    Back + swipe left  → previous desktop"
echo "    Back click (no swipe) → Overview (desktops & apps)"
echo ""
warn "If this is your first time, log out and back in for input group permissions."
echo "  Check logs: journalctl --user -u mouse-workspace-swipe -f"
