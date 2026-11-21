pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Shared shell state: which droplet panel is open, on which screen, and
// where it hangs from (screen x of the bar item it drops out of); which
// full-screen overlay (launcher, power menu, ...) is open.
Singleton {
    id: shell

    property string panel: ""          // "", "calendar", "status", "media", "power", "wifi", "privacy"
    property string screenName: ""
    property real anchorX: 0           // centre of the bar item, screen coordinates
    property real anchorWidth: 120     // width of the bar item (neck width follows it)
    property var panelData: null       // e.g. the network a Wi-Fi password droplet is for

    // where the status group sits (screen x of its centre, width), for the
    // flyouts that hang from it
    // where each bar's status group sits (per screen: several monitors)
    // the live ISO (tuxos-session sets TUXOS_LIVE): no lock, Welcome, session restore
    readonly property bool live: Quickshell.env("TUXOS_LIVE") === "1"
    signal peekBar()                      // Super held: show an auto-hidden bar
    property var statusXs: ({})
    property real statusWidth: 120
    function statusXFor(screen) { return statusXs[screen] !== undefined ? statusXs[screen] : (Object.values(statusXs)[0] || 0); }
    property real clockX: 0

    // hover state of bar items that open panels on hover
    property bool clockHovered: false
    property bool mediaHovered: false

    function open(name, screen, x, w) {
        panel = name;
        screenName = screen;
        anchorX = x;
        anchorWidth = w;
    }
    // a right-click menu under the bar (popups/Popups.qml "menu"):
    // items [{ label, icon, run, danger }]
    function menu(items, screen, x) { panelData = items; open("menu", screen, x, 60); }
    property double closedAt: 0
    function close() {
        if (panel !== "") closedAt = Date.now();
        panel = "";
    }
    function toggle(name, screen, x, w) {
        if (panel === name && screenName === screen) close();
        // a click on the same bar item just closed it via the focus grab
        else if (Date.now() - closedAt < 250) return;
        else open(name, screen, x, w);
    }

    // ---- flyouts other than volume: { icon, title, sub, value (0..1 or -1), text, off }
    property var flyoutData: null
    property int flyoutSerial: 0
    function flyout(data) { flyoutData = data; flyoutSerial++; }

    // ---- tooltips under the bar (with the shortcut, SPEC polish)
    property string tip: ""
    property real tipX: 0
    property string tipScreen: ""
    Timer { id: tipDelay; interval: 450; property string text; property real x; property string scr; onTriggered: { shell.tip = text; shell.tipX = x; shell.tipScreen = scr; } }
    function showTip(text, screen, x) { tipDelay.text = text; tipDelay.x = x; tipDelay.scr = screen; tipDelay.restart(); }
    function hideTip() { tipDelay.stop(); tip = ""; }

    // ---- full-screen overlays: one at a time, on the focused monitor
    // "launcher", "power", "restart", "switcher", "mission", "clipboard",
    // "emoji", "sheet", "notes", "centre", "screenshot", "polkit"
    property string overlay: ""
    property string overlayScreen: ""
    property var overlayArg: null
    readonly property string focusedScreen: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")

    function showOverlay(name, arg) {
        close();
        overlayArg = arg === undefined ? null : arg;
        overlayScreen = focusedScreen;
        overlay = name;
    }
    function hideOverlay(name) {
        if (name === undefined || overlay === name) overlay = "";
    }
    function toggleOverlay(name, arg) {
        if (overlay === name) hideOverlay();
        else showOverlay(name, arg);
    }

    // a full-screen window (game / video) is focused: Super alone must not
    // pull the user out of it (SPEC shortcuts)
    readonly property bool fullscreenFocused: {
        const t = ToplevelManager.activeToplevel;
        return t !== null && t.fullscreen;
    }

    // the compositor config moved / resized windows without an IPC event
    // (gapped maximize): the dock checks again whether it is covered
    signal windowsMoved()
    // a gamepad button (services/GamePad.qml): up down left right a b x y start
    // select home lb rb; the open overlay reacts
    signal pad(string button)
    // run a shortcut by name from anywhere (shortcuts/Keys.qml does it)
    signal shortcut(string name)
    // a window was dragged and let go at (x, y) on that screen (logical,
    // screen-local): the bar's desktop numbers take it (SPEC "drop a window
    // on a desktop number to move it there")
    signal windowDropped(string screenName, real x, real y, string address)

    // ---- open from the tile (SPEC window animations): the shell remembers
    // what it launched and from where; the Minimizer overlay grows the new
    // window out of that point
    property var launches: []                 // { ids, pt (screen point or null), until }
    function noteLaunch(entry, pt) {
        const id = AppSymbols.norm(entry.id);
        const ids = [id, AppSymbols.norm(entry.startupClass), id.split(".").pop()].filter(x => x);
        const now = Date.now();
        launches = launches.filter(l => l.until > now).concat([{ ids: ids, pt: pt || null, until: now + 8000 }]);
    }
    function takeLaunch(cls) {
        const now = Date.now(), c = AppSymbols.norm(cls), live = launches.filter(l => l.until > now);
        let i = live.findIndex(l => l.ids.indexOf(c) !== -1 || l.ids.some(x => c.endsWith("." + x) || x.endsWith("." + c)));
        if (i === -1 && live.length === 1) i = 0;       // apps whose window class differs (Steam, Electron)
        if (i === -1) { launches = live; return null; }
        const l = live[i];
        live.splice(i, 1);
        launches = live;
        return l;
    }

    // ---- minimize into the dock (SPEC window animations): the dock publishes
    // where each app's tile is; the Minimizer overlay draws the flight
    property var dockTiles: ({})              // "screen/appid" -> screen point
    property bool minimizing: false
    property string minimizeTarget: ""
    signal minimizeRequested(var hyprToplevel)
    signal restoreRequested(var hyprToplevel)
    function minimizeActive() { minimizeRequested(Hyprland.activeToplevel); }
    function restoreWindow(h) { restoreRequested(h); }

    // Alt + Tab while the switcher is open: Hyprland keeps the binding, so the
    // next Tab arrives as the shortcut again
    signal switcherStep(int delta)

    // focus a window anywhere (its desktop comes along); minimized windows
    // come back to the current desktop first
    // from an overlay: wait until it has let go of the keyboard (Hyprland
    // keeps focus on an exclusive layer while it is mapped)
    property var pendingFocus: null
    Timer { id: focusLater; interval: 140; onTriggered: { shell.focusWindow(shell.pendingFocus); shell.pendingFocus = null; } }
    function focusWindowSoon(h) { pendingFocus = h; focusLater.restart(); }
    function addr(h) { return h.address.startsWith("0x") ? h.address : "0x" + h.address; }
    function focusWindow(hyprToplevel) {
        if (!hyprToplevel) return;
        const a = addr(hyprToplevel);
        const o = hyprToplevel.lastIpcObject || {};
        if (o.workspace && o.workspace.name === "special:minimized") {
            const ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
            dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:${a}" })`, `movetoworkspace ${ws},address:${a}`);
        }
        dispatch(`hl.dsp.focus({ window = "address:${a}" })`, `focuswindow address:${a}`);
    }

    // run a Hyprland dispatcher in the config's syntax
    function dispatch(lua, legacy) {
        Hyprland.dispatch(Hyprland.usingLua ? lua : legacy);
    }
}
