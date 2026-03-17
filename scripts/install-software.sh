#!/usr/bin/env bash
#
# install-software.sh — Interactive software selection menu for CachyOS.
# Maps all apps from the Ubuntu desktop to CachyOS (Arch) equivalents.
#
# Run with: bash scripts/install-software.sh
#
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }

# ─── Package install helpers ─────────────────────────────────────────────────

pac_install() {
    local pkgs=("$@")
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installing (pacman): ${to_install[*]}"
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
    else
        log "Already installed: ${pkgs[*]}"
    fi
}

aur_install() {
    local pkgs=("$@")
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
        if command -v paru &>/dev/null; then
            info "Installing (AUR): ${to_install[*]}"
            paru -S --needed --noconfirm "${to_install[@]}"
        elif command -v yay &>/dev/null; then
            info "Installing (AUR): ${to_install[*]}"
            yay -S --needed --noconfirm "${to_install[@]}"
        else
            err "No AUR helper found (paru/yay). Install paru first."
            return 1
        fi
    else
        log "Already installed: ${pkgs[*]}"
    fi
}

flatpak_install() {
    local app_id="$1"
    if ! command -v flatpak &>/dev/null; then
        info "Installing flatpak..."
        sudo pacman -S --needed --noconfirm flatpak
    fi
    if flatpak info "$app_id" &>/dev/null; then
        log "Flatpak already installed: $app_id"
    else
        info "Installing flatpak: $app_id"
        flatpak install -y flathub "$app_id"
    fi
}

cargo_install() {
    local crate="$1"
    local bin="${2:-$1}"
    if command -v "$bin" &>/dev/null; then
        log "Already installed: $bin"
    else
        info "Installing (cargo): $crate"
        cargo install "$crate"
    fi
}

# ─── Category install functions ──────────────────────────────────────────────

install_browsers() {
    echo -e "\n${BOLD}── Browsers ──${NC}\n"
    pac_install firefox
    aur_install brave-bin google-chrome
    log "Browsers done."
}

install_communication() {
    echo -e "\n${BOLD}── Communication ──${NC}\n"
    pac_install discord thunderbird
    aur_install slack-desktop
    flatpak_install com.github.eneshecan.WhatsAppForLinux
    log "Communication apps done."
}

install_editors() {
    echo -e "\n${BOLD}── Editors & Terminals ──${NC}\n"
    aur_install visual-studio-code-bin
    aur_install cursor-bin
    pac_install kitty
    pac_install terminator
    aur_install ghostty
    log "Editors & terminals done."
    info "JetBrains Toolbox is a separate forge option (--jetbrains)."
}

install_languages() {
    echo -e "\n${BOLD}── Languages & Runtimes ──${NC}\n"
    pac_install rustup go nodejs npm jdk21-openjdk base-devel
    aur_install dotnet-sdk-bin

    # Initialize rustup if needed
    if command -v rustup &>/dev/null && ! rustup show active-toolchain &>/dev/null 2>&1; then
        info "Initializing rustup with stable toolchain..."
        rustup default stable
    fi

    # pipx
    pac_install python-pipx

    log "Languages & runtimes done."
}

install_cargo_tools() {
    echo -e "\n${BOLD}── Cargo / Rust CLI Tools ──${NC}\n"

    # Many of these are in pacman/AUR — prefer packaged versions
    pac_install \
        bandwhich bottom broot gitui gping grex hyperfine just \
        navi procs sd tokei watchexec xh xplr zellij

    aur_install \
        choose git-absorb spotify_player-bin tickrs ytermusic

    log "Cargo/Rust CLI tools done."
}

install_media() {
    echo -e "\n${BOLD}── Media ──${NC}\n"
    pac_install vlc mpv kodi easyeffects
    aur_install spotify makemkv
    log "Media apps done."
}

install_productivity() {
    echo -e "\n${BOLD}── Productivity ──${NC}\n"
    pac_install obsidian remmina libreoffice-fresh
    aur_install beekeeper-studio-bin
    log "Productivity apps done."
}

install_gaming() {
    echo -e "\n${BOLD}── Gaming ──${NC}\n"
    pac_install steam
    log "Gaming done."
    info "Enable multilib in /etc/pacman.conf if Steam fails to install."
}

install_system() {
    echo -e "\n${BOLD}── System & Utilities ──${NC}\n"
    pac_install \
        nvtop cmatrix figlet toilet mc glow flatpak openssh github-cli \
        stress phoronix-test-suite

    aur_install mission-center xrdp

    # Claude Code via npm
    if command -v npm &>/dev/null; then
        if ! command -v claude &>/dev/null; then
            info "Installing Claude Code..."
            sudo npm install -g @anthropic-ai/claude-code
        else
            log "Claude Code already installed."
        fi
    fi

    log "System utilities done."
}

install_dev_tools() {
    echo -e "\n${BOLD}── Dev Tools ──${NC}\n"
    pac_install git github-cli git-delta tig
    aur_install lazygit lazydocker-bin

    # gnome-extensions-cli via pipx
    if command -v pipx &>/dev/null; then
        if ! pipx list --short 2>/dev/null | grep -q gnome-extensions-cli; then
            info "Installing gnome-extensions-cli via pipx..."
            pipx install gnome-extensions-cli
        else
            log "gnome-extensions-cli already installed."
        fi
    fi

    log "Dev tools done."
}

# ─── Category definitions ───────────────────────────────────────────────────

declare -a CATEGORIES=(
    "Browsers"
    "Communication"
    "Editors & Terminals"
    "Languages & Runtimes"
    "Cargo / Rust CLI Tools"
    "Media"
    "Productivity"
    "Gaming"
    "System & Utilities"
    "Dev Tools"
)

