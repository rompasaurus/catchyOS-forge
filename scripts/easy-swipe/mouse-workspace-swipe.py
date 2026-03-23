#!/usr/bin/env python3
"""
Hold mouse back button + move to switch KDE Plasma virtual desktops.
Uses KWin's DBus interface for reliable desktop management.

Gestures:
  Back + swipe right → next desktop (wraps to first if on last)
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


def dbus_call(dest, path, method, args=None):
    """Call a DBus method via dbus-send. Returns stdout on success, None on failure."""
    cmd = ["dbus-send", "--session", "--print-reply", f"--dest={dest}", path, method]
    if args:
        cmd.extend(args)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
        if result.returncode != 0:
            return None
        return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def get_current_desktop():
    """Return the current desktop number (1-based)."""
    out = dbus_call(
        "org.kde.KWin", "/KWin", "org.kde.KWin.currentDesktop",
    )
    if out is None:
        return None
    try:
        for line in out.splitlines():
            line = line.strip()
            if "int32" in line:
                return int(line.split()[-1])
    except ValueError:
        pass
    return None


def get_desktop_count():
    """Return the total number of virtual desktops."""
    out = dbus_call(
        "org.kde.KWin", "/VirtualDesktopManager",
        "org.freedesktop.DBus.Properties.Get",
        ["string:org.kde.KWin.VirtualDesktopManager", "string:count"],
    )
    if out is None:
        return None
    try:
        for line in out.splitlines():
            line = line.strip()
            if "uint32" in line:
                return int(line.split()[-1])
    except ValueError:
        pass
    return None


def switch_desktop_right():
    """Move to the next desktop, wrapping around to the first if on the last."""
    current = get_current_desktop()
    count = get_desktop_count()
    if current is None or count is None:
        print(f"DBus error: current={current}, count={count}", file=sys.stderr)
        return
    if current >= count:
        dbus_call("org.kde.KWin", "/KWin", "org.kde.KWin.setCurrentDesktop",
                   ["int32:1"])
    else:
        dbus_call("org.kde.KWin", "/KWin", "org.kde.KWin.nextDesktop")


def switch_desktop_left():
    """Move to the previous desktop."""
    dbus_call("org.kde.KWin", "/KWin", "org.kde.KWin.previousDesktop")


def toggle_overview():
    """Toggle KDE's Overview effect (desktops & apps view)."""
    dbus_call(
        "org.kde.kglobalaccel", "/component/kwin",
        "org.kde.kglobalaccel.Component.invokeShortcut",
        ["string:Overview"],
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


def is_keyboard_or_touchpad(dev):
    """Return True if the device looks like a keyboard or touchpad, not a mouse."""
    name_lower = dev.name.lower()
    # Skip anything that identifies as a keyboard, touchpad, or trackpad
    skip_keywords = ("keyboard", "touchpad", "trackpad", "trackpoint", "lid switch",
                     "power button", "video bus", "pc speaker")
    if any(kw in name_lower for kw in skip_keywords):
        return True
    caps = dev.capabilities()
    key_caps = set(caps.get(ecodes.EV_KEY, []))
    # If the device has alphabetic keys, it's a keyboard (or keyboard combo device)
    keyboard_keys = {ecodes.KEY_A, ecodes.KEY_Z, ecodes.KEY_SPACE, ecodes.KEY_ENTER}
    if keyboard_keys & key_caps:
        return True
    # If it has absolute axes (ABS_X/ABS_Y) it's likely a touchpad, not a mouse
    abs_caps = set(caps.get(ecodes.EV_ABS, []))
    if ecodes.ABS_X in abs_caps or ecodes.ABS_MT_POSITION_X in abs_caps:
        return True
    return False


def scan_and_add_devices(fd_to_dev, dev_back_buttons, seen_paths=set()):
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
        # Skip keyboards, touchpads, and combo devices
        if is_keyboard_or_touchpad(dev):
            if path not in seen_paths:
                print(f"Skipping non-mouse: {dev.name} ({dev.path})", file=sys.stderr)
                seen_paths.add(path)
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
    print("Starting mouse-workspace-swipe (dbus-send)", file=sys.stderr)
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
