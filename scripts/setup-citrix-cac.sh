#!/usr/bin/env bash
#
# Setup Citrix Workspace with CAC smart card passthrough for DoD VDI on CachyOS.
# Installs icaclient from AUR, links system/DoD certificates, and configures
# smart card redirection.
#
# Prerequisites: Run setup-cac.sh first to install smart card middleware and DoD certs.
#
# Run with: bash scripts/setup-citrix-cac.sh
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
err()  { echo -e "${RED}[✗]${NC} $*"; }

ICAROOT="/opt/Citrix/ICAClient"
CITRIX_CERTS="$ICAROOT/keystore/cacerts"
DOD_CERTS_DIR="$HOME/.dod-certs"
DOD_CERTS_URL="https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_DoD.zip"
PKCS11_LIB="/usr/lib/pkcs11/opensc-pkcs11.so"

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │   Citrix Workspace + CAC Setup for VDI   │"
echo "  │             CachyOS / Arch                │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Preflight checks ───────────────────────────────────────────────────────

if [[ $EUID -eq 0 ]]; then
    err "Do not run this script as root. It will prompt for sudo when needed."
    exit 1
fi

# Check that smart card middleware is already set up
if ! command -v pcsc_scan &>/dev/null; then
    err "pcsc-tools not found. Run setup-cac.sh first to install smart card middleware."
    exit 1
fi

# Detect AUR helper
AUR_HELPER=""
for helper in paru yay; do
    if command -v "$helper" &>/dev/null; then
        AUR_HELPER="$helper"
        break
    fi
done

if [[ -z "$AUR_HELPER" ]]; then
    err "No AUR helper found (paru or yay). Install one first."
    exit 1
fi

info "Using AUR helper: $AUR_HELPER"

# ─── Step 1: Install Citrix Workspace (icaclient) from AUR ──────────────────

info "Installing Citrix Workspace dependencies..."
sudo pacman -S --needed --noconfirm \
    opensc ccid pcsclite libusb \
    webkit2gtk-4.1 libsecret libsoup3 \
    gstreamer gst-plugins-base-libs \
    alsa-lib curl libvorbis speex

# gdk-pixbuf2 glycin breakage: the glycin-backed version breaks Citrix StoreBrowser.
# Install the noglycin variant if available.
if $AUR_HELPER -Si gdk-pixbuf2-noglycin &>/dev/null 2>&1; then
    info "Installing gdk-pixbuf2-noglycin to avoid Citrix StoreBrowser crash..."
    $AUR_HELPER -S --needed gdk-pixbuf2-noglycin
    log "gdk-pixbuf2-noglycin installed."
else
    warn "gdk-pixbuf2-noglycin not found in AUR — if Citrix StoreBrowser crashes,"
    warn "install it manually or downgrade gdk-pixbuf2 to 2.42.x."
fi

info "Installing icaclient from AUR (you may need to download the tarball manually)..."
warn "If the build fails, download the Citrix Workspace tarball from:"
warn "  https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"
warn "and place it in the AUR build directory shown in the error."
echo ""

$AUR_HELPER -S --needed icaclient

log "Citrix Workspace installed."

# ─── Step 2: Link system CA certificates into Citrix keystore ────────────────

info "Linking system CA certificates into Citrix keystore..."

if [[ ! -d "$CITRIX_CERTS" ]]; then
    sudo mkdir -p "$CITRIX_CERTS"
fi

