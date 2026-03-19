#!/usr/bin/env bash
#
# Setup CAC (Common Access Card) smart card authentication for Chrome on CachyOS.
# Installs middleware, configures PKCS#11 module, and imports DoD root certificates.
#
# Translated from dubuntu-forge (Ubuntu/apt) to CachyOS (Arch/pacman).
#
# Run with: bash scripts/setup-cac.sh
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

NSSDB="sql:$HOME/.pki/nssdb"
CAC_MODULE_NAME="CAC Module"
DOD_CERTS_DIR="$HOME/.dod-certs"
DOD_CERTS_URL="https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_DoD.zip"

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │     CAC Smart Card Setup for Chrome       │"
echo "  │            CachyOS / Arch                 │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Preflight checks ───────────────────────────────────────────────────────

if [[ $EUID -eq 0 ]]; then
    err "Do not run this script as root. It will prompt for sudo when needed."
    exit 1
fi

# ─── Step 1: Install required packages ───────────────────────────────────────

info "Installing smart card packages (will prompt for sudo password)..."
sudo pacman -S --needed --noconfirm \
    opensc ccid pcsc-tools pcsclite libusb nss unzip wget

# coolkey equivalent on Arch — opensc handles most CAC cards
# libnss3-tools equivalent is 'nss' which provides certutil and modutil
# pcsc-lite provides the pcscd daemon; libusb is needed for USB reader access

log "Smart card packages installed."

# ─── Step 1b: Install udev rules for USB smart card readers ──────────────────

UDEV_RULE="/etc/udev/rules.d/92-smart-card-reader.rules"
info "Installing udev rules for USB smart card reader access..."

# Grant plugdev/scard group access; fall back to TAG+="uaccess" so the
# logged-in seat user can always open the device (works with systemd-logind).
sudo tee "$UDEV_RULE" > /dev/null << 'UDEVRULES'
# ── Smart card / CAC reader permissions ──────────────────────────
# Allow the logged-in user (via systemd seat) to access USB CCID readers.
# Class 0x0b = Smart Card device class (covers most readers).
# Specific readers that sometimes use vendor class are listed by VID:PID.

# Generic: any USB device with Smart Card interface class
SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="0b", TAG+="uaccess"

# HID Global / OmniKey readers (common CAC readers)
SUBSYSTEM=="usb", ATTR{idVendor}=="076b", TAG+="uaccess"

# Identiv / SCM Microsystems
SUBSYSTEM=="usb", ATTR{idVendor}=="04e6", TAG+="uaccess"

# Gemalto / Thales
SUBSYSTEM=="usb", ATTR{idVendor}=="08e6", TAG+="uaccess"

# Cherry GmbH
SUBSYSTEM=="usb", ATTR{idVendor}=="046a", TAG+="uaccess"

# Alcor Micro (built-in laptop readers)
SUBSYSTEM=="usb", ATTR{idVendor}=="058f", TAG+="uaccess"

# Yubico YubiKey (also acts as a CCID smart card)
SUBSYSTEM=="usb", ATTR{idVendor}=="1050", TAG+="uaccess"
UDEVRULES

sudo udevadm control --reload-rules
sudo udevadm trigger
log "Udev rules installed and reloaded."

# ─── Step 2: Enable and start pcscd ─────────────────────────────────────────

info "Enabling and starting pcscd (smart card daemon)..."
sudo systemctl enable pcscd.socket --now
# Restart pcscd so it picks up the new udev permissions
sudo systemctl restart pcscd.service
sudo systemctl enable pcscd.service --now
log "pcscd is running."

# ─── Step 3: Detect the PKCS#11 library path ────────────────────────────────

info "Locating opensc-pkcs11.so..."
PKCS11_LIB=$(find /usr/lib -name "opensc-pkcs11.so" 2>/dev/null | head -n 1)

if [[ -z "$PKCS11_LIB" ]]; then
    err "Could not find opensc-pkcs11.so. Is opensc installed?"
    exit 1
fi

log "Found PKCS#11 module at: $PKCS11_LIB"

# ─── Step 4: Initialize NSS database ────────────────────────────────────────

info "Ensuring NSS database exists at ~/.pki/nssdb..."
mkdir -p "$HOME/.pki/nssdb"

if [[ ! -f "$HOME/.pki/nssdb/cert9.db" ]]; then
    certutil -d "$NSSDB" -N --empty-password
    log "Created new NSS database."
else
    log "NSS database already exists."
fi

# ─── Step 5: Register PKCS#11 module with NSS ───────────────────────────────

info "Registering CAC PKCS#11 module with Chrome's NSS database..."

if modutil -dbdir "$NSSDB" -list 2>/dev/null | grep -q "$CAC_MODULE_NAME"; then
    warn "CAC module already registered — skipping."
else
    modutil -dbdir "$NSSDB" -add "$CAC_MODULE_NAME" -libfile "$PKCS11_LIB" -force
    log "CAC module registered."
fi

# ─── Step 6: Download and import DoD root certificates ──────────────────────

info "Downloading DoD root certificates from DISA..."
mkdir -p "$DOD_CERTS_DIR"
ZIPFILE="$DOD_CERTS_DIR/dod-certs.zip"

wget -q --show-progress -O "$ZIPFILE" "$DOD_CERTS_URL" || {
    warn "Auto-download failed. Trying alternative approach..."
    warn "If this also fails, manually download DoD certs from:"
    warn "  https://militarycac.com/dodcerts.htm"
    warn "  or https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/"
    warn "Place .cer/.crt files in: $DOD_CERTS_DIR"
    warn "Then re-run this script."
}