declare -a DESCRIPTIONS=(
    "Firefox, Brave, Chrome"
    "Discord, Slack, WhatsApp, Thunderbird"
    "VS Code, Cursor, Kitty, Terminator, Ghostty"
    "Rust, Go, Node.js, .NET 10, Java 21, Python pipx"
    "zellij, gitui, hyperfine, just, bottom, broot, xh, +more"
    "Spotify, VLC, MPV, Kodi, MakeMKV, Easy Effects"
    "Obsidian, Remmina, LibreOffice, Beekeeper Studio"
    "Steam"
    "nvtop, cmatrix, mc, glow, flatpak, openssh, gh, Claude Code"
    "git-delta, tig, lazygit, lazydocker, gnome-extensions-cli"
)

declare -a INSTALLERS=(
    install_browsers
    install_communication
    install_editors
    install_languages
    install_cargo_tools
    install_media
    install_productivity
    install_gaming
    install_system
    install_dev_tools
)

# ─── Interactive menu ────────────────────────────────────────────────────────

show_banner() {
    echo -e "${CYAN}"
    echo "  ┌──────────────────────────────────────────────┐"
    echo "  │        Software Selection Installer           │"
    echo "  │            CachyOS / Arch                     │"
    echo "  └──────────────────────────────────────────────┘"
    echo -e "${NC}"
}

show_menu() {
    local -a selected=()
    for _ in "${CATEGORIES[@]}"; do selected+=(0); done

    while true; do
        clear
        show_banner
        echo -e "${BOLD}Toggle categories to install (enter number to toggle):${NC}"
        echo ""

        for i in "${!CATEGORIES[@]}"; do
            local num=$((i + 1))
            local mark=" "
            [[ ${selected[$i]} -eq 1 ]] && mark="${GREEN}✓${NC}"
            printf "  [%b] %2d) %-26s ${DIM}%s${NC}\n" "$mark" "$num" "${CATEGORIES[$i]}" "${DESCRIPTIONS[$i]}"
        done

        echo ""
        echo -e "   ${BOLD}a)${NC} Select all"
        echo -e "   ${BOLD}n)${NC} Select none"
        echo -e "   ${BOLD}i)${NC} Install selected"
        echo -e "   ${BOLD}q)${NC} Quit"
        echo ""
        read -rp "Choice: " choice

        case "$choice" in
            [1-9]|10)
                local idx=$((choice - 1))
                if [[ $idx -lt ${#CATEGORIES[@]} ]]; then
                    selected[$idx]=$(( 1 - selected[$idx] ))
                fi
                ;;
            a|A)
                for i in "${!selected[@]}"; do selected[$i]=1; done
                ;;
            n|N)
                for i in "${!selected[@]}"; do selected[$i]=0; done
                ;;
            i|I)
                local any=0
                for s in "${selected[@]}"; do
                    [[ $s -eq 1 ]] && any=1 && break
                done
                if [[ $any -eq 0 ]]; then
                    warn "Nothing selected. Toggle categories first."
                    read -rp "Press Enter to continue..." _
                    continue
                fi

                echo ""
                echo -e "${BOLD}The following will be installed:${NC}"
                for i in "${!CATEGORIES[@]}"; do
                    [[ ${selected[$i]} -eq 1 ]] && echo -e "  ${GREEN}✓${NC} ${CATEGORIES[$i]}"
                done
                echo ""
                read -rp "Proceed? [Y/n] " confirm
                [[ "$confirm" =~ ^[Nn] ]] && continue

                for i in "${!CATEGORIES[@]}"; do
                    if [[ ${selected[$i]} -eq 1 ]]; then
                        ${INSTALLERS[$i]}
                    fi
                done

                echo ""
                log "All selected software installed!"
                echo ""
                read -rp "Press Enter to exit..." _
                return 0
                ;;
            q|Q)
                echo "Bye!"
                return 0
                ;;
            *)
                warn "Invalid choice."
                read -rp "Press Enter to continue..." _
                ;;
        esac
    done
}

# ─── CLI flags ───────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    show_menu
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        --all)
            for installer in "${INSTALLERS[@]}"; do $installer; done
            ;;
        --browsers)       install_browsers ;;
        --communication)  install_communication ;;
        --editors)        install_editors ;;
        --languages)      install_languages ;;
        --cargo-tools)    install_cargo_tools ;;
        --media)          install_media ;;
        --productivity)   install_productivity ;;
        --gaming)         install_gaming ;;
        --system)         install_system ;;
        --dev-tools)      install_dev_tools ;;
        --help|-h)
            show_banner
            echo "Usage: bash install-software.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all             Install everything"
            echo "  --browsers        Firefox, Brave, Chrome"
            echo "  --communication   Discord, Slack, WhatsApp, Thunderbird"
            echo "  --editors         VS Code, Cursor, Kitty, Terminator, Ghostty"
            echo "  --languages       Rust, Go, Node, .NET, Java, Python"
            echo "  --cargo-tools     Rust CLI tools (zellij, gitui, etc.)"
            echo "  --media           Spotify, VLC, MPV, Kodi, MakeMKV"
            echo "  --productivity    Obsidian, Remmina, LibreOffice, Beekeeper"
            echo "  --gaming          Steam"
            echo "  --system          nvtop, flatpak, openssh, Claude Code, etc."
            echo "  --dev-tools       git-delta, lazygit, lazydocker, gh"
            echo "  --help            Show this help"
            echo ""
            echo "Run without arguments for interactive toggle menu."
            ;;
        *)
            err "Unknown option: $arg"
            echo "Run: bash install-software.sh --help"
            exit 1
            ;;
    esac
done
