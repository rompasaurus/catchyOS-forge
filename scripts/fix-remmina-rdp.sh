#!/usr/bin/env bash
# fix-remmina-rdp.sh — Fix Remmina RDP sessions on CachyOS.
#
# Symptoms this fixes:
#   * Missing toolbar / connection icons inside an RDP session
#   * Random freezing mid-session
#
# Cause: the native Arch/CachyOS combo (remmina 1.4.x + FreeRDP 3.x) regressed
# the RDP toolbar icons and introduced session freezes. The reliable cross-install
# fix is the Flathub build of Remmina, which bundles its own tested FreeRDP and a
# complete icon set, isolating Remmina from the system FreeRDP mismatch.
#
# Usage:  bash scripts/fix-remmina-rdp.sh
#
# Re-runnable: safe to run multiple times.

set -euo pipefail

log()  { echo -e "\e[32m[✓]\e[0m $*"; }
info() { echo -e "\e[34m[i]\e[0m $*"; }
warn() { echo -e "\e[33m[!]\e[0m $*"; }

APP_ID="org.remmina.Remmina"

echo "=== Remmina RDP fix (icons + freezing) ==="

# ── Step 1: install flatpak if missing ───────────────────────────────────────
if ! command -v flatpak >/dev/null 2>&1; then
    info "[1/5] flatpak not found — installing..."
    sudo pacman -S --needed --noconfirm flatpak
    warn "flatpak was just installed — you may need to log out/in once so the"
    warn "exported .desktop entries and PATH are picked up by your session."
else
    log "[1/5] flatpak present."
fi

# ── Step 2: ensure Flathub remote ────────────────────────────────────────────
info "[2/5] Ensuring Flathub remote is configured..."
flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo
log "Flathub remote ready."

# ── Step 3: remove the broken native Remmina (optional) ──────────────────────
if pacman -Q remmina >/dev/null 2>&1; then
    info "[3/5] Native 'remmina' package detected ($(pacman -Q remmina | awk '{print $2}'))."
    read -r -p "    Remove it so the Flatpak build takes over the .desktop entry? [Y/n] " ans
    ans=${ans:-Y}
    if [[ $ans =~ ^[Yy]$ ]]; then
        # -Rn keeps shared deps like system freerdp (other apps may use it).
        sudo pacman -Rn --noconfirm remmina remmina-plugin-rdp 2>/dev/null \
            || sudo pacman -Rn --noconfirm remmina
        log "Native Remmina removed."
    else
        warn "Keeping native Remmina — you'll have two entries; launch the Flatpak one."
    fi
else
    log "[3/5] No native Remmina installed — nothing to remove."
fi

# ── Step 4: install the Flatpak build ────────────────────────────────────────
info "[4/5] Installing Remmina from Flathub (bundles FreeRDP + icons)..."
flatpak install -y --noninteractive flathub "$APP_ID"
log "Flatpak Remmina installed."

# ── Step 5: grant the permissions an RDP client needs ────────────────────────
info "[5/6] Granting filesystem/clipboard access (drive redirect, shared folders)..."
flatpak override --user --filesystem=home "$APP_ID"          # shared folders / drive redirect
flatpak override --user --socket=session-bus "$APP_ID"       # clipboard, notifications
flatpak override --user --device=all "$APP_ID"               # smartcard / USB redirect
log "Permissions applied."

# ── Step 6: fix blank toolbar icons (KDE host theme not in sandbox) ───────────
# On KDE the host GTK icon theme is usually 'breeze-dark'. The sandbox reads that
# name from the host gtk settings but the theme itself isn't inside the runtime
# (only Adwaita + hicolor are), so Remmina's toolbar icons render as blank
# squares. NOTE: you cannot mount /usr/share/icons into a flatpak — Flatpak
# refuses all host /usr paths ("Path /usr is reserved"). The working fix is to
# copy the host icon theme(s) into ~/.local/share/icons, which the sandbox CAN
# read. breeze-dark inherits from breeze + hicolor, so copy both.
info "[6/6] Copying host icon theme into ~/.local/share/icons (fixes blank icons)..."
flatpak override --user --filesystem=xdg-data/icons:ro "$APP_ID"
ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" || true)
ICON_THEME=${ICON_THEME:-breeze-dark}
mkdir -p "$HOME/.local/share/icons"
for t in "$ICON_THEME" breeze breeze-dark hicolor; do
    if [[ -d "/usr/share/icons/$t" && ! -d "$HOME/.local/share/icons/$t" ]]; then
        cp -a "/usr/share/icons/$t" "$HOME/.local/share/icons/"
        gtk-update-icon-cache -q -f "$HOME/.local/share/icons/$t" 2>/dev/null || true
        info "  copied icon theme: $t"
    fi
done
log "Host icon themes copied into the sandbox-visible icons dir."

echo ""
log "Done. FULLY quit Remmina first (check the system tray → Quit), then launch:"
log "    flatpak run $APP_ID"
info "Your saved profiles in ~/.local/share/remmina and ~/.config/remmina are reused as-is."
warn "If both a native and Flatpak entry show in your launcher, pin the Flatpak one."
