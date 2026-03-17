/*
KWin Script Window Gaps — Plasma 6 port
Originally (C) 2021-2022 Natalie Clarius <natalie_clarius@yahoo.de>
Ported to KWin 6 API with automatic panel detection
GNU General Public License v3.0
*/

///////////////////////
// configuration
///////////////////////

// Base gap size (applied on all edges, all monitors)
const baseGap = readConfig("gapBase", 16);
// Extra padding around panels (on top of panel thickness + floating gap)
const panelPaddingTop    = readConfig("panelPaddingTop", -10);
const panelPaddingBottom = readConfig("panelPaddingBottom", 30);
const panelPaddingLeft   = readConfig("panelPaddingLeft", 10);
const panelPaddingRight  = readConfig("panelPaddingRight", 10);
// Gap between adjacent windows
const midGap = readConfig("gapMid", 16);

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

///////////////////////
// KWin 6 compat
///////////////////////

const getWindowList = workspace.windowList
    ? () => workspace.windowList()
    : () => workspace.clientList();

const windowAddedSignal = workspace.windowAdded || workspace.clientAdded;

const getArea = (win) => {
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

const getFullArea = (win) => {
    try {
        return workspace.clientArea(KWin.FullScreenArea, win.output, win.desktops[0] || workspace.currentDesktop);
    } catch(e) {
        try {
            return workspace.clientArea(KWin.FullScreenArea, win);
        } catch(e2) {
            return workspace.clientArea(6, win);
        }
    }
};

///////////////////////
// panel detection
///////////////////////

// Cache panel gaps per output, refreshed when docks change
var panelGapCache = {};

function detectPanelGaps(win) {
    let fullArea = getFullArea(win);

    // Use the screen's full area coordinates as a unique cache key
    let outputKey = [fullArea.x, fullArea.y, fullArea.width, fullArea.height].join(",");

    if (panelGapCache[outputKey]) return panelGapCache[outputKey];

    let maxArea = getArea(win);

    // Struts: space already reserved by panels that KWin accounts for
    let strutTop    = maxArea.y - fullArea.y;
    let strutBottom = (fullArea.y + fullArea.height) - (maxArea.y + maxArea.height);
    let strutLeft   = maxArea.x - fullArea.x;
    let strutRight  = (fullArea.x + fullArea.width) - (maxArea.x + maxArea.width);

    // Scan dock windows (panels) — use geometry overlap to match to this screen
    let windows = getWindowList();
    let dockTop = 0, dockBottom = 0, dockLeft = 0, dockRight = 0;

    for (let i = 0; i < windows.length; i++) {
        let w = windows[i];
        if (!w || !w.dock) continue;

        let dg = w.frameGeometry;

        // Check if this dock overlaps with this screen's full area
        let overlapX = dg.x < (fullArea.x + fullArea.width) && (dg.x + dg.width) > fullArea.x;
        let overlapY = dg.y < (fullArea.y + fullArea.height) && (dg.y + dg.height) > fullArea.y;
        if (!overlapX || !overlapY) continue;

        let isHorizontal = dg.width > dg.height;
        let isVertical   = dg.height > dg.width;

        if (isHorizontal) {
            let panelCenter = dg.y + dg.height / 2;
            let screenCenter = fullArea.y + fullArea.height / 2;
            if (panelCenter < screenCenter) {
                let needed = (dg.y + dg.height) - fullArea.y;
                dockTop = Math.max(dockTop, needed);
            } else {
                let needed = (fullArea.y + fullArea.height) - dg.y;
                dockBottom = Math.max(dockBottom, needed);
            }
        } else if (isVertical) {
            let panelCenter = dg.x + dg.width / 2;
            let screenCenter = fullArea.x + fullArea.width / 2;
            if (panelCenter < screenCenter) {
                let needed = (dg.x + dg.width) - fullArea.x;
                dockLeft = Math.max(dockLeft, needed);
            } else {
                let needed = (fullArea.x + fullArea.width) - dg.x;
                dockRight = Math.max(dockRight, needed);
            }
        }
    }

    // For edges with panels: use base gap + panel padding (panel already pushes
    // the window inward via its thickness, we just add breathing room)
    // For edges without panels: just use base gap
    let result = {
        left:   Math.max(0, baseGap + (dockLeft   > strutLeft   ? panelPaddingLeft   : 0)),
        right:  Math.max(0, baseGap + (dockRight  > strutRight  ? panelPaddingRight  : 0)),
        top:    Math.max(0, baseGap + (dockTop    > strutTop    ? panelPaddingTop    : 0)),
        bottom: Math.max(0, baseGap + (dockBottom > strutBottom ? panelPaddingBottom : 0)),
        mid:    midGap,
    };

    debug("panel gaps for", outputKey, JSON.stringify(result),
          "struts:", strutTop, strutRight, strutBottom, strutLeft,
          "docks:", dockTop, dockRight, dockBottom, dockLeft);

    panelGapCache[outputKey] = result;
    return result;
}

function invalidatePanelCache() {
    panelGapCache = {};
}

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

    // If a dock/panel is added, invalidate cache and re-gap everything
    if (win.dock) {
        invalidatePanelCache();
        applyGapsAll();
        return;
    }

    debug("added", win.caption);
    applyGaps(win);

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
    if (sig) {
        sig.connect(() => {
            invalidatePanelCache();
            applyGapsAll();
        });
    }
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
    let gap = detectPanelGaps(win);
    let grid = getGrid(win, area, gap);
    let anchored = {left: false, right: false, top: false, bottom: false};

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

        if (nearWindow(w1.left, w2.right, midGap) && overlapVer(w1, w2)) {
            let diff = w1.left - w2.right;
            w1.x = w1.x - halfL(diff) + halfGapU();
            w1.width = w1.width + halfL(diff) - halfGapU();
            w2.width = w2.width + halfU(diff) - halfGapL();
        }
        if (nearWindow(w2.left, w1.right, midGap) && overlapVer(w1, w2)) {
            let diff = w2.left - (w1.right + 1);
            w1.width = w1.width + halfU(diff) - halfGapL();
            w2.x = w2.x - halfL(diff) + halfGapU();
            w2.width = w2.width + halfL(diff) - halfGapU();
        }
        if (nearWindow(w1.top, w2.bottom, midGap) && overlapHor(w1, w2)) {
            let diff = w1.top - w2.bottom;
            w1.y = w1.y - halfL(diff) + halfGapU();
            w1.height = w1.height + halfL(diff) - halfGapU();
            w2.height = w2.height + halfU(diff) - halfGapL();
        }
        if (nearWindow(w2.top, w1.bottom, midGap) && overlapHor(w1, w2)) {
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

function getGrid(win, area, gap) {
    return {
        left: {
            fullLeft:       { closed: Math.round(area.x),
                              gapped: Math.round(area.x + gap.left) },
            halfHorizontal: { closed: Math.round(area.x + area.width / 2),
                              gapped: Math.round(area.x + (area.width + gap.left - gap.right + gap.mid) / 2) },
        },
        right: {
            halfHorizontal: { closed: Math.round(area.x + area.width / 2),
                              gapped: Math.round(area.x + area.width - (area.width + gap.left - gap.right + gap.mid) / 2) },
            fullRight:      { closed: Math.round(area.x + area.width),
                              gapped: Math.round(area.x + area.width - gap.right) },
        },
        top: {
            fullTop:        { closed: Math.round(area.y),
                              gapped: Math.round(area.y + gap.top) },
            halfVertical:   { closed: Math.round(area.y + area.height / 2),
                              gapped: Math.round(area.y + (area.height + gap.top - gap.bottom + gap.mid) / 2) },
        },
        bottom: {
            halfVertical:   { closed: Math.round(area.y + area.height / 2),
                              gapped: Math.round(area.y + area.height - (area.height + gap.top - gap.bottom + gap.mid) / 2) },
            fullBottom:     { closed: Math.round(area.y + area.height),
                              gapped: Math.round(area.y + area.height - gap.bottom) },
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
    let tol = 2 * midGap;
    return (w1.left <= w2.left + tol && w1.right > w2.left + tol)
        || (w2.left <= w1.left + tol && w2.right + tol > w1.left);
}

function overlapVer(w1, w2) {
    let tol = 2 * midGap;
    return (w1.top <= w2.top + tol && w1.bottom > w2.top + tol)
        || (w2.top <= w1.top + tol && w2.bottom + tol > w1.top);
}

function halfL(d) { return Math.floor(d / 2); }
function halfU(d) { return Math.ceil(d / 2); }
function halfGapL() { return Math.floor(midGap / 2); }
function halfGapU() { return Math.ceil(midGap / 2); }


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
    // Skip windows that are not tiled/snapped
    if (typeof win.tile !== "undefined" && win.tile === null) return true;
    return false;
}

function ignoreOther(win1, win2) {
    if (ignoreClient(win2)) return true;
    if (win2 === win1) return true;
    if (win2.minimized) return true;
    if (win2.output !== win1.output && win2.screen !== win1.screen) return true;
    if (win1.desktops && win2.desktops) {
        let shared = win1.desktops.some(d => win2.desktops.includes(d));
        if (!shared && !win1.onAllDesktops && !win2.onAllDesktops) return true;
    } else {
        if (win2.desktop !== win1.desktop && !win2.onAllDesktops && !win1.onAllDesktops) return true;
    }
    return false;
}
