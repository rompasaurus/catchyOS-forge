# catchyOS-forge

A modular, idempotent system setup framework for **CachyOS** (Arch Linux). One master installer orchestrates 28+ specialized scripts that configure a complete development, gaming, media, and productivity environment.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
  - [Interactive Menu](#interactive-menu)
  - [CLI Flags](#cli-flags)
  - [Individual Scripts](#individual-scripts)
- [What Gets Installed](#what-gets-installed)
  - [System Setup](#system-setup)
  - [Software & Security](#software--security)
  - [Hardware & Drivers](#hardware--drivers)
  - [KDE Plasma Customization](#kde-plasma-customization)
  - [Media Tools](#media-tools)
- [Script Reference](#script-reference)
  - [forge.sh — Master Installer](#forgesh--master-installer)
  - [install-essentials.sh — CLI Tools](#install-essentialssh--cli-tools)
  - [install-software.sh — Software Selection](#install-softwaresh--software-selection)
  - [setup-docker.sh — Docker](#setup-dockersh--docker)
  - [setup-jetbrains.sh — JetBrains Toolbox](#setup-jetbrainssh--jetbrains-toolbox)
  - [setup-smb.sh — SMB/CIFS Mounts](#setup-smbsh--smbcifs-mounts)
  - [setup-zshrc.sh — Zsh Configuration](#setup-zshrcsh--zsh-configuration)
  - [setup-tailscale.sh — Tailscale VPN](#setup-tailscalesh--tailscale-vpn)
  - [setup-easy-swipe.sh — Mouse Gestures](#setup-easy-swipesh--mouse-gestures)
  - [setup-touchpad-gestures.sh — Touchpad Gestures](#setup-touchpad-gesturessh--touchpad-gestures)
  - [setup-xbox-bt-controller.sh — Xbox Controller](#setup-xbox-bt-controllersh--xbox-controller)
  - [setup-cac.sh — DoD CAC Smart Card](#setup-cacsh--dod-cac-smart-card)
  - [setup-citrix-cac.sh — Citrix VDI + CAC](#setup-citrix-cacsh--citrix-vdi--cac)
  - [setup-claude-code.sh — Claude Code CLI](#setup-claude-codesh--claude-code-cli)
  - [setup-ghostty.sh — Ghostty Terminal](#setup-ghosttysh--ghostty-terminal)
  - [setup-bluray.sh — Blu-ray Playback](#setup-bluraysh--blu-ray-playback)
  - [setup-re-hd-mods.sh — RE HD Remaster Mods](#setup-re-hd-modssh--re-hd-remaster-mods)
  - [setup-re-hd-mods-deck.sh — RE HD Mods (Steam Deck)](#setup-re-hd-mods-decksh--re-hd-mods-steam-deck)
  - [setup-inputactions.sh — KWin Mouse Buttons](#setup-inputactionssh--kwin-mouse-buttons)
  - [setup-mt7927-wifi-bt.sh — MediaTek WiFi 7](#setup-mt7927-wifi-btsh--mediatek-wifi-7)
  - [setup-denon-audio.sh — DENON-AVR Audio Routing](#setup-denon-audiosh--denon-avr-audio-routing)
  - [setup-printer.sh — Samsung Network Printer](#setup-printersh--samsung-network-printer)
  - [setup-tile-gaps.sh — KDE Window Gaps](#setup-tile-gapssh--kde-window-gaps)
  - [patch-taskbar-indicator.sh — Taskbar Patch](#patch-taskbar-indicatorsh--taskbar-patch)
  - [setup-vscode-icon.sh — VS Code Icon](#setup-vscode-iconsh--vs-code-icon)
  - [steam-lan-transfer.sh — Steam LAN Firewall](#steam-lan-transfersh--steam-lan-firewall)
  - [setup-steam-ports.sh — Steam Download Ports](#setup-steam-portssh--steam-download-ports)
  - [fix-bluetooth.sh — Bluetooth Recovery](#fix-bluetoothsh--bluetooth-recovery)
  - [dv-play.sh — Dolby Vision Player/Converter](#dv-playsh--dolby-vision-playerconverter)
  - [dv-convert-gui.sh — Dolby Vision GUI](#dv-convert-guish--dolby-vision-gui)
  - [dv-player.sh — Simple DV Player](#dv-playersh--simple-dv-player)
- [Project Structure](#project-structure)
- [Use Cases](#use-cases)
- [Configuration Files](#configuration-files)
- [Notes](#notes)

---

## Quick Start

```bash
git clone https://github.com/<your-user>/catchyOS-forge.git
cd catchyOS-forge

# Interactive menu
bash forge.sh

# Or install everything at once
bash forge.sh --all
```

## Prerequisites

| Requirement | Details |
|---|---|
| **OS** | CachyOS (Arch-based) |
| **AUR Helper** | `paru` or `yay` (required for AUR packages) |
| **Sudo** | Root access for system-wide installations |
| **Desktop** | KDE Plasma 6 (for taskbar/window gap patches, mouse/touchpad gestures) |
| **Internet** | Required for package downloads and firmware |

## Usage

### Interactive Menu

Run without arguments to get a numbered menu:

```bash
bash forge.sh
```

```
  ╔═══════════════════════════════════════════════╗
  ║            catchyOS-forge                     ║
  ║     CachyOS System Setup & Configuration      ║
  ╚═══════════════════════════════════════════════╝

  ── System Setup ──
   1) Docker Desktop         6) Easy Swipe
   2) JetBrains Toolbox      7) Tailscale
   3) SMB Mounts             8) Taskbar Patch
   4) CLI Essentials         9) Xbox BT Controller
   5) Zsh Config

  ── Software & Security ──
  10) Software Selection    13) Blu-Ray Player
  11) CAC Smart Card        14) RE HD Mods
  12) Claude Code           15) Ghostty Terminal
                            16) Touchpad Gestures

  ── Batch ──
  17) All of the above
   0) Exit
```

### CLI Flags

Automate specific components without the menu:

```bash
bash forge.sh --docker --jetbrains --cli --zsh
```

| Flag | Component |
|---|---|
| `--all` | Install everything |
| `--docker` | Docker Engine + Desktop |
| `--jetbrains` | JetBrains Toolbox |
| `--smb` | SMB share mounts |
| `--cli` | CLI essential tools |
| `--zsh` | Zsh + Oh My Zsh config |
| `--swipe` | Mouse gesture workspace switching |
| `--touchpad` | 3-finger touchpad gestures |
| `--tailscale` | Tailscale VPN |
| `--taskbar` | Taskbar indicator patch |
| `--xbox` | Xbox Bluetooth controller driver |
| `--software` | Interactive software selection |
| `--cac` | DoD CAC smart card for Chrome |
| `--claude` | Claude Code CLI |
| `--bluray` | Blu-ray playback setup |
| `--re-mods` | RE HD Remaster mods |
| `--ghostty` | Ghostty terminal + keybind config |
| `--help` | Show help |

### Individual Scripts

Run any script directly:

```bash
bash scripts/setup-docker.sh
bash scripts/setup-tile-gaps.sh --configure
bash scripts/setup-smb.sh --reconfigure
```

---

## What Gets Installed

### System Setup

- **30+ modern CLI tools** replacing coreutils: `bat` (cat), `eza` (ls), `fd` (find), `ripgrep` (grep), `fzf` (fuzzy finder), `zoxide` (cd), `btop` (top), `dust` (du), `duf` (df), `doggo` (dig), `tre` (tree), plus `lazygit`, `lazydocker`, `starship`, `tmux`, `jq`, `git-delta`, and more
- **Zsh** with Oh My Zsh, autosuggestions plugin, custom aliases, and Starship prompt
- **Docker Engine + Desktop** with compose and buildx
- **JetBrains Toolbox** for all JetBrains IDEs
- **Tailscale** VPN mesh networking
- **SMB/CIFS mounts** for network shares via fstab
- **mise** polyglot version manager for Node, Python, Go, Rust, etc.
- **Ghostty** terminal emulator with custom keybindings

### Software & Security

Interactive category-based installer with 10 categories:

| Category | Packages |
|---|---|
| Browsers | Firefox, Brave, Chrome |
| Communication | Discord, Slack, WhatsApp |
| Editors & Terminals | VS Code, Cursor, Kitty, Terminator, Ghostty |
| Languages | Rust, Go, Node.js, .NET, Java 21 |
| Cargo Tools | zellij, gitui, hyperfine, just, bottom, broot, xh, tokei, navi, bandwhich, gping, sd, watchexec, and more |
| Media | Spotify, VLC, MPV, Kodi, MakeMKV, EasyEffects |
| Productivity | Obsidian, Remmina, LibreOffice, Beekeeper Studio |
| Gaming | Steam (with multilib) |
| System | nvtop, cmatrix, figlet, OpenSSH, xrdp, mission-center |
| Dev Tools | GitHub CLI, Claude Code |

### Hardware & Drivers

- **Xbox Bluetooth controller** — xpadneo DKMS driver with ERTM disable and udev rules
- **MediaTek MT7927 WiFi 7** — DKMS driver build from source (WiFi + Bluetooth)
- **DENON-AVR audio** — WirePlumber routing rules for 7.1 surround via HDMI
- **USB smart card readers** — udev rules for HID Global, Identiv, Gemalto, Cherry, Yubico
- **Samsung M288x printer** — CUPS + Avahi auto-discovery with splix driver
- **Bluetooth recovery** — 3-step fix for controllers that disappear after sleep/suspend

### KDE Plasma Customization

- **Taskbar indicator patch** — uniform light gray instead of accent color
- **Window tile gaps** — configurable pixel gaps between tiled windows
- **Mouse button mapping** — Back/Forward buttons to Overview/Desktop Grid via InputActions KWin plugin
- **Mouse workspace swipe** — hold Back + swipe to switch virtual desktops (natural/drag direction)
- **Touchpad gestures** — 3-finger swipe replaces 4-finger for desktop switching, Overview, and Show Desktop
- **VS Code icon** — blue VS Code icon replacing the green Code-OSS icon

### Media Tools

- **Dolby Vision playback** — mpv with HDR tone-mapping for DV content
- **Dolby Vision conversion** — strip DV metadata (keep HDR10) or tone-map to SDR
- **Dolby Vision GUI** — Zenity-based file picker with drag-and-drop conversion
- **Blu-ray playback** — VLC + MakeMKV + AACS decryption + KEYDB

---

## Script Reference

### forge.sh — Master Installer

The entry point. Presents an interactive menu or accepts CLI flags to run individual setup scripts. Handles color-coded logging and error reporting. The `--all` flag runs every script in optimal dependency order.

### install-essentials.sh — CLI Tools

Installs ~30 modern CLI tools from pacman and AUR. Sets up Oh My Zsh with the autosuggestions plugin and installs `mise` (polyglot version manager). All tools are checked before install — safe to run repeatedly.

### install-software.sh — Software Selection

Interactive toggle menu across 10 categories. Select individual packages or entire categories. Handles pacman, AUR, flatpak, cargo, and npm sources. Pass `--all` to install everything non-interactively.

### setup-docker.sh — Docker

Installs Docker Engine, docker-compose, and docker-buildx from pacman. Installs Docker Desktop from AUR with qemu-base backend. Adds your user to the `docker` group and starts the service.

### setup-jetbrains.sh — JetBrains Toolbox

Installs fuse2 and JetBrains Toolbox from AUR, then launches Toolbox so you can install any JetBrains IDE (IntelliJ, WebStorm, PyCharm, CLion, GoLand, Rider, RustRover, etc.).

### setup-smb.sh — SMB/CIFS Mounts

Mounts 9 SMB shares from a `dookintel` server via fstab. Creates `~/.smbcredentials` (mode 600) and mount points under `/mnt/dookintel/`. Uses CIFS 3.0 with NTLMv2 auth and auto-mount on boot. Run with `--reconfigure` to update credentials.

### setup-zshrc.sh — Zsh Configuration

Installs Zsh, Oh My Zsh, and the autosuggestions plugin. Deploys the custom `.zshrc` from `configs/zshrc` (backs up existing config). Changes default shell to Zsh. The config sets up modern aliases (`ls` -> `eza`, `cat` -> `bat`, etc.), fzf integration with bat/eza previews, Starship prompt, and tool initializers for zoxide, direnv, and mise.

### setup-tailscale.sh — Tailscale VPN

Installs Tailscale, enables the systemd socket and service, and prompts you to authenticate with `sudo tailscale up`.

### setup-easy-swipe.sh — Mouse Gestures

Installs a Python-based daemon that maps mouse gestures to workspace actions using natural/drag-style direction:

- **Back + swipe right** — previous virtual desktop
- **Back + swipe left** — next virtual desktop (wraps to first if on last)
- **Back click** — KDE Overview

The daemon uses `python-evdev` to intercept raw input events, creates a UInput virtual mouse for event forwarding, and communicates with KWin via DBus. Automatically detects multiple mice and filters out keyboards/touchpads. Runs as a systemd user service. Requires `input` group membership (logout/login after install).

### setup-touchpad-gestures.sh — Touchpad Gestures

Remaps KDE's default 4-finger touchpad gestures to 3-finger using `libinput-gestures`:

- **3-finger swipe left** — next desktop (natural/drag direction)
- **3-finger swipe right** — previous desktop
- **3-finger swipe up** — KDE Overview (all windows + desktops)
- **3-finger swipe down** — Show Desktop (minimize all)

Installs `libinput-gestures` from AUR, deploys the gesture config, disables KDE's built-in touchpad gestures to avoid conflicts, and creates an autostart entry. Requires `input` group membership (logout/login after install).

### setup-xbox-bt-controller.sh — Xbox Controller

Fixes Xbox One S Bluetooth connectivity by:
1. Disabling Bluetooth ERTM via modprobe
2. Installing the `xpadneo` DKMS driver with kernel headers
3. Creating udev rules for Xbox controller product IDs
4. Reconnecting the controller to re-probe with the new module

### setup-cac.sh — DoD CAC Smart Card

Full DoD CAC smart card setup for Chrome and Firefox:
- Installs OpenSC, CCID, PC/SC tools, and NSS utilities
- Creates udev rules for common smart card readers (HID Global, Identiv, Gemalto, Cherry, Yubico, ACR)
- Starts the PC/SC daemon
- Initializes the NSS database at `~/.pki/nssdb`
- Registers the PKCS#11 module
- Downloads and imports DoD root certificates

### setup-citrix-cac.sh — Citrix VDI + CAC

Extends CAC setup for Citrix Workspace:
- Installs Citrix ICA client with all dependencies
- Links system CA certificates into the Citrix keystore
- Downloads DoD certificates and converts PKCS#7 to PEM
- Configures `AuthManConfig.xml` with the PKCS#11 module path
- Enables smart card cryptographic redirection

**Prerequisite:** Run `setup-cac.sh` first.

### setup-claude-code.sh — Claude Code CLI

Installs Node.js/npm if missing, then installs the Claude Code CLI globally via npm. Checks for updates on subsequent runs.

### setup-ghostty.sh — Ghostty Terminal

Installs the Ghostty terminal emulator from AUR and deploys a custom keybind config from `configs/ghostty/config`. Backs up any existing Ghostty config before deploying. Configures:
- Ctrl+1-9 for tab switching
- Ctrl+Shift+[/] for split pane navigation
- Ctrl+Shift+H/J/K/L for directional split navigation
- Ctrl+Shift+W to close a split pane

### setup-bluray.sh — Blu-ray Playback

Sets up Blu-ray disc playback:
- Installs VLC, libbluray, and Java (for BD-J menus)
- Replaces stock libaacs with MakeMKV's libaacs for AACS decryption
- Downloads the KEYDB.cfg key database
- Creates a `bluray-play` wrapper script and desktop launcher
- Adds user to the `optical` group

### setup-re-hd-mods.sh — RE HD Remaster Mods

Automates modding for Resident Evil HD Remaster on Steam:
- Detects game installation across all Steam library paths
- Downloads and installs the latest **GE-Proton** release (with checksum verification)
- Downloads and installs the **Door Skip Plugin** (reduces door animations from 7.6s to ~2.2s)
- Does not disable achievements
- Provides manual instructions for setting Steam launch options

### setup-re-hd-mods-deck.sh — RE HD Mods (Steam Deck)

Steam Deck variant of the RE HD mod installer. Handles Deck-specific paths (including SD card libraries), write permission checks, and provides Game Mode setup instructions.

### setup-inputactions.sh — KWin Mouse Buttons

Installs the InputActions KWin plugin and configures mouse button mappings:
- **Mouse Back (button 8)** — KDE Overview
- **Mouse Forward (button 9)** — Desktop Grid

Requires Wayland.

### setup-mt7927-wifi-bt.sh — MediaTek WiFi 7

Builds and installs the MediaTek MT7927 WiFi 7 + Bluetooth driver via DKMS:
1. Installs build dependencies and kernel headers
2. Clones the driver repository
3. Downloads kernel source and ASUS firmware
4. Patches and compiles the mt76 WiFi and btmtk Bluetooth modules
5. Installs firmware blobs and regenerates initramfs

Supports PCIe WiFi (mt7925e) and USB Bluetooth (MT6639).

### setup-denon-audio.sh — DENON-AVR Audio Routing

Configures audio routing for a DENON-AVR receiver connected via HDMI:
- Installs a routing script to `~/.local/bin/`
- Creates WirePlumber rules for 7.1 surround output
- Creates a desktop launcher and systemd user service for auto-routing on boot
- Sets card profile and moves audio streams via `pactl`/`wpctl`

### setup-printer.sh — Samsung Network Printer

Auto-discovers and configures a Samsung M288x network printer:
- Installs CUPS printing system, Avahi mDNS discovery, and splix Samsung drivers
- Enables CUPS and Avahi systemd services
- Configures mDNS resolution in `nsswitch.conf`
- Scans for the printer via Avahi and CUPS backends
- Auto-selects the best available driver (Samsung-specific or driverless IPP Everywhere)
- Sets the discovered printer as default
- Falls back to manual setup instructions if auto-discovery fails

### setup-tile-gaps.sh — KDE Window Gaps

Installs the tile-gaps KWin script for pixel gaps between tiled windows:
- Configurable base gap (default 16px), inter-window gap (default 16px), and panel padding (default 10px)
- Auto-detects panels per monitor

```bash
bash scripts/setup-tile-gaps.sh              # Install with defaults
bash scripts/setup-tile-gaps.sh --configure  # Change gap values
bash scripts/setup-tile-gaps.sh --uninstall  # Remove
```

### patch-taskbar-indicator.sh — Taskbar Patch

Patches KDE Plasma's taskbar to use a uniform light gray indicator strip instead of the accent color. Extracts `tasks.svgz`, modifies SVG attributes, and installs to the local theme directory. Clears the Plasma SVG cache and restarts plasmashell.

### setup-vscode-icon.sh — VS Code Icon

Replaces the green Code-OSS icon with the official blue VS Code icon. Copies `configs/icons/vscode.svg` to the local icon theme directory and updates the icon cache.

### steam-lan-transfer.sh — Steam LAN Firewall

Opens UFW firewall ports required for Steam LAN game transfers:
- `27031-27036/UDP` — LAN discovery
- `27040/TCP`, `24070/TCP` — LAN game transfer
- `27014-27050/TCP` — Steam downloads

### setup-steam-ports.sh — Steam Download Ports

Opens broader UFW firewall rules for full Steam functionality:
- Allows all traffic from private LAN subnets (`192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`)
- `27000-27100/UDP` — Steam game traffic and downloads
- `27015-27050/TCP` — Steam client connections
- `3478-4380/UDP` — Steamworks P2P and voice chat
- Outbound HTTP/HTTPS for content delivery

### fix-bluetooth.sh — Bluetooth Recovery

3-step escalation fix for Bluetooth controllers that disappear after sleep/suspend on CachyOS:
1. **Service restart** — restarts the bluetooth systemd service
2. **Module reload** — unloads and reloads the `btusb` kernel module
3. **rfkill power cycle** — blocks and unblocks Bluetooth via rfkill

Checks for a powered controller after each step and exits early on success. Suggests a reboot if all steps fail.

### dv-play.sh — Dolby Vision Player/Converter

Multi-mode tool for Dolby Vision video files:

```bash
dv-play.sh movie.mkv              # Play with mpv HDR tone-mapping
dv-play.sh --convert movie.mkv    # Strip DV layer → HDR10 (fast, lossless)
dv-play.sh --tosdr movie.mkv      # Tone-map → SDR (slow, re-encode with libx265)
dv-play.sh --batch /path/to/dir   # Strip DV from all MKV/MP4 in directory
dv-play.sh --batch-sdr /path/     # Tone-map entire directory to SDR
```

Auto-configures `~/.config/mpv/mpv.conf` with HDR tone-mapping settings (gpu-next, hable tone-mapping, hybrid mode). Requires `mpv` for playback and `ffmpeg` for conversion.

### dv-convert-gui.sh — Dolby Vision GUI

Zenity-based GUI wrapper for `dv-play.sh`. Supports drag-and-drop (pass files as arguments) or opens a file picker dialog. Presents an action menu (play, strip DV, tone-map to SDR) with progress dialogs and desktop notifications.

### dv-player.sh — Simple DV Player

Minimal wrapper that launches `mpv` with HDR tone-mapping flags (`--vo=gpu-next --tone-mapping=hable --tone-mapping-mode=hybrid`). Pass any video file as an argument.

---

## Project Structure

```
catchyOS-forge/
├── forge.sh                            # Master installer (menu + CLI flags)
├── CHEATSHEET.md                       # Quick reference guide
├── CHEATSHEET-PRINTABLE.md             # Printable cheatsheet
├── configs/
│   ├── zshrc                           # Custom Zsh config (aliases, fzf, starship)
│   ├── ghostty/
│   │   └── config                      # Ghostty terminal keybindings
│   └── icons/
│       └── vscode.svg                  # VS Code blue icon
└── scripts/
    ├── install-essentials.sh           # 30+ modern CLI tools
    ├── install-software.sh             # Interactive category-based installer
    ├── setup-docker.sh                 # Docker Engine + Desktop
    ├── setup-jetbrains.sh              # JetBrains Toolbox
    ├── setup-smb.sh                    # SMB/CIFS network mounts
    ├── setup-zshrc.sh                  # Zsh + Oh My Zsh + plugins
    ├── setup-tailscale.sh              # Tailscale VPN
    ├── setup-easy-swipe.sh             # Mouse gesture workspace switching
    ├── setup-touchpad-gestures.sh      # 3-finger touchpad gestures
    ├── setup-xbox-bt-controller.sh     # Xbox BT controller (xpadneo)
    ├── setup-cac.sh                    # DoD CAC smart card
    ├── setup-citrix-cac.sh             # Citrix VDI + CAC passthrough
    ├── setup-claude-code.sh            # Claude Code CLI
    ├── setup-ghostty.sh                # Ghostty terminal + keybind config
    ├── setup-bluray.sh                 # Blu-ray playback (VLC + MakeMKV)
    ├── setup-re-hd-mods.sh            # RE HD Remaster mods
    ├── setup-re-hd-mods-deck.sh        # RE HD mods (Steam Deck)
    ├── setup-inputactions.sh           # KWin mouse button mapping
    ├── setup-mt7927-wifi-bt.sh         # MediaTek MT7927 WiFi 7 driver
    ├── setup-denon-audio.sh            # DENON-AVR 7.1 audio routing
    ├── setup-printer.sh                # Samsung M288x network printer
    ├── setup-tile-gaps.sh              # KDE window tile gaps
    ├── patch-taskbar-indicator.sh      # Taskbar indicator patch
    ├── setup-vscode-icon.sh            # VS Code icon replacement
    ├── steam-lan-transfer.sh           # UFW rules for Steam LAN
    ├── setup-steam-ports.sh            # Steam download/P2P firewall ports
    ├── fix-bluetooth.sh                # Bluetooth controller recovery
    ├── dv-play.sh                      # Dolby Vision player/converter
    ├── dv-convert-gui.sh               # DV conversion GUI (Zenity)
    ├── dv-player.sh                    # Simple mpv DV player wrapper
    └── easy-swipe/
        └── mouse-workspace-swipe.py    # Python daemon for mouse gestures
```

---

## Use Cases

### Fresh CachyOS Install

Run the full setup to go from a bare CachyOS install to a fully configured workstation:

```bash
bash forge.sh --all
```

This installs CLI tools, Zsh, Docker, JetBrains, SMB mounts, Tailscale, gaming controllers, software selection, CAC support, Blu-ray playback, Ghostty, and gesture controls — then prompts you to log out for group changes to take effect.

### Developer Workstation

Set up a development environment with modern tools:

```bash
bash forge.sh --cli --zsh --docker --jetbrains --ghostty
bash scripts/setup-claude-code.sh
```

### Gaming PC

Configure Steam, controllers, and game mods:

```bash
bash forge.sh --xbox --software
bash scripts/setup-re-hd-mods.sh
bash scripts/steam-lan-transfer.sh
bash scripts/setup-steam-ports.sh
```

### Home Theater / Media Center

Set up Blu-ray playback, surround sound, and Dolby Vision:

```bash
bash forge.sh --bluray
bash scripts/setup-denon-audio.sh
bash scripts/dv-play.sh movie.mkv       # Play DV content
bash scripts/dv-play.sh --convert movie.mkv  # Strip DV → HDR10
```

### DoD / Government Workstation

Configure CAC smart card authentication for Chrome, Firefox, and Citrix:

```bash
bash scripts/setup-cac.sh
bash scripts/setup-citrix-cac.sh
```

### KDE Plasma Customization

Tune the desktop appearance and input behavior:

```bash
bash scripts/patch-taskbar-indicator.sh     # Uniform gray taskbar
bash scripts/setup-tile-gaps.sh             # Window gaps
bash scripts/setup-inputactions.sh          # Mouse button → Overview/Grid
bash scripts/setup-easy-swipe.sh            # Mouse back + swipe → desktops
bash scripts/setup-touchpad-gestures.sh     # 3-finger swipe → desktops
bash scripts/setup-vscode-icon.sh           # Blue VS Code icon
```

### Laptop Setup

Configure touchpad gestures and printer:

```bash
bash forge.sh --touchpad --cli --zsh --ghostty
bash scripts/setup-printer.sh
```

### Steam Deck Modding

Install RE HD Remaster mods on a Steam Deck:

```bash
bash scripts/setup-re-hd-mods-deck.sh
```

### Hardware Driver Setup

Fix specific hardware issues:

```bash
bash scripts/setup-xbox-bt-controller.sh   # Xbox BT controller
bash scripts/setup-mt7927-wifi-bt.sh        # MediaTek WiFi 7 + BT
bash scripts/fix-bluetooth.sh              # Recover after sleep/suspend
```

---

## Configuration Files

### configs/zshrc

Custom Zsh configuration deployed by `setup-zshrc.sh`:

- **Theme:** robbyrussell (Oh My Zsh)
- **Prompt:** Starship
- **Plugins:** git, zsh-autosuggestions
- **FZF:** uses `fd` for file search, `bat` for preview, `eza` for directory preview
- **Modern aliases:**

| Alias | Replacement |
|---|---|
| `ls`, `ll`, `la`, `lt` | `eza` (with icons, git status, tree) |
| `cat` | `bat` |
| `du` | `dust` |
| `df` | `duf` |
| `find` | `fd` |
| `grep` | `rg` |
| `tree` | `tre` |
| `top` | `btop` |
| `dig` | `doggo` |
| `lg` | `lazygit` |
| `ld` | `lazydocker` |

- **Tool init:** zoxide, fzf, starship, direnv, mise

### configs/ghostty/config

Custom Ghostty terminal keybindings:

| Keybinding | Action |
|---|---|
| `Ctrl+1` through `Ctrl+9` | Switch to tab 1-9 |
| `Ctrl+Shift+[` / `Ctrl+Shift+]` | Previous/next split pane |
| `Ctrl+Shift+H/J/K/L` | Directional split navigation (vim-style) |
| `Ctrl+Shift+W` | Close split pane |

---

## Notes

- All scripts use `set -euo pipefail` and are **idempotent** — safe to run multiple times.
- Color-coded output: green (success), cyan (info), yellow (warning), red (error).
- Some scripts add your user to system groups (`docker`, `input`, `optical`, `lp`). **Log out and back in** after running these for changes to take effect.
- AUR packages require either `paru` or `yay` to be installed first.
- The `.gitignore` excludes `*.bak` files and `.smbcredentials` to prevent committing backups or secrets.
- Gesture scripts (Easy Swipe + Touchpad Gestures) both use **natural/drag direction** — swipe left moves to the next desktop, swipe right moves to the previous desktop.
- The Dolby Vision tools (`dv-play.sh`, `dv-convert-gui.sh`, `dv-player.sh`) can be run standalone without the forge installer.
