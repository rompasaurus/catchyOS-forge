/*
KWin Script Window Gaps — Plasma 6 port
Originally (C) 2021-2022 Natalie Clarius <natalie_clarius@yahoo.de>
Ported to KWin 6 API
GNU General Public License v3.0
*/

///////////////////////
// configuration
///////////////////////
const gap = {
    left:   readConfig("gapLeft",   16),
    right:  readConfig("gapRight",  16),
    top:    readConfig("gapTop",    16),
    bottom: readConfig("gapBottom", 16),
    mid:    readConfig("gapMid",    16)
};

const panels = {
    left:   readConfig("panelLeft",   false),
    right:  readConfig("panelRight",  false),
    top:    readConfig("panelTop",    false),
    bottom: readConfig("panelBottom", false),
};

const config = {
    includeMaximized: readConfig("includeMaximized", false),
    excludeMode:      readConfig("excludeMode", true),
    includeMode:      readConfig("includeMode", false),
    applications:     readConfig("applications", "").toLowerCase().split("\n")
};

const debugMode = readConfig("debugMode", false);

function debug(...args) {
    if (debugMode) console.debug("tilegaps:", ...args);
}

debug("initializing");
debug("gaps (l/r/t/b/mid):", gap.left, gap.right, gap.top, gap.bottom, gap.mid);
debug("panels (l/r/t/b):", panels.left, panels.right, panels.top, panels.bottom);

///////////////////////
// KWin 6 compat
///////////////////////

// KWin 6 renamed clientList -> windowList, clientAdded -> windowAdded, etc.
const getWindowList = workspace.windowList
    ? () => workspace.windowList()
    : () => workspace.clientList();

const windowAddedSignal = workspace.windowAdded || workspace.clientAdded;

const getArea = (win) => {
    // KWin 6: workspace.clientArea(type, window, desktop)
    // Some builds use the output object, some use the window
    try {
        return workspace.clientArea(KWin.MaximizeArea, win.output, win.desktops[0] || workspace.currentDesktop);
    } catch(e) {
        try {
            return workspace.clientArea(KWin.MaximizeArea, win);
        } catch(e2) {
            return workspace.clientArea(0, win);
        }
    }
};

///////////////////////
// block re-entry
///////////////////////
var block = false;

///////////////////////
// set up triggers
///////////////////////

getWindowList().forEach(win => onAdded(win));
windowAddedSignal.connect(onAdded);

function onAdded(win) {
    if (!win) return;
    debug("added", win.caption);
    applyGaps(win);

    // KWin 6 signals
    const connectSig = (sig, label) => {
        if (sig) sig.connect(() => {
            debug(label, win.caption);
            applyGaps(win);
        });
    };

    connectSig(win.moveResizedChanged,            "moveResizedChanged");
    connectSig(win.frameGeometryChanged,           "frameGeometryChanged");
    connectSig(win.clientFinishUserMovedResized || win.interactiveMoveResizeFinished,
                                                   "finishMoveResize");
    connectSig(win.fullScreenChanged,              "fullScreenChanged");
    connectSig(win.maximizedChanged || win.clientMaximizedStateChanged,
                                                   "maximizedChanged");
    connectSig(win.clientUnminimized || win.unminimized,
                                                   "unminimized");
    connectSig(win.screenChanged || win.outputChanged,
                                                   "screenChanged");
    connectSig(win.desktopChanged || win.desktopsChanged,
                                                   "desktopChanged");
}

function applyGapsAll() {
    getWindowList().forEach(win => applyGaps(win));
}

// Re-apply on layout changes
const layoutSignals = [
    workspace.currentDesktopChanged,
    workspace.desktopPresenceChanged,
    workspace.numberDesktopsChanged,
    workspace.numberScreensChanged  || workspace.outputAdded,
    workspace.screenResized         || workspace.outputRemoved,
    workspace.currentActivityChanged,
    workspace.virtualScreenSizeChanged,
    workspace.virtualScreenGeometryChanged,
];
layoutSignals.forEach(sig => {
    if (sig) sig.connect(applyGapsAll);
});

///////////////////////
// apply gaps
///////////////////////

function applyGaps(win) {
    if (block || !win || ignoreClient(win)) return;
    block = true;
    debug("--- gaps for", win.caption, "---");
    applyGapsArea(win);
    applyGapsWindows(win);
    block = false;
}

function isMaximized(win) {
    let area = getArea(win);
    let fg = win.frameGeometry;
    return Math.abs(fg.x - area.x) < 2
        && Math.abs(fg.y - area.y) < 2
        && Math.abs(fg.width - area.width) < 2
        && Math.abs(fg.height - area.height) < 2;
}

