#!/usr/bin/env bash
#
# catchyOS-forge — Master installer for CachyOS (Arch).
# Installs Docker Desktop, JetBrains Toolbox, SMB mounts,
# CLI essentials, Zsh config, and Easy Swipe mouse gestures.
#
# Usage: bash forge.sh [--all | --docker | --jetbrains | --smb | --cli | --zsh | --swipe]
#        bash forge.sh              (interactive menu)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }

show_banner() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║            catchyOS-forge                     ║"
    echo "  ║     CachyOS System Setup & Configuration      ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

run_script() {
    local script="$SCRIPT_DIR/scripts/$1"
    if [ -f "$script" ]; then
        echo ""
        bash "$script"
        echo ""
    else
        err "Script not found: $script"
        return 1
    fi
}

show_menu() {
    echo -e "${BOLD}Select what to install:${NC}"
    echo ""
    echo "   1) Docker Desktop        (Docker Engine + Desktop GUI)"
    echo "   2) JetBrains Toolbox     (All JetBrains IDEs)"
    echo "   3) SMB Mounts            (//dookintel shares via fstab)"
    echo "   4) CLI Essentials        (bat, eza, fd, rg, fzf, lazygit, ...)"
    echo "   5) Zsh Config            (Oh My Zsh + plugins + config)"
    echo "   6) Easy Swipe            (Mouse gesture workspace switching)"
    echo "   7) Tailscale             (VPN mesh network)"
    echo "   8) Taskbar Patch         (Uniform light gray indicator)"
    echo "   9) Xbox BT Controller    (xpadneo driver for Steam)"
    echo "  10) All of the above"
    echo "   0) Exit"
    echo ""
    read -rp "Choice [0-10]: " choice
    echo ""

    case "$choice" in
        1)  run_script "setup-docker.sh" ;;
        2)  run_script "setup-jetbrains.sh" ;;
        3)  run_script "setup-smb.sh" ;;
        4)  run_script "install-essentials.sh" ;;
        5)  run_script "setup-zshrc.sh" ;;
        6)  run_script "setup-easy-swipe.sh" ;;
        7)  run_script "setup-tailscale.sh" ;;
        8)  run_script "patch-taskbar-indicator.sh" ;;
        9)  run_script "setup-xbox-bt-controller.sh" ;;
        10) run_all ;;
        0)  echo "Bye!"; exit 0 ;;
        *)  err "Invalid choice"; show_menu ;;
    esac
}

run_all() {
    log "Running full setup..."
    run_script "install-essentials.sh"
    run_script "setup-zshrc.sh"
    run_script "setup-docker.sh"
    run_script "setup-jetbrains.sh"
    run_script "setup-smb.sh"
    run_script "setup-easy-swipe.sh"
    run_script "setup-tailscale.sh"
    run_script "patch-taskbar-indicator.sh"
    run_script "setup-xbox-bt-controller.sh"
    echo ""
    log "Full setup complete!"
    warn "Log out and back in for group changes (docker, input) to take effect."
}

# ─── CLI argument handling ───────────────────────────────────────────────────

show_banner

if [ $# -eq 0 ]; then
    show_menu
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        --all)       run_all ;;
        --docker)    run_script "setup-docker.sh" ;;
        --jetbrains) run_script "setup-jetbrains.sh" ;;
        --smb)       run_script "setup-smb.sh" ;;
        --cli)       run_script "install-essentials.sh" ;;
        --zsh)       run_script "setup-zshrc.sh" ;;
        --swipe)     run_script "setup-easy-swipe.sh" ;;
        --tailscale) run_script "setup-tailscale.sh" ;;
        --taskbar)   run_script "patch-taskbar-indicator.sh" ;;
        --xbox)      run_script "setup-xbox-bt-controller.sh" ;;
        --help|-h)
            echo "Usage: bash forge.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all        Install everything"
            echo "  --docker     Docker Engine + Desktop"
            echo "  --jetbrains  JetBrains Toolbox"
            echo "  --smb        Mount SMB shares (//dookintel)"
            echo "  --cli        CLI essential tools"
            echo "  --zsh        Zsh + Oh My Zsh config"
            echo "  --swipe      Easy Swipe mouse gestures"
            echo "  --tailscale  Tailscale VPN"
            echo "  --taskbar    Uniform light gray taskbar indicator"
            echo "  --xbox       Xbox Bluetooth controller (xpadneo)"
            echo "  --help       Show this help"
            echo ""
            echo "Run without arguments for interactive menu."
            ;;
        *)
            err "Unknown option: $arg"
            echo "Run: bash forge.sh --help"
            exit 1
            ;;
    esac
done