if [[ -f "$ZIPFILE" ]]; then
    info "Extracting certificates..."
    unzip -o -q "$ZIPFILE" -d "$DOD_CERTS_DIR"
    log "Certificates extracted to $DOD_CERTS_DIR"
fi

info "Importing DoD CA certificates into NSS database..."
IMPORTED=0
SKIPPED=0
FAILED=0

# Find all cert files (DER and PEM) recursively
while IFS= read -r -d '' certfile; do
    certname=$(basename "$certfile" | sed 's/\.\(cer\|crt\|pem\|der\)$//')

    # Check if already imported
    if certutil -d "$NSSDB" -L 2>/dev/null | grep -q "$certname"; then
        ((SKIPPED++))
        continue
    fi

    # Try DER format first, then PEM
    if certutil -d "$NSSDB" -A -t "CT,CT,CT" -n "$certname" -i "$certfile" 2>/dev/null; then
        ((IMPORTED++))
    elif certutil -d "$NSSDB" -A -t "CT,CT,CT" -n "$certname" -i "$certfile" -a 2>/dev/null; then
        ((IMPORTED++))
    else
        ((FAILED++))
    fi
done < <(find "$DOD_CERTS_DIR" -type f \( -iname "*.cer" -o -iname "*.crt" -o -iname "*.pem" -o -iname "*.der" \) -print0)

# Also handle PKCS#7 bundles (.p7b / .sst) — extract individual certs
while IFS= read -r -d '' p7bfile; do
    p7b_dir="$DOD_CERTS_DIR/extracted_$(basename "$p7bfile" .p7b)"
    mkdir -p "$p7b_dir"

    # Convert PKCS#7 to individual PEM certs
    if openssl pkcs7 -inform DER -in "$p7bfile" -print_certs -out "$p7b_dir/bundle.pem" 2>/dev/null || \
       openssl pkcs7 -inform PEM -in "$p7bfile" -print_certs -out "$p7b_dir/bundle.pem" 2>/dev/null; then

        # Split the PEM bundle into individual certs
        csplit -z -f "$p7b_dir/cert-" -b "%03d.pem" "$p7b_dir/bundle.pem" \
            '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null || true

        for splitcert in "$p7b_dir"/cert-*.pem; do
            [[ -f "$splitcert" ]] || continue
            # Extract CN for the nickname
            cn=$(openssl x509 -in "$splitcert" -noout -subject 2>/dev/null | sed -n 's/.*CN\s*=\s*//p' | head -1)
            cn="${cn:-$(basename "$splitcert" .pem)}"

            if certutil -d "$NSSDB" -L 2>/dev/null | grep -q "$cn"; then
                ((SKIPPED++))
                continue
            fi

            if certutil -d "$NSSDB" -A -t "CT,CT,CT" -n "$cn" -i "$splitcert" -a 2>/dev/null; then
                ((IMPORTED++))
            else
                ((FAILED++))
            fi
        done
    fi
done < <(find "$DOD_CERTS_DIR" -type f \( -iname "*.p7b" -o -iname "*.sst" \) -print0)

log "Certificate import complete: $IMPORTED imported, $SKIPPED skipped (already present), $FAILED failed."

# ─── Step 7: Verify setup ───────────────────────────────────────────────────

echo ""
info "Verifying setup..."
echo ""

echo -e "${CYAN}── Registered PKCS#11 modules ──${NC}"
modutil -dbdir "$NSSDB" -list 2>/dev/null | head -20
echo ""

echo -e "${CYAN}── Imported certificates (first 20) ──${NC}"
certutil -d "$NSSDB" -L 2>/dev/null | head -20
echo ""

echo -e "${CYAN}── Smart card reader status ──${NC}"
if command -v pcsc_scan &>/dev/null; then
    timeout 5 pcsc_scan 2>/dev/null | head -15 || warn "No card reader detected. Plug in your CAC reader and try: pcsc_scan"
fi

# Check for USB access errors in pcscd journal
if journalctl -u pcscd.service --no-pager -n 20 2>/dev/null | grep -q "LIBUSB_ERROR_ACCESS"; then
    warn "pcscd still reports LIBUSB_ERROR_ACCESS — try unplugging and re-plugging the reader,"
    warn "or reboot to fully apply the new udev rules."
fi

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}  ┌──────────────────────────────────────────┐${NC}"
echo -e "${GREEN}  │           CAC Setup Complete!             │${NC}"
echo -e "${GREEN}  └──────────────────────────────────────────┘${NC}"
echo ""
echo "  Next steps:"
echo "    1. Fully quit Chrome (check: pkill chrome)"
echo "    2. Insert your CAC into the reader"
echo "    3. Open Chrome and navigate to https://webmail.apps.mil/mail/"
echo "    4. You should see the certificate selection popup"
echo ""
echo "  Troubleshooting:"
echo "    - Verify module:  modutil -dbdir $NSSDB -list"
echo "    - List certs:     certutil -d $NSSDB -L"
echo "    - Test reader:    pcsc_scan"
echo "    - Check slots:    pkcs11-tool --list-slots"
echo "    - Check daemon:   systemctl status pcscd"
echo "    - USB access:     journalctl -u pcscd -n 20 (look for LIBUSB_ERROR_ACCESS)"
echo "    - Udev rules:     cat /etc/udev/rules.d/92-smart-card-reader.rules"
echo "    - Re-plug reader or reboot if USB permissions don't take effect"
echo ""
