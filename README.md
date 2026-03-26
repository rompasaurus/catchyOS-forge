# catchyOS-forge

Personal system setup and configuration toolkit for CachyOS (Arch Linux). One script to go from a fresh install to a fully configured desktop with all the tools, drivers, and tweaks dialed in.

## Quick Start

```bash
# Interactive menu
bash forge.sh

# Install everything
bash forge.sh --all

# Run individual modules
bash forge.sh --docker --cli --zsh
```

## Modules

### System Setup

| Flag | Script | What it does |
|---|---|---|
| `--cli` | `install-essentials.sh` | bat, eza, fd, ripgrep, fzf, lazygit, and other CLI staples |
| `--zsh` | `setup-zshrc.sh` | Oh My Zsh with plugins and custom config |
| `--docker` | `setup-docker.sh` | Docker Engine + Docker Desktop GUI |
| `--jetbrains` | `setup-jetbrains.sh` | JetBrains Toolbox (all IDEs) |
| `--smb` | `setup-smb.sh` | SMB share mounts for `//dookintel` via fstab |
| `--tailscale` | `setup-tailscale.sh` | Tailscale mesh VPN |

### Desktop & Input

| Flag | Script | What it does |
|---|---|---|
| `--swipe` | `setup-easy-swipe.sh` | Mouse gesture workspace switching (back button + swipe) |
| `--taskbar` | `patch-taskbar-indicator.sh` | Uniform light gray taskbar window indicator |
| `--xbox` | `setup-xbox-bt-controller.sh` | xpadneo driver for Xbox Bluetooth controllers in Steam |
| — | `setup-inputactions.sh` | Mouse back/forward button shortcuts (Overview, Desktop Grid) |
| — | `setup-denon-audio.sh` | Denon receiver audio output configuration |
| — | `setup-mt7927-wifi-bt.sh` | MT7927 WiFi + Bluetooth DKMS driver |
| — | `setup-vscode-icon.sh` | Blue VS Code icon replacement for Code OSS |

### Software & Security

| Flag | Script | What it does |
|---|---|---|
| `--software` | `install-software.sh` | Guided selection of browsers, IDEs, media apps, gaming tools |
| `--cac` | `setup-cac.sh` | DoD CAC smart card reader for Chrome |
| `--claude` | `setup-claude-code.sh` | Anthropic Claude Code CLI |
| `--bluray` | `setup-bluray.sh` | Blu-ray disc playback via VLC + MakeMKV |

### Gaming

| Flag | Script | What it does |
|---|---|---|
| `--re-mods` | `setup-re-hd-mods.sh` | RE HD Remaster mods (Proton GE + Door Skip plugin) |
| — | `setup-re-hd-mods-deck.sh` | Same as above, Steam Deck variant |
| — | `steam-lan-transfer.sh` | UFW firewall rules for Steam LAN game transfers |

### Networking & Peripherals

| Script | What it does |
|---|---|
| `setup-citrix-cac.sh` | Citrix Workspace with CAC smart card passthrough for DoD VDI |
| `setup-printer.sh` | Printer setup |
| `fix-bluetooth.sh` | Bluetooth troubleshooting fixes |
| `remmina-multimonitor.sh` | Remmina RDP multi-monitor configuration |

## Project Structure

```
catchyOS-forge/
├── forge.sh              # Main entry point (menu + CLI flags)
├── scripts/              # All setup modules
│   ├── easy-swipe/       # Mouse gesture daemon (Python)
│   └── *.sh              # Individual setup scripts
└── configs/
    ├── icons/            # Custom app icons (VS Code)
    └── zshrc             # Zsh configuration
```

## Requirements

- CachyOS or Arch Linux
- `pacman` / `yay` (AUR helper)
- `sudo` access

## Notes

- Each script is idempotent — safe to re-run.
- Run without arguments for the interactive menu, or pass flags for unattended setup.
- Log out and back in after first run for group changes (docker, input) to take effect.
