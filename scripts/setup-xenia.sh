#!/usr/bin/env bash
#
# setup-xenia.sh — Install & configure Xenia Canary (Xbox 360 emulator).
# Safe to run multiple times (re-run to update to the latest Canary build).
#
# Uses the official NATIVE Linux build of Xenia Canary — no Wine/Proton needed.
# Tuned for AMD RADV (Vulkan) but works on any Vulkan-capable GPU.
#
# Usage: bash scripts/setup-xenia.sh
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

REPO="xenia-canary/xenia-canary-releases"
INSTALL_DIR="${HOME}/Games/Xenia"
BIN_PATH="${INSTALL_DIR}/xenia_canary"
CONFIG_FILE="${INSTALL_DIR}/xenia-canary.config.toml"
LAUNCHER="${HOME}/.local/bin/xenia"
DESKTOP_FILE="${HOME}/.local/share/applications/xenia-canary.desktop"

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────┐"
echo "  │          Xenia Canary Setup               │"
echo "  │     Xbox 360 Emulator (native Linux)      │"
echo "  │            CachyOS / Arch                  │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Dependencies ────────────────────────────────────────────────────────────
# Native build needs: a Vulkan loader/driver + SDL2 (input/window) + fetch tools.

info "Installing runtime dependencies..."
sudo pacman -S --needed --noconfirm \
    vulkan-icd-loader \
    vulkan-radeon \
    curl \
    jq \
    tar \
    xz
log "Core dependencies present."

# SDL2: Xenia links libSDL2-2.0.so. Either 'sdl2' or 'sdl2-compat' provides it
# (they conflict with each other), so only install one if neither is present.
if ldconfig -p 2>/dev/null | grep -q 'libSDL2-2.0.so'; then
    log "SDL2 runtime already provided ($(pacman -Qq sdl2 sdl2-compat 2>/dev/null | tr '\n' ' '))."
else
    info "Installing an SDL2 provider..."
    sudo pacman -S --needed --noconfirm sdl2-compat || sudo pacman -S --needed --noconfirm sdl2
    log "SDL2 installed."
fi

# Sanity check: is Vulkan actually working?
if command -v vulkaninfo &>/dev/null; then
    if vulkaninfo --summary 2>/dev/null | grep -q deviceName; then
        GPU=$(vulkaninfo --summary 2>/dev/null | grep -m1 deviceName | sed 's/.*= //')
        log "Vulkan OK → ${GPU}"
    else
        warn "vulkaninfo found no Vulkan device — Xenia may not render. Check your GPU drivers."
    fi
fi

# ─── Download latest native Linux Canary build ───────────────────────────────

info "Querying latest Xenia Canary release from GitHub..."
ASSET_URL=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
    | jq -r '.assets[] | select(.name | test("linux.*\\.tar")) | .browser_download_url' \
    | head -1)
TAG=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r '.tag_name')

if [ -z "${ASSET_URL}" ] || [ "${ASSET_URL}" = "null" ]; then
    err "Could not find a native Linux asset in the latest release."
    err "Download manually from: https://github.com/${REPO}/releases/latest"
    exit 1
fi

log "Latest build: ${TAG}"
info "Downloading ${ASSET_URL##*/} ..."
mkdir -p "${INSTALL_DIR}"
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT
curl -L --progress-bar -o "${TMP}/xenia.tar.xz" "${ASSET_URL}"

info "Extracting..."
tar -xf "${TMP}/xenia.tar.xz" -C "${TMP}"
# Binary lives at build/bin/Linux/Release/xenia_canary inside the archive.
SRC_BIN=$(find "${TMP}" -type f -name 'xenia_canary' | head -1)
if [ -z "${SRC_BIN}" ]; then
    err "xenia_canary binary not found in archive."
    exit 1
fi
install -m 755 "${SRC_BIN}" "${BIN_PATH}"
# Copy license if present.
find "${TMP}" -maxdepth 2 -iname 'LICENSE*' -exec cp {} "${INSTALL_DIR}/" \; 2>/dev/null || true
log "Installed to ${BIN_PATH}"

# Portable mode: keep config + save data next to the binary (self-contained).
touch "${INSTALL_DIR}/portable.txt"

# ─── Config ──────────────────────────────────────────────────────────────────
# Only write a config if none exists yet — never clobber user tweaks on re-run.
# Xenia merges/fills missing defaults on first launch; we set the important bits.

if [ ! -f "${CONFIG_FILE}" ]; then
    info "Writing recommended default config..."
    cat > "${CONFIG_FILE}" <<'TOML'
[CPU]
break_on_unimplemented_instructions = false

[Content]
license_mask = -1              # unlock all DLC/licenses (needed by many games)

[Display]
fullscreen = false             # set true once you're happy; F11 toggles in-game
postprocess_antialiasing = "fxaa"

[GPU]
gpu = "vulkan"                 # RADV/AMD path — best on your RX 9070 XT
render_target_path_vulkan = ""
vsync = true
gpu_allow_invalid_fetch_constants = true

[General]
allow_plugins = false
apply_patches = true          # enable community game patches (Canary feature)
discord = false

[HID]
hid = "sdl"                   # SDL gamepad backend (Xbox/DS4/8BitDo all work)

[Storage]
mount_cache = false
TOML
    log "Config written → ${CONFIG_FILE}"
else
    info "Existing config kept (not overwritten): ${CONFIG_FILE}"
fi

# ─── Launcher command + desktop entry ────────────────────────────────────────

mkdir -p "$(dirname "${LAUNCHER}")"
cat > "${LAUNCHER}" <<EOF
#!/usr/bin/env bash
# Convenience launcher: 'xenia [/path/to/game.iso|.xex|.zar]'
exec "${BIN_PATH}" "\$@"
EOF
chmod +x "${LAUNCHER}"
log "Launcher command installed → ${LAUNCHER}  (run: xenia)"

if ! echo "${PATH}" | grep -q "${HOME}/.local/bin"; then
    warn "~/.local/bin is not on your PATH — add this to ~/.zshrc:"
    warn "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

mkdir -p "$(dirname "${DESKTOP_FILE}")"
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=Xenia Canary
Comment=Xbox 360 Emulator
Exec=${BIN_PATH} %f
Path=${INSTALL_DIR}
Terminal=false
Categories=Game;Emulator;
MimeType=application/x-iso9660-image;
EOF
update-desktop-database "$(dirname "${DESKTOP_FILE}")" &>/dev/null || true
log "App-menu entry created (search 'Xenia')."

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
log "Xenia Canary setup complete!"
echo ""
info "How to play Lost Odyssey:"
info "  • Dump your disc to an ISO/ZAR (4 discs → keep as 4 files), OR use the"
info "    extracted game folder containing the 'default.xex'."
info "  • Launch:  xenia '/path/to/Lost Odyssey Disc 1.iso'"
info "    …or just run 'xenia', then File → Open and pick the game."
info "  • Multi-disc: finish a disc, then File → Open the next disc's image."
echo ""
info "Handy in-game keys:  F11 = fullscreen   ~/tilde = console"
info "Config to tweak later:  ${CONFIG_FILE}"
warn "Lost Odyssey runs but isn't flawless — expect minor glitches. If graphics"
warn "look wrong, the config already uses the Vulkan renderer (best for AMD)."
echo ""
