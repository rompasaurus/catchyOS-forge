#!/bin/bash
# Setup Blu-ray playback support for VLC on CachyOS (Arch-based)
# Includes MakeMKV + libaacs emulation for modern DRM decryption
# Creates a pinnable Blu-Ray Player launcher with custom icon

set -euo pipefail

echo "=== Installing VLC and Blu-ray libraries ==="
sudo pacman -S --needed --noconfirm vlc libbluray jre-openjdk

echo ""
echo "=== Adding user to optical group ==="
if ! id -nG | grep -qw optical; then
    sudo usermod -aG optical "$USER"
    echo "Added $USER to optical group (takes effect after logout)."
else
    echo "Already in optical group."
fi

echo ""
echo "=== Installing MakeMKV + libaacs emulation ==="

# Remove stock libaacs if installed as its own package (not as a provides)
# pacman -Q checks exact names; makemkv-libaacs provides libaacs but has a different pkg name
if pacman -Qq libaacs 2>/dev/null | grep -qx libaacs; then
    echo "Removing stock libaacs (makemkv-libaacs will replace it)..."
    sudo pacman -Rdd --noconfirm libaacs
fi

if command -v yay &>/dev/null; then
    yay -S --needed --noconfirm makemkv makemkv-libaacs
elif command -v paru &>/dev/null; then
    paru -S --needed --noconfirm makemkv makemkv-libaacs
else
    echo "No AUR helper found. Install makemkv and makemkv-libaacs manually from the AUR."
fi

echo ""
echo "=== Configuring MakeMKV beta key ==="
# MakeMKV requires a registration key for its libaacs emulation to work.
# The free beta key is published at: https://forum.makemkv.com/forum/viewtopic.php?t=1053
MAKEMKV_KEY="T-URt6MHxNy3HmfVojU8pE05WQ6HfgVI8S@HiIeNcWFim9rBgNlOdLFROSATCsWikcKW"

mkdir -p ~/.MakeMKV
if [ -f ~/.MakeMKV/settings.conf ] && grep -q "app_Key" ~/.MakeMKV/settings.conf; then
    # Update existing key
    sed -i "s|^app_Key = .*|app_Key = \"$MAKEMKV_KEY\"|" ~/.MakeMKV/settings.conf
    echo "Updated MakeMKV beta key."
else
    # Create or append key
    echo "app_Key = \"$MAKEMKV_KEY\"" >> ~/.MakeMKV/settings.conf
    echo "Installed MakeMKV beta key."
fi

echo ""
echo "=== Installing fallback decryption keys ==="
mkdir -p ~/.config/aacs

KEYDB_INSTALLED=false

# Try FindVUK database (maintained community key database)
echo "Trying FindVUK KEYDB source..."
if wget -q --timeout=15 -O /tmp/keydb_test.cfg \
    "https://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg" 2>/dev/null; then
    # Only use if download is non-trivial (> 100KB suggests a real database)
    if [ "$(stat -c%s /tmp/keydb_test.cfg 2>/dev/null || echo 0)" -gt 100000 ]; then
        mv /tmp/keydb_test.cfg ~/.config/aacs/KEYDB.cfg
        echo "KEYDB installed from FindVUK."
        KEYDB_INSTALLED=true
    fi
fi
rm -f /tmp/keydb_test.cfg

# Try git repo fallback
if [ "$KEYDB_INSTALLED" = false ]; then
    echo "Primary source failed. Trying git repo fallback..."
    rm -rf /tmp/libaacs-keys
    if git clone --depth 1 https://github.com/psr/libaacs-keys.git /tmp/libaacs-keys 2>/dev/null; then
        if [ -f /tmp/libaacs-keys/KEYDB.cfg ]; then
            cp /tmp/libaacs-keys/KEYDB.cfg ~/.config/aacs/KEYDB.cfg
            echo "KEYDB installed from git repo."
            KEYDB_INSTALLED=true
        fi
        rm -rf /tmp/libaacs-keys
    fi
fi

if [ "$KEYDB_INSTALLED" = false ]; then
    echo "NOTE: Could not download fresh KEYDB.cfg."
    if [ -f ~/.config/aacs/KEYDB.cfg ]; then
        echo "Keeping existing KEYDB.cfg (may be outdated)."
    else
        echo "No KEYDB.cfg found — MakeMKV libaacs emulation will handle decryption."
    fi
fi

echo ""
echo "=== Setting up Java for BD-J menus ==="
# libbluray needs JAVA_HOME to find the JVM for Blu-ray Java menus
JAVA_HOME_DIR=$(dirname "$(dirname "$(readlink -f /usr/bin/java)")")
if [ -d "$JAVA_HOME_DIR" ]; then
    # Create libbluray expects: /usr/share/java/libbluray/ with the right jars
    # Set JAVA_HOME in profile so VLC/libbluray can find it
    PROFILE_LINE="export JAVA_HOME=\"$JAVA_HOME_DIR\""
    if ! grep -qF "JAVA_HOME" ~/.profile 2>/dev/null; then
        echo "$PROFILE_LINE" >> ~/.profile
        echo "Added JAVA_HOME=$JAVA_HOME_DIR to ~/.profile"
    else
        echo "JAVA_HOME already set in ~/.profile"
    fi
    export JAVA_HOME="$JAVA_HOME_DIR"
