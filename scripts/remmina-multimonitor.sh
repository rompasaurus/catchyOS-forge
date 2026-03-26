#!/usr/bin/env bash
# Launch Remmina with multi-monitor support on Wayland (KDE Plasma)
#
# FreeRDP multi-monitor is broken on Wayland+KDE (upstream bug):
#   https://github.com/FreeRDP/FreeRDP/issues/10430
#   https://gitlab.com/Remmina/Remmina/-/issues/2644
#
# This script forces an X11 session for Remmina via XWayland.
# If this still doesn't work, log into Plasma (X11) at SDDM instead.

set -euo pipefail

if [ "$XDG_SESSION_TYPE" = "x11" ]; then
    echo "Already on X11, launching Remmina normally..."
    exec remmina "$@"
fi

echo "Wayland detected — launching Remmina under XWayland..."
exec env GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb remmina "$@"
