#!/usr/bin/env python3
"""
Hold mouse back button + move to switch KDE Plasma virtual desktops
and simulate 4-finger touchpad gestures.
Uses KWin's DBus interface for reliable desktop management.

Gestures:
  Back + swipe right → next desktop (creates new one if on last)
  Back + swipe left  → previous desktop
  Back + swipe up    → 4-finger swipe up (Overview)
  Back + swipe down  → 4-finger swipe down (Desktop Grid)
  Back click (no swipe) → normal back button
"""

import evdev
from evdev import ecodes, UInput
import select
import subprocess
import sys
import time

# --- Configuration ---
SWIPE_THRESHOLD = 300       # pixels of mouse movement to trigger switch
MOUSE_BACK_BUTTON = ecodes.BTN_SIDE  # back button (button 8 / code 275)
COOLDOWN = 0.4              # seconds between workspace switches
RESCAN_INTERVAL = 2.0       # seconds between device re-scans


def qdbus(*args):
    """Call qdbus6 and return stdout, or None on failure."""
    try:
        result = subprocess.run(
            ["qdbus6", *args],
            capture_output=True, text=True, timeout=2,
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def get_current_desktop():
    """Return the current desktop number (1-based)."""
    val = qdbus("org.kde.KWin", "/KWin", "currentDesktop")
    return int(val) if val else None


def get_desktop_count():
    """Return the total number of virtual desktops."""
    val = qdbus(
        "org.kde.KWin", "/VirtualDesktopManager",
        "org.freedesktop.DBus.Properties.Get",
        "org.kde.KWin.VirtualDesktopManager", "count",
    )
    return int(val) if val else None


def switch_desktop_right():
    """Move to the next desktop. If on the last one, create a new desktop first."""
    current = get_current_desktop()
    count = get_desktop_count()
    if current is None or count is None:
        return
    if current >= count:
        # On the last desktop — create a new one at the end
        qdbus(
            "org.kde.KWin", "/VirtualDesktopManager",
            "createDesktop", str(count), f"Desktop {count + 1}",
        )
        print(f"Created new desktop {count + 1}", file=sys.stderr)
    qdbus("org.kde.KWin", "/KWin", "nextDesktop")


def switch_desktop_left():
    """Move to the previous desktop."""
    qdbus("org.kde.KWin", "/KWin", "previousDesktop")


def toggle_overview():
    """Toggle KDE's Overview effect (like GNOME Activities)."""
    qdbus("org.kde.KWin", "/org/kde/KWin/Effects/overview", "toggle")


def toggle_desktop_grid():
    """Toggle KDE's Desktop Grid effect (4-finger swipe down equivalent)."""
    qdbus("org.kde.KWin", "/org/kde/KWin/Effects/desktopgrid", "toggle")


def create_uinput():
    """Create UInput for forwarding non-swiped events."""
    caps = {
        ecodes.EV_KEY: [
            ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE,
            ecodes.BTN_SIDE, ecodes.BTN_EXTRA,
        ],
        ecodes.EV_REL: [
            ecodes.REL_X, ecodes.REL_Y,
            ecodes.REL_WHEEL, ecodes.REL_HWHEEL,
            ecodes.REL_WHEEL_HI_RES, ecodes.REL_HWHEEL_HI_RES,
        ],
    }
    return UInput(caps, name="mouse (workspace-swipe proxy)")


def remove_device(fd, fd_to_dev):
    """Safely ungrab/close a disconnected device and remove from tracking."""
    dev = fd_to_dev.pop(fd, None)
    if dev is None:
        return
    print(f"Removed device: {dev.name} ({dev.path})", file=sys.stderr)
    try:
        dev.ungrab()
    except OSError:
        pass
    try:
        dev.close()
    except OSError:
        pass


def scan_and_add_devices(fd_to_dev):
    """Re-scan /dev/input/event*, skip already-tracked paths, grab new mice."""
    tracked_paths = {dev.path for dev in fd_to_dev.values()}
    for path in evdev.list_devices():
        if path in tracked_paths:
            continue
        try:
            dev = evdev.InputDevice(path)
        except OSError:
            continue
        if "workspace-swipe proxy" in dev.name:
            dev.close()
            continue
        caps = dev.capabilities()
        if ecodes.EV_REL in caps and ecodes.EV_KEY in caps:
            key_caps = caps.get(ecodes.EV_KEY, [])
            # Skip devices that have keyboard keys — they're keyboards,
            # not mice (e.g. Asus Keyboard exposes mouse-like caps)
            has_keyboard_keys = any(
                k in key_caps for k in (ecodes.KEY_A, ecodes.KEY_Z, ecodes.KEY_ESC)
            )
            if has_keyboard_keys:
                dev.close()
                continue
            if ecodes.BTN_LEFT in key_caps and MOUSE_BACK_BUTTON in key_caps:
                try:
                    dev.grab()
                except OSError:
                    dev.close()
                    continue
                fd_to_dev[dev.fd] = dev
                print(f"Added device: {dev.name} ({dev.path})", file=sys.stderr)
                continue
        dev.close()


def main():
    ui = create_uinput()
    fd_to_dev = {}

    scan_and_add_devices(fd_to_dev)
    if not fd_to_dev:
        print("No mouse with a back button found, waiting for one...", file=sys.stderr)

    back_held = False
    x_accum = 0
    y_accum = 0
    triggered = False
    last_switch = 0

    try:
        while True:
            if not fd_to_dev:
                time.sleep(RESCAN_INTERVAL)
                scan_and_add_devices(fd_to_dev)
                continue

            try:
                r, _, _ = select.select(fd_to_dev.keys(), [], [], RESCAN_INTERVAL)
            except OSError:
                bad_fds = []
                for fd in list(fd_to_dev):
                    try:
                        select.select([fd], [], [], 0)
                    except OSError:
                        bad_fds.append(fd)
                for fd in bad_fds:
                    remove_device(fd, fd_to_dev)
                back_held = False
                x_accum = 0
                y_accum = 0
                triggered = False
                continue

            if not r:
                scan_and_add_devices(fd_to_dev)
                continue

            for fd in r:
                dev = fd_to_dev.get(fd)
                if dev is None:
                    continue
                try:
                    events = list(dev.read())
                except OSError:
                    remove_device(fd, fd_to_dev)
                    back_held = False
                    x_accum = 0
                    y_accum = 0
                    triggered = False
                    continue

                for event in events:
                    if event.type == ecodes.EV_KEY and event.code == MOUSE_BACK_BUTTON:
                        if event.value == 1:  # pressed
                            back_held = True
                            x_accum = 0
                            y_accum = 0
                            triggered = False
                        elif event.value == 0:  # released
                            back_held = False
                            if not triggered:
                                ui.write(ecodes.EV_KEY, MOUSE_BACK_BUTTON, 1)
                                ui.write(ecodes.EV_SYN, ecodes.SYN_REPORT, 0)
                                ui.write(ecodes.EV_KEY, MOUSE_BACK_BUTTON, 0)
                                ui.write(ecodes.EV_SYN, ecodes.SYN_REPORT, 0)
                            x_accum = 0
                            y_accum = 0
                            triggered = False
                        continue

                    if back_held and event.type == ecodes.EV_REL:
                        if event.code == ecodes.REL_X:
                            x_accum += event.value
                        elif event.code == ecodes.REL_Y:
                            y_accum += event.value

                        now = time.time()
                        if not triggered and (now - last_switch) > COOLDOWN:
                            if x_accum > SWIPE_THRESHOLD:
                                switch_desktop_right()
                                triggered = True
                                last_switch = now
                                x_accum = 0
                                y_accum = 0
                            elif x_accum < -SWIPE_THRESHOLD:
                                switch_desktop_left()
                                triggered = True
                                last_switch = now
                                x_accum = 0
                                y_accum = 0
                            elif y_accum < -SWIPE_THRESHOLD:  # up
                                toggle_overview()
                                triggered = True
                                last_switch = now
                                x_accum = 0
                                y_accum = 0
                            elif y_accum > SWIPE_THRESHOLD:  # down
                                toggle_desktop_grid()
                                triggered = True
                                last_switch = now
                                x_accum = 0
                                y_accum = 0

                        if abs(x_accum) > 30 or abs(y_accum) > 30:
                            continue

                    # Forward all other events
                    ui.write(event.type, event.code, event.value)

    except KeyboardInterrupt:
        pass
    finally:
        for fd in list(fd_to_dev):
            try:
                fd_to_dev[fd].ungrab()
            except OSError:
                pass
        ui.close()
        print("Stopped.", file=sys.stderr)


if __name__ == "__main__":
    main()