else
    echo "WARNING: Could not determine JAVA_HOME."
fi

echo ""
echo "=== Verifying libaacs symlink ==="
# makemkv-libaacs should create this, but verify it
if [ -L /usr/lib/libaacs.so.0 ]; then
    target=$(readlink /usr/lib/libaacs.so.0)
    echo "libaacs.so.0 -> $target (OK)"
else
    echo "WARNING: /usr/lib/libaacs.so.0 symlink missing."
    echo "Try reinstalling makemkv-libaacs."
fi

echo ""
echo "=== Creating Blu-Ray Player launcher ==="

# Create icon
mkdir -p ~/.local/share/icons
cat > ~/.local/share/icons/bluray-player.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <circle cx="64" cy="64" r="60" fill="#1a1a2e"/>
  <circle cx="64" cy="64" r="58" fill="url(#discGrad)" stroke="#0077cc" stroke-width="1.5"/>
  <circle cx="64" cy="64" r="48" fill="none" stroke="#0055aa" stroke-width="0.5" opacity="0.4"/>
  <circle cx="64" cy="64" r="40" fill="none" stroke="#0055aa" stroke-width="0.5" opacity="0.3"/>
  <circle cx="64" cy="64" r="32" fill="none" stroke="#0055aa" stroke-width="0.5" opacity="0.3"/>
  <ellipse cx="45" cy="40" rx="30" ry="20" fill="url(#shine)" opacity="0.15"/>
  <circle cx="64" cy="64" r="12" fill="#111"/>
  <circle cx="64" cy="64" r="10" fill="#222" stroke="#0077cc" stroke-width="1"/>
  <circle cx="64" cy="64" r="6" fill="#0a0a15"/>
  <text x="64" y="84" text-anchor="middle" font-family="Arial, sans-serif" font-weight="bold" font-size="11" fill="#00aaff" opacity="0.9">BLU-RAY</text>
  <polygon points="58,50 58,38 70,44" fill="#00aaff" opacity="0.8"/>
  <defs>
    <radialGradient id="discGrad" cx="40%" cy="35%">
      <stop offset="0%" stop-color="#1a3a5c"/>
      <stop offset="50%" stop-color="#0d1b2a"/>
      <stop offset="100%" stop-color="#1a1a2e"/>
    </radialGradient>
    <radialGradient id="shine" cx="50%" cy="50%">
      <stop offset="0%" stop-color="#66bbff"/>
      <stop offset="100%" stop-color="#66bbff" stop-opacity="0"/>
    </radialGradient>
  </defs>
</svg>
SVGEOF

# Create wrapper script that sets env and launches VLC
mkdir -p ~/.local/bin
cat > ~/.local/bin/bluray-play << 'SCRIPTEOF'
#!/bin/bash
# Blu-Ray Player launcher
# Sets environment for libaacs decryption and Java BD-J menus

export LIBAACS_PATH=/usr/lib/libaacs.so.0
JAVA_DIR=$(dirname "$(dirname "$(readlink -f /usr/bin/java)")")
[ -d "$JAVA_DIR" ] && export JAVA_HOME="$JAVA_DIR"

# Use --no-bluray-menu to skip BD-J Java menus which often hang VLC.
# Play the main title directly instead.
exec vlc --no-bluray-menu bluray:///dev/sr0
SCRIPTEOF
chmod +x ~/.local/bin/bluray-play

# Create desktop launcher
cat > ~/.local/share/applications/bluray-player.desktop << DESKEOF
[Desktop Entry]
Name=Blu-Ray Player
Comment=Play Blu-Ray disc with VLC
Exec=$HOME/.local/bin/bluray-play
Icon=$HOME/.local/share/icons/bluray-player.svg
Terminal=false
Type=Application
Categories=AudioVideo;Video;Player;
Keywords=bluray;blu-ray;disc;movie;
StartupWMClass=vlc
StartupNotify=true
DESKEOF

update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

echo "Launcher created! Search 'Blu-Ray Player' in your app menu."

echo ""
echo "=== Done! ==="
echo ""
echo "To play a Blu-ray disc:"
echo "  1. Click the Blu-Ray Player icon in your app menu"
echo "  2. Or run: ~/.local/bin/bluray-play"
echo "  3. For stubborn discs, open in MakeMKV first to rip, then play the file"
echo ""
echo "The launcher skips BD-J Java menus (which often hang VLC) and plays the"
echo "main title directly. If you need disc menus, run:"
echo "  vlc bluray:///dev/sr0"
