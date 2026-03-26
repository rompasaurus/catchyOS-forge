# CachyOS + KDE Plasma Cheatsheet

Quick reference for keybindings and shortcuts configured on this system.
CachyOS (Arch) / KDE Plasma 6 / Wayland / Ghostty / Krohnkite tiling.

---

## KDE Plasma — Global

### Application Launcher & Taskbar

| Shortcut        | Action                          |
|-----------------|---------------------------------|
| `Meta`          | Open Application Launcher       |
| `Meta + 1–9`   | Activate Taskbar Entry 1–9      |
| `Meta + Q`     | Activity Switcher               |
| `Meta + A`     | Next Activity                   |
| `Meta + Shift + A` | Previous Activity           |

### Session

| Shortcut          | Action              |
|-------------------|----------------------|
| `Meta + L`        | Lock Session         |
| `Ctrl + Alt + Del`| Logout Screen        |
| `Meta + Shift + Esc` | Disable Input Capture |

### Clipboard

| Shortcut          | Action                            |
|-------------------|-----------------------------------|
| `Meta + V`        | Show Clipboard at Mouse Position  |
| `Meta + Ctrl + X` | Automatic Action Popup            |

---

## KDE Plasma — Window Management

### Quick Tile (built-in KDE)

| Shortcut        | Action              |
|-----------------|----------------------|
| `Meta + Left`   | Tile Left            |
| `Meta + Right`  | Tile Right           |
| `Meta + Up`     | Tile Top             |
| `Meta + Down`   | Tile Bottom          |
| `Meta + T`      | Toggle Tile Editor   |

### Window Actions

| Shortcut          | Action                    |
|-------------------|---------------------------|
| `Alt + F4`        | Close Window              |
| `Meta + PgUp`     | Maximize Window           |
| `Meta + PgDown`   | Minimize Window           |
| `Alt + F3`        | Window Operations Menu    |
| `Meta + Tab`      | Walk Through Windows      |
| `Meta + Shift + Tab` | Walk Through Windows (Reverse) |
| `Meta + \``       | Cycle Windows of Same App |

### Move Window to Screen

| Shortcut              | Action                     |
|-----------------------|----------------------------|
| `Meta + Shift + Left` | Move Window to Prev Screen |
| `Meta + Shift + Right`| Move Window to Next Screen |

### Virtual Desktops — Navigation

| Shortcut              | Action                    |
|-----------------------|---------------------------|
| `Meta + Ctrl + Left`  | Desktop Left              |
| `Meta + Ctrl + Right` | Desktop Right             |
| `Meta + Ctrl + Up`    | Desktop Up                |
| `Meta + Ctrl + Down`  | Desktop Down              |
| `Meta + F1–F4`        | Jump to Desktop 1–4       |

### Virtual Desktops — Move Window

| Shortcut                    | Action                         |
|-----------------------------|--------------------------------|
| `Meta + Ctrl + Shift + Left`  | Send Window Desktop Left    |
| `Meta + Ctrl + Shift + Right` | Send Window Desktop Right   |
| `Meta + Ctrl + Shift + Up`    | Send Window Desktop Up      |
| `Meta + Ctrl + Shift + Down`  | Send Window Desktop Down    |

### Overview & Expose

| Shortcut          | Action                              |
|-------------------|-------------------------------------|
| `Meta + W`        | Toggle Overview                     |
| `Meta + G`        | Toggle Grid View                    |
| `Meta + D`        | Peek at Desktop                     |
| `Ctrl + F12`      | Show Desktop (dashboard)            |
| `Meta + F9`       | Present Windows (Current Desktop)   |
| `Meta + F10`      | Present Windows (All Desktops)      |
| `Meta + F7`       | Present Windows (Same App)          |

### Zoom

| Shortcut        | Action           |
|-----------------|------------------|
| `Meta + =`      | Zoom In          |
| `Meta + -`      | Zoom Out         |
| `Meta + 0`      | Zoom Actual Size |

### Misc

| Shortcut            | Action                  |
|---------------------|-------------------------|
| `Meta + Ctrl + Esc` | Kill Window (xkill)     |
| `Meta + Ctrl + A`   | Activate Demanding Window |
| `Meta + F5`         | Move Mouse to Focus     |
| `Meta + F6`         | Move Mouse to Center    |
| `Meta + Alt + P`    | Cycle Panel Focus       |

---

## Krohnkite — Tiling Window Manager

### Focus (vim-style)

| Shortcut    | Action         |
|-------------|----------------|
| `Meta + H`  | Focus Left     |
| `Meta + J`  | Focus Down     |
| `Meta + K`  | Focus Up       |
| `Meta + ,`  | Focus Previous |

> **Note:** Focus Right is unbound.

### Move Windows

| Shortcut           | Action           |
|--------------------|------------------|
| `Meta + Shift + H` | Move Left        |
| `Meta + Shift + J` | Move Down / Next |
| `Meta + Shift + K` | Move Up / Prev   |
| `Meta + Shift + L` | Move Right       |

### Resize Windows

