<style>
  @page { size: letter; margin: 0.4in; }
  body { font-family: "JetBrains Mono", "Fira Code", monospace; font-size: 7.5pt; line-height: 1.2; column-count: 3; column-gap: 14px; color: #1a1a1a; }
  h1 { column-span: all; text-align: center; font-size: 13pt; margin: 0 0 4px; border-bottom: 2px solid #333; padding-bottom: 2px; }
  h2 { font-size: 8.5pt; margin: 6px 0 2px; padding: 1px 4px; background: #333; color: #fff; break-after: avoid; }
  h3 { font-size: 7.5pt; margin: 4px 0 1px; border-bottom: 1px solid #999; break-after: avoid; }
  table { width: 100%; border-collapse: collapse; margin: 0 0 2px; font-size: 7pt; }
  th { display: none; }
  td { padding: 1px 3px; border-bottom: 1px dotted #ccc; }
  td:first-child { font-weight: bold; white-space: nowrap; }
  code { font-size: 6.8pt; background: #eee; padding: 0 2px; border-radius: 1px; }
  p { margin: 1px 0; font-size: 6.8pt; }
  @media print { body { column-count: 3; } }
</style>

# CachyOS + KDE Plasma Cheatsheet

## KDE Plasma

### Launcher / Session

| | |
|---|---|
| `Meta` | App Launcher |
| `Meta 1-9` | Taskbar Entry |
| `Meta Q` | Activity Switcher |
| `Meta L` | Lock Session |
| `Ctrl Alt Del` | Logout |
| `Meta V` | Clipboard |

### Window Actions

| | |
|---|---|
| `Alt F4` | Close Window |
| `Meta PgUp/Dn` | Maximize / Minimize |
| `Meta Tab` | Walk Windows |
| `Meta`` ` `` | Cycle Same App |
| `Alt F3` | Window Ops Menu |

### Quick Tile

| | |
|---|---|
| `Meta Arrow` | Tile L/R/U/D |
| `Meta T` | Tile Editor |

### Move to Screen

| | |
|---|---|
| `Meta Shift Left/Right` | Prev/Next Screen |

### Virtual Desktops

| | |
|---|---|
| `Meta Ctrl Arrow` | Switch Desktop |
| `Meta F1-F4` | Jump to Desktop 1-4 |
| `Meta Ctrl Shift Arrow` | Send Window to Desktop |

### Overview

| | |
|---|---|
| `Meta W` | Overview |
| `Meta G` | Grid View |
| `Meta D` | Peek Desktop |
| `Meta F9/F10` | Present Current/All |

### Misc

| | |
|---|---|
| `Meta =/- /0` | Zoom In/Out/Reset |
| `Meta Ctrl Esc` | Kill Window |
| `Meta B` | Power Profile |

## Krohnkite Tiling

### Focus (vim)

| | |
|---|---|
| `Meta H/J/K` | Focus L/D/U |
| `Meta ,` | Focus Previous |

### Move

| | |
|---|---|
| `Meta Shift H/J/K/L` | Move L/D/U/R |

### Resize

| | |
|---|---|
| `Meta Ctrl H/L` | Shrink/Grow Width |
| `Meta Ctrl J/K` | Grow/Shrink Height |

### Layout / Float

| | |
|---|---|
| `Meta \ / \|` | Next/Prev Layout |
| `Meta M` | Monocle |
| `Meta Enter` | Set Master |
| `Meta F` | Toggle Float |
| `Meta Shift F` | Float All |

## Ghostty Terminal

### Tabs / Windows

| | |
|---|---|
| `Ctrl Shift T` | New Tab |
| `Ctrl 1-9` | Jump to Tab |
| `Ctrl Shift N` | New Window |
| `Ctrl Shift Q` | Quit |

### Splits

| | |
|---|---|
| `Ctrl Shift O` | Split Right |
| `Ctrl Shift E` | Split Down |
| `Ctrl Shift W` | Close Split |
| `Ctrl Shift [ / ]` | Prev/Next Split |
| `Ctrl Shift H/J/K/L` | Focus L/D/U/R Split |

### General

| | |
|---|---|
| `Ctrl Shift C/V` | Copy / Paste |
| `Ctrl Shift F` | Search |
| `Ctrl =/- /0` | Font Size +/-/Reset |

## Pacman / AUR

| | |
|---|---|
| `pacman -Syu` | System Upgrade |
| `pacman -S pkg` | Install |
| `pacman -Rs pkg` | Remove + Deps |
| `pacman -Ss query` | Search Repos |
| `pacman -Qi pkg` | Package Info |
| `pacman -F file` | Find Owner |
| `yay -S pkg` | AUR Install |
| `yay -Sua` | AUR Upgrade |

## Systemd / Journal

| | |
|---|---|
| `systemctl status unit` | Service Status |
| `systemctl enable --now` | Enable + Start |
| `systemctl restart unit` | Restart |
| `journalctl -b` | Current Boot Logs |
| `journalctl -u unit -f` | Follow Logs |
| `journalctl -p err -b` | Errors This Boot |

## Media

| | |
|---|---|
| `Vol Up/Down` | Volume |
| `Shift Vol Up/Down` | Volume 1% |
| `Mute / Meta Mute` | Speakers / Mic |
| `Brightness Up/Down` | Screen Brightness |