function applyGapsArea(win) {
    let area = getArea(win);
    let grid = getGrid(win, area);
    let anchored = {left: false, right: false, top: false, bottom: false};

    // KWin 6: frameGeometry is a QRect, copy its properties
    let fg = win.frameGeometry;
    let gridded = {x: fg.x, y: fg.y, width: fg.width, height: fg.height};
    let edged   = {x: fg.x, y: fg.y, width: fg.width, height: fg.height};

    if (config.includeMaximized && isMaximized(win)) {
        debug("unmaximize");
        win.setMaximize(false, false);
    }

    for (let edge of Object.keys(grid)) {
        for (let pos of Object.keys(grid[edge])) {
            let coords = grid[edge][pos];
            let winCoord;
            switch(edge) {
                case "left":   winCoord = fg.x; break;
                case "right":  winCoord = fg.x + fg.width; break;
                case "top":    winCoord = fg.y; break;
                case "bottom": winCoord = fg.y + fg.height; break;
            }
            if (nearArea(winCoord, coords.closed, coords.gapped, gap[edge] || gap.mid)) {
                anchored[edge] = true;
                let diff = coords.gapped - winCoord;
                switch(edge) {
                    case "left":
                        gridded.width -= diff; gridded.x += diff;
                        if (pos.startsWith("full")) { edged.width -= diff; edged.x += diff; }
                        break;
                    case "right":
                        gridded.width += diff;
                        if (pos.startsWith("full")) { edged.width += diff; }
                        break;
                    case "top":
                        gridded.height -= diff; gridded.y += diff;
                        if (pos.startsWith("full")) { edged.height -= diff; edged.y += diff; }
                        break;
                    case "bottom":
                        gridded.height += diff;
                        if (pos.startsWith("full")) { edged.height += diff; }
                        break;
                }
                break;
            }
        }
    }

    let allAnchored = Object.keys(anchored).every(e => anchored[e]);
    let target = allAnchored ? gridded : edged;

    if (fg.x !== target.x || fg.y !== target.y ||
        fg.width !== target.width || fg.height !== target.height) {
        debug("set geometry", JSON.stringify(target));
        win.frameGeometry = {x: target.x, y: target.y, width: target.width, height: target.height};
    }
}

function applyGapsWindows(win1) {
    let fg1 = win1.frameGeometry;
    let w1 = {x: fg1.x, y: fg1.y, width: fg1.width, height: fg1.height,
              left: fg1.x, right: fg1.x + fg1.width, top: fg1.y, bottom: fg1.y + fg1.height};

    let windows = getWindowList();
    for (let i = 0; i < windows.length; i++) {
        let win2 = windows[i];
        if (!win2 || ignoreOther(win1, win2)) continue;

        let fg2 = win2.frameGeometry;
        let w2 = {x: fg2.x, y: fg2.y, width: fg2.width, height: fg2.height,
                  left: fg2.x, right: fg2.x + fg2.width, top: fg2.y, bottom: fg2.y + fg2.height};

        // Left edge of win1 near right edge of win2
        if (nearWindow(w1.left, w2.right, gap.mid) && overlapVer(w1, w2)) {
            let diff = w1.left - w2.right;
            w1.x = w1.x - halfL(diff) + halfGapU();
            w1.width = w1.width + halfL(diff) - halfGapU();
            w2.width = w2.width + halfU(diff) - halfGapL();
        }
        // Right edge of win1 near left edge of win2
        if (nearWindow(w2.left, w1.right, gap.mid) && overlapVer(w1, w2)) {
            let diff = w2.left - (w1.right + 1);
            w1.width = w1.width + halfU(diff) - halfGapL();
            w2.x = w2.x - halfL(diff) + halfGapU();
            w2.width = w2.width + halfL(diff) - halfGapU();
        }
        // Top edge of win1 near bottom edge of win2
        if (nearWindow(w1.top, w2.bottom, gap.mid) && overlapHor(w1, w2)) {
            let diff = w1.top - w2.bottom;
            w1.y = w1.y - halfL(diff) + halfGapU();
            w1.height = w1.height + halfL(diff) - halfGapU();
            w2.height = w2.height + halfU(diff) - halfGapL();
        }
        // Bottom edge of win1 near top edge of win2
        if (nearWindow(w2.top, w1.bottom, gap.mid) && overlapHor(w1, w2)) {
            let diff = w2.top - (w1.bottom + 1);
            w1.height = w1.height + halfU(diff) - halfGapL();
            w2.y = w2.y - halfL(diff) + halfGapU();
            w2.height = w2.height + halfL(diff) - halfGapU();
        }

        if (fg2.x !== w2.x || fg2.y !== w2.y || fg2.width !== w2.width || fg2.height !== w2.height) {
            win2.frameGeometry = {x: w2.x, y: w2.y, width: w2.width, height: w2.height};
        }
    }

    if (fg1.x !== w1.x || fg1.y !== w1.y || fg1.width !== w1.width || fg1.height !== w1.height) {
        win1.frameGeometry = {x: w1.x, y: w1.y, width: w1.width, height: w1.height};
    }
}


