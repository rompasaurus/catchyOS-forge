#!/usr/bin/env bash
#
# Mount SMB shares from \\dookintel via /etc/fstab.
# Run with: bash scripts/setup-smb.sh
#
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │    SMB Share Mount Setup (dookintel)      │"
echo "  │           CachyOS / Arch                  │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

SMB_HOST="dookintel"
MOUNT_BASE="/mnt/dookintel"
CRED_FILE="$HOME/.smbcredentials"

SHARES=(
    "Bertha"
    "Movies"
    "Movies 2"
    "Steam"
    "Steam Library"
    "TV Shows"
    "TV Shows 2"
    "TV Shows 3"
    "TV Shows 4"
)

# ─── Install cifs-utils ─────────────────────────────────────────────────────

if pacman -Qi cifs-utils &>/dev/null; then
    log "cifs-utils already installed"
else
    info "Installing cifs-utils..."
    sudo pacman -S --needed --noconfirm cifs-utils
    log "cifs-utils installed."
fi

# ─── Credentials file ───────────────────────────────────────────────────────

if [ -f "$CRED_FILE" ] && [ "${1:-}" != "--reconfigure" ]; then
    log "Credentials file already exists at $CRED_FILE (use --reconfigure to update)"
else
    info "Creating SMB credentials file..."
    read -rp "SMB username for \\\\$SMB_HOST: " smb_user
    read -rsp "SMB password: " smb_pass
    echo ""

    cat > "$CRED_FILE" <<EOF
username=$smb_user
password=$smb_pass
EOF
    chmod 600 "$CRED_FILE"
    log "Credentials saved to $CRED_FILE (mode 600)"
fi

# ─── Mount points & fstab entries ────────────────────────────────────────────

info "Setting up mount points and fstab entries..."

for share in "${SHARES[@]}"; do
    mount_point="$MOUNT_BASE/$share"

    # Create mount point directory
    if [ -d "$mount_point" ]; then
        info "Mount point already exists: $mount_point"
    else
        sudo mkdir -p "$mount_point"
        log "Created mount point: $mount_point"
    fi

    # Escape spaces as \040 for fstab
    fstab_source="//$SMB_HOST/${share// /\\040}"
    fstab_mount="${mount_point// /\\040}"
    fstab_entry="$fstab_source $fstab_mount cifs credentials=$CRED_FILE,vers=3.0,sec=ntlmv2,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev 0 0"

    # Add or update fstab entry
    if grep -qF "$fstab_source " /etc/fstab; then
        # Replace existing entry with current options
        sudo sed -i "\|^${fstab_source} |c\\${fstab_entry}" /etc/fstab
        log "Updated fstab entry for $share"
    else
        echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
        log "Added fstab entry for $share"
    fi
done

# ─── Mount everything ───────────────────────────────────────────────────────

info "Reloading systemd and mounting all shares..."
sudo systemctl daemon-reload
sudo mount -a
log "mount -a complete."

# ─── Verify ─────────────────────────────────────────────────────────────────

echo ""
info "Verification:"
for share in "${SHARES[@]}"; do
    mount_point="$MOUNT_BASE/$share"
    if mountpoint -q "$mount_point" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $share → $mount_point"
    else
        echo -e "  ${YELLOW}✗${NC} $share — not mounted (server may be unreachable)"
    fi
done

echo ""
log "Done! Shares will auto-mount on reboot via fstab."