| Shortcut          | Action        |
|-------------------|---------------|
| `Meta + Ctrl + H` | Shrink Width  |
| `Meta + Ctrl + L` | Grow Width    |
| `Meta + Ctrl + J` | Grow Height   |
| `Meta + Ctrl + K` | Shrink Height |

### Layouts

| Shortcut     | Action          |
|--------------|-----------------|
| `Meta + \`   | Next Layout     |
| `Meta + \|`  | Previous Layout |
| `Meta + M`   | Monocle Layout  |

### Float

| Shortcut           | Action                         |
|--------------------|--------------------------------|
| `Meta + Enter`     | Set Master                     |
| `Meta + F`         | Toggle Float (current window)  |
| `Meta + Shift + F` | Toggle Float All               |

### Unbound (available to bind)

Tile, Columns, Spiral, Stair, Stacked, Spread, Quarter, BTree, Three Column layouts,
Increase/Decrease, Rotate, Rotate Part, Focus Next, Focus Right, Toggle Dock.

### Krohnkite Config

| Setting              | Value                                       |
|----------------------|---------------------------------------------|
| Gaps (all sides)     | 8px                                         |
| Gaps (between)       | 8px                                         |
| DP-2 override        | top=50, bottom=70 (panel compensation)      |
| Monocle maximize     | off                                         |
| Tile borders         | hidden                                      |
| Max tile width ratio | 2.6                                         |

---

## Ghostty — Terminal

### Tabs

| Shortcut          | Action         |
|-------------------|----------------|
| `Ctrl + Shift + T`| New Tab (default) |
| `Ctrl + 1–9`     | Jump to Tab 1–9 |

### Splits

| Shortcut              | Action                |
|-----------------------|-----------------------|
| `Ctrl + Shift + Enter`| New Split (default)   |
| `Ctrl + Shift + W`    | Close Split Pane      |

### Built-in Defaults

| Shortcut            | Action             |
|---------------------|--------------------|
| `Ctrl + Shift + C`  | Copy               |
| `Ctrl + Shift + V`  | Paste              |
| `Ctrl + Shift + N`  | New Window         |
| `Ctrl + Shift + Q`  | Quit               |
| `Ctrl + =`          | Increase Font Size |
| `Ctrl + -`          | Decrease Font Size |
| `Ctrl + 0`          | Reset Font Size    |
| `Ctrl + Shift + F`  | Search             |
| `Ctrl + Shift + A`  | Select All         |
| `Ctrl + Shift + O`  | Open Split Right   |
| `Ctrl + Shift + E`  | Open Split Down    |
| `Ctrl + Shift + [`  | Previous Split     |
| `Ctrl + Shift + ]`  | Next Split         |

> Shell: Zsh | Config: `~/.config/ghostty/config`

---

## Media & Volume

| Shortcut                 | Action                  |
|--------------------------|-------------------------|
| `Volume Up / Down`       | Volume                  |
| `Shift + Volume Up/Down` | Volume by 1%            |
| `Volume Mute`            | Mute                    |
| `Meta + Volume Mute`     | Mute Microphone         |
| `Media Play`             | Play / Pause            |
| `Media Next / Previous`  | Next / Previous Track   |
| `Media Rewind / FF`      | Seek 5s Back / Forward  |

---

## Power & Display

| Shortcut                    | Action              |
|-----------------------------|----------------------|
| `Monitor Brightness Up/Down`| Screen Brightness    |
| `Shift + Brightness Up/Down`| Brightness by 1%    |
| `Meta + B`                  | Switch Power Profile |

---

## CachyOS — Pacman Quick Reference

| Command                      | Action                        |
|------------------------------|-------------------------------|
| `sudo pacman -Syu`           | Full system upgrade           |
| `sudo pacman -S <pkg>`       | Install package               |
| `sudo pacman -Rs <pkg>`      | Remove package + deps         |
| `sudo pacman -Ss <query>`    | Search repos                  |
| `sudo pacman -Qi <pkg>`      | Package info (installed)      |
| `sudo pacman -Ql <pkg>`      | List files owned by package   |
| `pacman -F <file>`           | Find which package owns file  |
| `yay -S <pkg>`               | Install from AUR              |
| `yay -Sua`                   | Upgrade AUR packages          |
| `sudo pacman -Sc`            | Clean package cache           |
| `sudo pacman -Qtdq`          | List orphaned packages        |

---

## Systemd Quick Reference

| Command                           | Action                     |
|-----------------------------------|----------------------------|
| `systemctl status <unit>`         | Check service status       |
| `sudo systemctl start <unit>`     | Start service              |
| `sudo systemctl enable --now <unit>` | Enable + start service  |
| `sudo systemctl restart <unit>`   | Restart service            |
| `journalctl -b`                   | Logs from current boot     |
| `journalctl -b -1`               | Logs from previous boot    |
| `journalctl -u <unit> -f`        | Follow service logs live   |
| `journalctl -p err -b`           | Errors from current boot   |
| `systemctl --user status <unit>`  | User service status        |
