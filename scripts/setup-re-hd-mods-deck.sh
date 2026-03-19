#!/usr/bin/env bash
#
# Resident Evil HD Remaster — Proton GE + BhdTool Mod Setup (Steam Deck)
#
# Steam Deck variant of setup-re-hd-mods.sh
#
# Differences from the desktop version:
#   - Steam Deck default paths (/home/deck, internal + SD card)
#   - Handles read-only filesystem (SteamOS immutable rootfs)
#   - Works in both Game Mode and Desktop Mode
#   - Detects microSD card Steam libraries automatically
#
# Sets up:
#   1. GE-Proton (latest) for better compatibility
#   2. BhdTool — in-game tool with save anywhere, door skip, room jump
#      Press F5 in-game to open the BhdTool menu
#
# Supports: RE HD Remaster (304240) and RE0 HD Remaster (339340)
#
# Run with: bash scripts/setup-re-hd-mods-deck.sh
#   or copy to Deck and run from Konsole in Desktop Mode
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
echo "  │   Resident Evil HD — Mod Setup            │"
echo "  │   Proton GE + BhdTool                     │"
echo "  │          Steam Deck Edition                │"
echo "  └──────────────────────────────────────────┘"
echo -e "${NC}"

# ─── Detect if running on Steam Deck ─────────────────────────────────────────

IS_DECK=false
if [[ -f /etc/os-release ]] && grep -qi "steamos" /etc/os-release; then
    IS_DECK=true
    log "Detected SteamOS (Steam Deck)"
elif [[ -d "/home/deck" ]]; then
    IS_DECK=true
    log "Detected Steam Deck home directory"
fi

if [[ "$IS_DECK" != true ]]; then
    warn "This script is designed for Steam Deck."
    warn "For desktop Linux, use setup-re-hd-mods.sh instead."
    read -rp "Continue anyway? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 0
fi

# ─── Check dependencies ──────────────────────────────────────────────────────

for cmd in curl tar 7z; do
    if ! command -v "$cmd" &>/dev/null; then
        err "Missing required command: $cmd"
        if [[ "$IS_DECK" == true ]]; then
            echo "  SteamOS should have this by default. Try rebooting into Desktop Mode."
        fi
        exit 1
    fi
done

# ─── Detect Steam library paths (Deck-specific) ──────────────────────────────

STEAM_ROOT=""
COMPAT_DIR=""
DECK_USER="${DECK_USER:-deck}"

# Steam Deck paths — internal storage and Flatpak variants
for candidate in \
    "/home/$DECK_USER/.steam/steam" \
    "/home/$DECK_USER/.local/share/Steam" \
    "$HOME/.steam/steam" \
    "$HOME/.local/share/Steam"; do
    if [[ -d "$candidate" ]]; then
        STEAM_ROOT="$candidate"
        break
    fi
done

if [[ -z "$STEAM_ROOT" ]]; then
    err "Steam installation not found."
    echo "  Expected at /home/$DECK_USER/.steam/steam"
    exit 1
fi
log "Steam root: $STEAM_ROOT"

# Compat tools dir — standard location on Deck
COMPAT_DIR="$STEAM_ROOT/compatibilitytools.d"

# ─── Find game directories across all Steam libraries ────────────────────────
# Includes internal storage AND microSD card (typically /run/media/mmcblk0p1)

RE1_DIR=""
RE0_DIR=""

find_game_dirs() {
    local lib_folders=("$STEAM_ROOT/steamapps")

    # Parse additional library folders from libraryfolders.vdf
    # This picks up microSD card libraries automatically
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

    # Also check common SD card mount points directly
    for sdcard in /run/media/mmcblk0p1 /run/media/deck/*; do
        if [[ -d "$sdcard/steamapps" ]]; then
            local already=false
            for existing in "${lib_folders[@]}"; do
                [[ "$existing" == "$sdcard/steamapps" ]] && already=true && break
            done
            [[ "$already" == false ]] && lib_folders+=("$sdcard/steamapps")
        fi
    done

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
    echo "  Checked internal storage and microSD card."
    exit 1
fi

[[ -n "$RE1_DIR" ]] && log "Found RE HD Remaster: $RE1_DIR"
[[ -n "$RE0_DIR" ]] && log "Found RE0 HD Remaster: $RE0_DIR"

# ─── 1. Install GE-Proton (latest) ───────────────────────────────────────────

info "Fetching latest GE-Proton release..."

GE_JSON=$(curl -fsSL "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest")
GE_TAG=$(echo "$GE_JSON" | grep -oP '"tag_name":\s*"\K[^"]+')
GE_URL=$(echo "$GE_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]+\.tar\.gz(?=")')
GE_SHA_URL=$(echo "$GE_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]+\.sha512sum(?=")')

if [[ -z "$GE_TAG" || -z "$GE_URL" ]]; then
    err "Failed to fetch GE-Proton release info."
    echo "  Make sure you have internet access (connect via Wi-Fi or Ethernet adapter)."
    exit 1
fi

mkdir -p "$COMPAT_DIR"

if [[ -d "$COMPAT_DIR/$GE_TAG" ]]; then
    log "GE-Proton already installed: $GE_TAG"
else
    info "Downloading $GE_TAG (~500 MB)..."
    info "This may take a few minutes on Wi-Fi..."

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

    # Check we can write to the game directory (relevant for SD card permissions)
    if [[ ! -w "$game_dir" ]]; then
        err "Cannot write to $game_dir"
        echo "  If the game is on a microSD card, make sure it's not mounted read-only."
        return
    fi

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

# ─── 3. Steam launch options ─────────────────────────────────────────────────

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Manual Steps (do these in Steam):${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""
echo "  1. Switch back to Game Mode (or restart Steam in Desktop Mode)"
echo ""
echo "  2. For each RE game → Press the ⚙ gear icon → Properties:"
echo ""
echo "     Compatibility:"
echo "       ☑ Force the use of a specific Steam Play compatibility tool"
echo "       Select: $GE_TAG"
echo ""
echo "     General → Launch Options:"
echo -e "       ${YELLOW}WINEDLLOVERRIDES=\"dinput8=n,b\" %command%${NC}"
echo ""
echo "  This tells Proton to load BhdTool's DLL as a native override."
echo "  Press F5 in-game to open the BhdTool menu."
echo "  Features: Save Anywhere, Door Skip, Room Jump."
echo ""
echo -e "${CYAN}  Steam Deck Tips:${NC}"
echo "  - In Game Mode: press the game tile → gear icon → Properties"
echo "  - Performance overlay (QAM → battery icon) works normally"
echo "  - Recommended: set TDP to 10-12W, these games are lightweight"
echo ""
echo -e "${CYAN}  BhdTool Button Mapping (F5 → back grip):${NC}"
echo "  BhdTool opens with F5, but there's no keyboard in Game Mode."
echo "  Remap a back button to F5 via Steam Input:"
echo "    1. Game Properties → Controller → Edit Layout"
echo "    2. Pick a button (e.g. L4 or L5 back grip)"
echo "    3. Set to: Keyboard → F5"
echo "  Now that button toggles the BhdTool overlay in-game."
echo ""

# ─── 4. Verify installation ──────────────────────────────────────────────────

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
log "Setup complete! Switch to Game Mode, set the options above, and enjoy."
echo ""
