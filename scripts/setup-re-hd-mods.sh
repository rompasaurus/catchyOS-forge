#!/usr/bin/env bash
#
# Resident Evil HD Remaster — Proton GE + BhdTool Mod Setup
#
# Sets up:
#   1. GE-Proton (latest) for better compatibility on Linux
#   2. BhdTool — in-game tool with save anywhere, door skip, room jump
#      Press F5 in-game to open the BhdTool menu
#
# Supports: RE HD Remaster (304240) and RE0 HD Remaster (339340)
#
# Run with: bash scripts/setup-re-hd-mods.sh
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
echo "  │   Resident Evil HD — Linux Mod Setup      │"
echo "  │   Proton GE + BhdTool                     │"
echo "  │          CachyOS / Arch                   │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Detect Steam library paths ─────────────────────────────────────────────

STEAM_ROOT=""
COMPAT_DIR=""

for candidate in \
    "$HOME/.steam/steam" \
    "$HOME/.local/share/Steam" \
    "$HOME/.var/app/com.valvesoftware.Steam/data/Steam" \
    "$HOME/snap/steam/common/.steam/steam"; do
    if [[ -d "$candidate" ]]; then
        STEAM_ROOT="$candidate"
        break
    fi
done

if [[ -z "$STEAM_ROOT" ]]; then
    err "Steam installation not found."
    exit 1
fi
log "Steam root: $STEAM_ROOT"

# Flatpak uses a different compat dir
if [[ "$STEAM_ROOT" == *"flatpak"* || "$STEAM_ROOT" == *"com.valvesoftware.Steam"* ]]; then
    COMPAT_DIR="$STEAM_ROOT/compatibilitytools.d"
else
    COMPAT_DIR="$HOME/.steam/steam/compatibilitytools.d"
fi

# ─── Find game directories across all Steam libraries ───────────────────────

RE1_DIR=""
RE0_DIR=""

find_game_dirs() {
    local lib_folders=("$STEAM_ROOT/steamapps")

    # Parse additional library folders from libraryfolders.vdf
    local vdf="$STEAM_ROOT/steamapps/libraryfolders.vdf"
    if [[ -f "$vdf" ]]; then
        while IFS= read -r line; do
            local path
            path=$(echo "$line" | grep -oP '"path"\s*"\K[^"]+' || true)
            if [[ -n "$path" && -d "$path/steamapps" ]]; then
                lib_folders+=("$path/steamapps")
            fi
        done < "$vdf"
    fi

    for lib in "${lib_folders[@]}"; do
        local common="$lib/common"
        [[ -d "$common" ]] || continue

        # RE HD Remaster
        if [[ -z "$RE1_DIR" ]]; then
            for d in "$common"/Resident\ Evil*HD\ REMASTER "$common"/Resident\ Evil*Biohazard*HD*; do
                if [[ -d "$d" ]]; then
                    RE1_DIR="$d"
                    break
                fi
            done
        fi

        # RE0 HD Remaster
        if [[ -z "$RE0_DIR" ]]; then
            for d in "$common"/Resident\ Evil\ 0* "$common"/Resident*Biohazard*0*; do
                if [[ -d "$d" ]]; then
                    RE0_DIR="$d"
                    break
                fi
            done
        fi
    done
}

find_game_dirs

if [[ -z "$RE1_DIR" && -z "$RE0_DIR" ]]; then
    err "No Resident Evil HD Remaster or RE0 HD Remaster found in Steam libraries."
    echo "  Install the game through Steam first, then re-run this script."
    exit 1
fi

[[ -n "$RE1_DIR" ]] && log "Found RE HD Remaster: $RE1_DIR"
[[ -n "$RE0_DIR" ]] && log "Found RE0 HD Remaster: $RE0_DIR"

# ─── 1. Install GE-Proton (latest) ──────────────────────────────────────────

info "Fetching latest GE-Proton release..."

GE_JSON=$(curl -fsSL "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest")
GE_TAG=$(echo "$GE_JSON" | grep -oP '"tag_name":\s*"\K[^"]+')
GE_URL=$(echo "$GE_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]+\.tar\.gz(?=")')
GE_SHA_URL=$(echo "$GE_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]+\.sha512sum(?=")')

if [[ -z "$GE_TAG" || -z "$GE_URL" ]]; then
    err "Failed to fetch GE-Proton release info."
    exit 1
fi

mkdir -p "$COMPAT_DIR"

if [[ -d "$COMPAT_DIR/$GE_TAG" ]]; then
    log "GE-Proton already installed: $GE_TAG"
else
    info "Downloading $GE_TAG (~500 MB)..."
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT

    curl -fSL --progress-bar -o "$TMPDIR/$GE_TAG.tar.gz" "$GE_URL"

    # Verify checksum if available
    if [[ -n "$GE_SHA_URL" ]]; then
        info "Verifying checksum..."
        curl -fsSL -o "$TMPDIR/$GE_TAG.sha512sum" "$GE_SHA_URL"
        (cd "$TMPDIR" && sha512sum -c "$GE_TAG.sha512sum") || {
            err "Checksum verification failed!"
            exit 1
        }
        log "Checksum verified."
    fi

    info "Extracting to $COMPAT_DIR..."
    tar -xf "$TMPDIR/$GE_TAG.tar.gz" -C "$COMPAT_DIR/"
    log "GE-Proton $GE_TAG installed."