///////////////////////
// grid
///////////////////////

function getGrid(win, area) {
    let unmax = !isMaximized(win);
    return {
        left: {
            fullLeft:       { closed: Math.round(area.x),
                              gapped: Math.round(area.x + gap.left - (panels.left && unmax ? gap.left : 0)) },
            halfHorizontal: { closed: Math.round(area.x + area.width / 2),
                              gapped: Math.round(area.x + (area.width + gap.left - gap.right + gap.mid) / 2) },
        },
        right: {
            halfHorizontal: { closed: Math.round(area.x + area.width / 2),
                              gapped: Math.round(area.x + area.width - (area.width + gap.left - gap.right + gap.mid) / 2) },
            fullRight:      { closed: Math.round(area.x + area.width),
                              gapped: Math.round(area.x + area.width - gap.right + (panels.right && unmax ? gap.right : 0)) },
        },
        top: {
            fullTop:        { closed: Math.round(area.y),
                              gapped: Math.round(area.y + gap.top - (panels.top && unmax ? gap.top : 0)) },
            halfVertical:   { closed: Math.round(area.y + area.height / 2),
                              gapped: Math.round(area.y + (area.height + gap.top - gap.bottom + gap.mid) / 2) },
        },
        bottom: {
            halfVertical:   { closed: Math.round(area.y + area.height / 2),
                              gapped: Math.round(area.y + area.height - (area.height + gap.top - gap.bottom + gap.mid) / 2) },
            fullBottom:     { closed: Math.round(area.y + area.height),
                              gapped: Math.round(area.y + area.height - gap.bottom + (panels.bottom && unmax ? gap.bottom : 0)) },
        }
    };
}


///////////////////////
// geometry helpers
///////////////////////

function nearArea(actual, expected_closed, expected_gapped, tolerance) {
    return (Math.abs(actual - expected_closed) <= tolerance
         || Math.abs(actual - expected_gapped) <= tolerance);
}

function nearWindow(a, b, gapSize) {
    return a - b <= gapSize && a - b >= 0 && a - b != gapSize;
}

function overlapHor(w1, w2) {
    let tol = 2 * gap.mid;
    return (w1.left <= w2.left + tol && w1.right > w2.left + tol)
        || (w2.left <= w1.left + tol && w2.right + tol > w1.left);
}

function overlapVer(w1, w2) {
    let tol = 2 * gap.mid;
    return (w1.top <= w2.top + tol && w1.bottom > w2.top + tol)
        || (w2.top <= w1.top + tol && w2.bottom + tol > w1.top);
}

function halfL(d) { return Math.floor(d / 2); }
function halfU(d) { return Math.ceil(d / 2); }
function halfGapL() { return Math.floor(gap.mid / 2); }
function halfGapU() { return Math.ceil(gap.mid / 2); }


///////////////////////
// ignore filters
///////////////////////

function ignoreClient(win) {
    if (!win) return true;
    if (!win.normalWindow) return true;
    if (!win.resizeable) return true;
    if (win.fullScreen) return true;
    if (!config.includeMaximized && isMaximized(win)) return true;
    if (config.excludeMode && config.applications.includes(String(win.resourceClass))) return true;
    if (config.includeMode && !config.applications.includes(String(win.resourceClass))) return true;
    // Skip windows that are not tiled/snapped (freely placed, dialogs, popups, config windows)
    // In KWin 6, tiled windows have a tile property
    if (typeof win.tile !== "undefined" && win.tile === null) return true;
    return false;
}

function ignoreOther(win1, win2) {
    if (ignoreClient(win2)) return true;
    if (win2 === win1) return true;
    if (win2.minimized) return true;
    // Same screen check
    if (win2.output !== win1.output && win2.screen !== win1.screen) return true;
    // Same desktop check (KWin 6 uses desktops array)
    if (win1.desktops && win2.desktops) {
        let shared = win1.desktops.some(d => win2.desktops.includes(d));
        let onAll1 = win1.onAllDesktops;
        let onAll2 = win2.onAllDesktops;
        if (!shared && !onAll1 && !onAll2) return true;
    } else {
        if (win2.desktop !== win1.desktop && !win2.onAllDesktops && !win1.onAllDesktops) return true;
    }
    return false;
}
