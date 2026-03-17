#!/usr/bin/env python3
"""
Hold mouse back button + move to switch KDE Plasma virtual desktops.
Uses KWin's DBus interface for reliable desktop management.

Gestures:
  Back + swipe right → next desktop (creates new one if on last)
  Back + swipe left  → previous desktop
  Back click (no swipe) → toggle Overview (desktops & apps view)
"""

import evdev
from evdev import ecodes, UInput
import os
import select
import subprocess
import sys
import time

# --- Configuration ---
SWIPE_THRESHOLD = 200       # pixels of mouse movement to trigger switch
COOLDOWN = 0.3              # seconds between workspace switches
RESCAN_INTERVAL = 2.0       # seconds between device re-scans

# All possible "back" button codes — different mice use different ones
BACK_BUTTON_CODES = {ecodes.BTN_SIDE, ecodes.BTN_EXTRA, ecodes.BTN_BACK, ecodes.BTN_FORWARD}


def find_qdbus():
    """Find qdbus6 or qdbus binary."""
    for cmd in ("qdbus6", "qdbus"):
        for d in os.environ.get("PATH", "/usr/bin").split(":"):
            if os.path.isfile(os.path.join(d, cmd)):
                return cmd
    return None

QDBUS_CMD = find_qdbus()


def qdbus(*args):
    """Call qdbus6/qdbus and return stdout, or None on failure."""
    if QDBUS_CMD is None:
        return None
    try:
        result = subprocess.run(
            [QDBUS_CMD, *args],
            capture_output=True, text=True, timeout=2,
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def get_current_desktop():
    """Return the current desktop number (1-based)."""
    val = qdbus("org.kde.KWin", "/KWin", "currentDesktop")
    try:
        return int(val) if val else None
    except ValueError:
        return None


def get_desktop_count():
    """Return the total number of virtual desktops."""
    val = qdbus(
        "org.kde.KWin", "/VirtualDesktopManager",
        "org.freedesktop.DBus.Properties.Get",
        "org.kde.KWin.VirtualDesktopManager", "count",
    )
    try:
        return int(val) if val else None
    except ValueError:
        return None


def switch_desktop_right():
    """Move to the next desktop. If on the last one, create a new desktop first."""
    current = get_current_desktop()
    count = get_desktop_count()
    if current is None or count is None:
        print(f"DBus error: current={current}, count={count}", file=sys.stderr)
        return
    if current >= count:
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
    """Toggle KDE's Overview effect (desktops & apps view)."""
    qdbus(
        "org.kde.kglobalaccel", "/component/kwin",
        "org.kde.kglobalaccel.Component.invokeShortcut", "Overview",
    )


def create_uinput():
    """Create UInput for forwarding non-swiped events."""
    caps = {
        ecodes.EV_KEY: [
            ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE,
            ecodes.BTN_SIDE, ecodes.BTN_EXTRA, ecodes.BTN_BACK, ecodes.BTN_FORWARD,
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


def find_back_button(key_caps):
    """Find which back button code this device supports. Return the code or None."""
    for code in BACK_BUTTON_CODES:
        if code in key_caps:
            return code
    return None


def scan_and_add_devices(fd_to_dev, dev_back_buttons):
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
        # Must have relative axes (mouse movement) and key events
        if ecodes.EV_REL not in caps or ecodes.EV_KEY not in caps:
            dev.close()
            continue
        key_caps = caps.get(ecodes.EV_KEY, [])
        rel_caps = caps.get(ecodes.EV_REL, [])
        # Must have mouse movement (REL_X) and left click
        if ecodes.REL_X not in rel_caps or ecodes.BTN_LEFT not in key_caps:
            dev.close()
            continue
        # Must have at least one back/side button
        back_btn = find_back_button(key_caps)
        if back_btn is None:
            dev.close()
            continue
        try:
            dev.grab()
        except OSError:
            dev.close()
            continue
        fd_to_dev[dev.fd] = dev
        dev_back_buttons[dev.fd] = back_btn
        btn_name = ecodes.BTN.get(back_btn, str(back_btn))
        print(f"Added device: {dev.name} ({dev.path}) back_btn={btn_name}({back_btn})", file=sys.stderr)


def main():
    print(f"Starting mouse-workspace-swipe (qdbus={QDBUS_CMD})", file=sys.stderr)
    ui = create_uinput()
    fd_to_dev = {}
    dev_back_buttons = {}  # fd -> back button code for that device

    scan_and_add_devices(fd_to_dev, dev_back_buttons)
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
                scan_and_add_devices(fd_to_dev, dev_back_buttons)
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
                    dev_back_buttons.pop(fd, None)
                    remove_device(fd, fd_to_dev)
                back_held = False
                x_accum = 0
                y_accum = 0
                triggered = False
                continue

            if not r:
                scan_and_add_devices(fd_to_dev, dev_back_buttons)
                continue

            for fd in r:
                dev = fd_to_dev.get(fd)
                if dev is None:
                    continue
                back_btn = dev_back_buttons.get(fd, ecodes.BTN_SIDE)
                try:
                    events = list(dev.read())
                except OSError:
                    dev_back_buttons.pop(fd, None)
                    remove_device(fd, fd_to_dev)
                    back_held = False
                    x_accum = 0
                    y_accum = 0
                    triggered = False
                    continue

                for event in events:
                    # Check if this is ANY back/side button on this device
                    if event.type == ecodes.EV_KEY and event.code in BACK_BUTTON_CODES:
                        if event.value == 1:  # pressed
                            back_held = True
                            x_accum = 0
                            y_accum = 0
                            triggered = False
                        elif event.value == 0:  # released
                            back_held = False
                            if not triggered:
                                # No swipe detected — toggle Overview
                                toggle_overview()
                                print("Back click → Overview", file=sys.stderr)
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
                                print("Swipe right → next desktop", file=sys.stderr)
                            elif x_accum < -SWIPE_THRESHOLD:
                                switch_desktop_left()
                                triggered = True
                                last_switch = now
                                print("Swipe left → prev desktop", file=sys.stderr)

                        # Suppress mouse movement while back is held
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