fi

# ─── 2. Install BhdTool ───────────────────────────────────────────────────────
#
# BhdTool adds an in-game imgui overlay (F5) with:
#   - Save Anywhere (no ink ribbons / typewriter needed)
#   - Door Skip (auto-skips door opening animations)
#   - Room Jump (teleport to any room)
#
# Uses dinput8.dll + rooms.json. Works with Proton via WINEDLLOVERRIDES.
# Generates bhdtool.ini on first close for config (EnableBhdTool=0 to disable).
#
# Source: https://github.com/eleval/BhdTool

# Check for 7z (p7zip) — needed to extract BhdTool's .7z archive
if ! command -v 7z &>/dev/null; then
    err "7z (p7zip) is required to extract BhdTool."
    echo "  Install with: sudo pacman -S p7zip"
    exit 1
fi

info "Fetching latest BhdTool release..."

BHDTOOL_JSON=$(curl -fsSL "https://api.github.com/repos/eleval/BhdTool/releases/latest")
BHDTOOL_TAG=$(echo "$BHDTOOL_JSON" | grep -oP '"tag_name":\s*"\K[^"]+')
BHDTOOL_URL=$(echo "$BHDTOOL_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]+\.7z(?=")')

if [[ -z "$BHDTOOL_TAG" || -z "$BHDTOOL_URL" ]]; then
    err "Failed to fetch BhdTool release info."
    exit 1
fi

install_bhdtool() {
    local game_dir="$1"
    local game_name="$2"

    # Clean up old ThirteenAG Door Skip Plugin files (conflicts with BhdTool)
    if [[ -d "$game_dir/scripts" ]]; then
        warn "Removing old ThirteenAG Door Skip Plugin files for $game_name..."
        rm -rf "$game_dir/scripts"
        rm -f "$game_dir/dinput8.dll"
    fi

    if [[ -f "$game_dir/dinput8.dll" && -f "$game_dir/rooms.json" ]]; then
        log "BhdTool already installed for $game_name."
        return
    fi

    info "Installing BhdTool $BHDTOOL_TAG for $game_name..."

    local tmp_archive
    tmp_archive=$(mktemp /tmp/bhdtool-XXXXXX.7z)
    curl -fSL --progress-bar -o "$tmp_archive" "$BHDTOOL_URL"

    # Extract into game directory
    7z x -o"$game_dir" -y "$tmp_archive" > /dev/null 2>&1
    rm -f "$tmp_archive"

    if [[ -f "$game_dir/dinput8.dll" && -f "$game_dir/rooms.json" ]]; then
        log "BhdTool $BHDTOOL_TAG installed for $game_name."
    else
        err "BhdTool extraction failed for $game_name."
    fi
}

[[ -n "$RE1_DIR" ]] && install_bhdtool "$RE1_DIR" "RE HD Remaster"
[[ -n "$RE0_DIR" ]] && install_bhdtool "$RE0_DIR" "RE0 HD Remaster"

# ─── 3. Set Steam launch options ────────────────────────────────────────────
#
# Proton needs WINEDLLOVERRIDES to load the dinput8.dll wrapper.
# We can't set this programmatically via Steam's config reliably,
# so we print instructions.

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Manual Steps (do these in Steam):${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""
echo "  1. Restart Steam (required for GE-Proton to appear)"
echo ""
echo "  2. For each RE game → Right-click → Properties:"
echo ""
echo "     Compatibility tab:"
echo "       ☑ Force the use of a specific Steam Play compatibility tool"
echo "       Select: $GE_TAG"
echo ""
echo "     General tab → Launch Options:"
echo -e "       ${YELLOW}WINEDLLOVERRIDES=\"dinput8=n,b\" %command%${NC}"
echo ""
echo "  This tells Proton to load BhdTool's DLL as a native override."
echo "  Press F5 in-game to open the BhdTool menu."
echo "  Features: Save Anywhere, Door Skip, Room Jump."
echo ""

# ─── 4. Verify installation ─────────────────────────────────────────────────

echo -e "${CYAN}Verification:${NC}"

if [[ -d "$COMPAT_DIR/$GE_TAG" ]]; then
    echo -e "  ${GREEN}✓${NC} GE-Proton $GE_TAG installed"
else
    echo -e "  ${YELLOW}✗${NC} GE-Proton not found"
fi

if [[ -n "$RE1_DIR" ]]; then
    if [[ -f "$RE1_DIR/dinput8.dll" && -f "$RE1_DIR/rooms.json" ]]; then
        echo -e "  ${GREEN}✓${NC} BhdTool $BHDTOOL_TAG installed (RE HD Remaster)"
    else
        echo -e "  ${YELLOW}✗${NC} BhdTool missing (RE HD Remaster)"
    fi
fi

if [[ -n "$RE0_DIR" ]]; then
    if [[ -f "$RE0_DIR/dinput8.dll" && -f "$RE0_DIR/rooms.json" ]]; then
        echo -e "  ${GREEN}✓${NC} BhdTool $BHDTOOL_TAG installed (RE0 HD Remaster)"
    else
        echo -e "  ${YELLOW}✗${NC} BhdTool missing (RE0 HD Remaster)"
    fi
fi

echo ""
log "Setup complete! Restart Steam, set the options above, and enjoy."
echo ""