# Link Mozilla/system root CAs
if [[ -d /usr/share/ca-certificates/mozilla ]]; then
    sudo ln -sf /usr/share/ca-certificates/mozilla/* "$CITRIX_CERTS/" 2>/dev/null || true
    log "Linked Mozilla CA certificates."
elif [[ -d /etc/ssl/certs ]]; then
    sudo ln -sf /etc/ssl/certs/*.pem "$CITRIX_CERTS/" 2>/dev/null || true
    log "Linked system SSL certificates."
fi

# ─── Step 3: Download and import DoD certificates into Citrix ────────────────

info "Importing DoD root certificates into Citrix keystore..."

mkdir -p "$DOD_CERTS_DIR"
ZIPFILE="$DOD_CERTS_DIR/dod-certs.zip"

# Download if not already present (setup-cac.sh may have already grabbed this)
if [[ ! -f "$ZIPFILE" ]]; then
    wget -q --show-progress -O "$ZIPFILE" "$DOD_CERTS_URL" || {
        warn "Auto-download failed. Manually download DoD certs from:"
        warn "  https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/"
        warn "Place them in: $DOD_CERTS_DIR"
    }
fi

if [[ -f "$ZIPFILE" ]]; then
    unzip -o -q "$ZIPFILE" -d "$DOD_CERTS_DIR"
fi

# Convert PKCS#7 bundles to individual PEM certs and copy into Citrix keystore
DOD_PEM_DIR="$DOD_CERTS_DIR/citrix-pem"
mkdir -p "$DOD_PEM_DIR"

IMPORTED=0
while IFS= read -r -d '' p7bfile; do
    basename_noext=$(basename "$p7bfile")
    basename_noext="${basename_noext%%.*}"
    outpem="$DOD_PEM_DIR/${basename_noext}.pem"

    if openssl pkcs7 -inform DER -in "$p7bfile" -print_certs -out "$outpem" 2>/dev/null || \
       openssl pkcs7 -inform PEM -in "$p7bfile" -print_certs -out "$outpem" 2>/dev/null; then
        sudo cp "$outpem" "$CITRIX_CERTS/"
        ((IMPORTED++))
    fi
done < <(find "$DOD_CERTS_DIR" -type f \( -iname "*.p7b" -o -iname "*.sst" \) -print0)

# Also copy any loose .cer/.crt/.pem files
while IFS= read -r -d '' certfile; do
    sudo cp "$certfile" "$CITRIX_CERTS/"
    ((IMPORTED++))
done < <(find "$DOD_CERTS_DIR" -maxdepth 2 -type f \( -iname "*.cer" -o -iname "*.crt" -o -iname "*.pem" -o -iname "*.der" \) ! -path "*/citrix-pem/*" -print0)

# Rehash the Citrix certificate store
if [[ -x "$ICAROOT/util/ctx_rehash" ]]; then
    sudo "$ICAROOT/util/ctx_rehash" 2>/dev/null || true
    log "Citrix certificate store rehashed ($IMPORTED cert files processed)."
else
    warn "ctx_rehash not found — certificates were copied but not rehashed."
fi

# ─── Step 4: Configure smart card passthrough ────────────────────────────────

info "Configuring Citrix Workspace for CAC smart card passthrough..."

# 4a: Set PKCS#11 module path in AuthManConfig.xml
AUTH_CONFIG="$ICAROOT/config/AuthManConfig.xml"
if [[ -f "$AUTH_CONFIG" ]]; then
    if grep -q "PKCS11module" "$AUTH_CONFIG"; then
        sudo sed -i "s|<value>.*</value>\(.*PKCS11module\)|<value>$PKCS11_LIB</value>\1|" "$AUTH_CONFIG" 2>/dev/null || true
        # More reliable: replace the value element after PKCS11module key
        sudo sed -i "/<key>PKCS11module<\/key>/{n;s|<value>.*</value>|<value>$PKCS11_LIB</value>|}" "$AUTH_CONFIG"
        log "Updated PKCS#11 module path in AuthManConfig.xml."
    else
        warn "PKCS11module key not found in AuthManConfig.xml — you may need to set it manually."
        warn "  File: $AUTH_CONFIG"
        warn "  Set:  <key>PKCS11module</key> <value>$PKCS11_LIB</value>"
    fi
else
    warn "AuthManConfig.xml not found at $AUTH_CONFIG"
fi

# 4b: Enable smart card cryptographic redirection in module.ini
MODULE_INI="$ICAROOT/config/module.ini"
if [[ -f "$MODULE_INI" ]]; then
    if grep -q "\[SmartCard\]" "$MODULE_INI"; then
        if ! grep -q "SmartCardCryptographicRedirection" "$MODULE_INI"; then
            sudo sed -i '/\[SmartCard\]/a SmartCardCryptographicRedirection=On' "$MODULE_INI"
            log "Enabled SmartCardCryptographicRedirection in module.ini."
        else
            log "SmartCardCryptographicRedirection already set."
        fi
    else
        # Add the section
        printf '\n[SmartCard]\nSmartCardCryptographicRedirection=On\n' | sudo tee -a "$MODULE_INI" > /dev/null
        log "Added [SmartCard] section with cryptographic redirection to module.ini."
    fi
else
    warn "module.ini not found at $MODULE_INI"
fi

# 4c: Ensure pcscd is running
if ! systemctl is-active --quiet pcscd.service && ! systemctl is-active --quiet pcscd.socket; then
    info "Starting pcscd..."
    sudo systemctl enable pcscd.socket --now
    sudo systemctl restart pcscd.service
fi

# ─── Step 5: Verify setup ───────────────────────────────────────────────────

echo ""
info "Verifying setup..."
echo ""

echo -e "${CYAN}── Citrix Workspace ──${NC}"
if [[ -x "$ICAROOT/wfica" ]]; then
    log "Citrix ICA client found at $ICAROOT/wfica"
else
    err "wfica binary not found — Citrix may not be installed correctly."
fi

echo -e "${CYAN}── Certificate store ──${NC}"
CERT_COUNT=$(find "$CITRIX_CERTS" -type f -o -type l 2>/dev/null | wc -l)
log "$CERT_COUNT certificates/links in Citrix keystore."

echo -e "${CYAN}── Smart card ──${NC}"
if systemctl is-active --quiet pcscd.service || systemctl is-active --quiet pcscd.socket; then
    log "pcscd is running."
else
    warn "pcscd is not running."
fi

if [[ -f "$PKCS11_LIB" ]]; then
    log "OpenSC PKCS#11 module found at $PKCS11_LIB"
else
    warn "OpenSC PKCS#11 module not found at $PKCS11_LIB"
fi

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}  ┌──────────────────────────────────────────┐${NC}"
echo -e "${GREEN}  │     Citrix Workspace + CAC Complete!      │${NC}"
echo -e "${GREEN}  └──────────────────────────────────────────┘${NC}"
echo ""
echo "  Next steps:"
echo "    1. Insert your CAC into the reader"
echo "    2. Open Citrix Workspace or navigate to your VDI portal in Chrome"
echo "    3. You should be prompted for your CAC PIN"
echo ""
echo "  Troubleshooting:"
echo "    - Test reader:       pcsc_scan"
echo "    - Check pcscd:       systemctl status pcscd"
echo "    - Check slots:       pkcs11-tool --list-slots"
echo "    - Citrix logs:       ~/.ICAClient/logs/"
echo "    - Cert store:        ls $CITRIX_CERTS"
echo "    - Rehash certs:      sudo $ICAROOT/util/ctx_rehash"
echo "    - PKCS#11 config:    cat $ICAROOT/config/AuthManConfig.xml"
echo "    - Smart card config: cat $ICAROOT/config/module.ini"
echo "    - SSL error 61:      Missing CA cert — check $CITRIX_CERTS"
echo ""
