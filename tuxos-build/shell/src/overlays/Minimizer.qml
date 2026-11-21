import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Minimize / restore animation (SPEC window animations, ~300 ms): the window
// shrinks and flies into its own dock tile, narrowing and fading a little;
// the tile glows when it lands. Restoring grows back from the tile. Hyprland
// has no real minimize: the window waits on the hidden special desktop
// "minimized". Never takes input.
PanelWindow {
    id: win

    property var target: null           // HyprlandToplevel
    property rect from
    property point to
    property bool restoring: false
    property bool flying: false

    screen: Quickshell.screens.find(s => s.name === Shell.focusedScreen) || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: flying
    mask: Region {}
    WlrLayershell.namespace: "tuxos-minimize"
    WlrLayershell.layer: WlrLayer.Overlay

    function tileFor(h) {
        const id = AppSymbols.norm(h.wayland ? h.wayland.appId : "");
        const p = Shell.dockTiles[screen.name + "/" + id];
        return p ? Qt.point(p.x - screen.x, p.y - screen.y) : Qt.point(width / 2, height - 50);
    }
    function rectOf(h) {
        const o = h.lastIpcObject || {};
        if (!o.at || !o.size) return Qt.rect(width / 2 - 200, height / 2 - 150, 400, 300);
        return Qt.rect(o.at[0] - screen.x, o.at[1] - screen.y, o.size[0], o.size[1]);
    }

    Connections {
        target: Shell
        function onMinimizeRequested(h) {
            if (!h || win.flying) return;
            Hyprland.refreshToplevels();
            win.target = h;
            win.restoring = false;
            win.from = win.rectOf(h);
            win.to = win.tileFor(h);
            Shell.minimizeTarget = h.wayland ? h.wayland.appId : "";
            ghost.x = win.from.x; ghost.y = win.from.y; ghost.width = win.from.width; ghost.height = win.from.height; ghost.opacity = 1;
            win.flying = true;
            snap.waited = 0;
            snapWait.restart();
        }
        function onRestoreRequested(h) {
            if (!h) return;
            win.target = h;
            win.restoring = true;
            win.to = win.tileFor(h);
            const ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
            const a = Shell.addr(h);
            Shell.dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:${a}" })`, `movetoworkspace ${ws},address:${a}`);
            Shell.dispatch(`hl.dsp.focus({ window = "address:${a}" })`, `focuswindow address:${a}`);
            Hyprland.refreshToplevels();
            restoreLater.restart();
        }
    }
    // ---- open from the tile: a window the shell just launched grows out of
    // the dock tile / launcher entry it was clicked on
    property var opening: null          // { addr, pt }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "openwindow" || Theme.reduceMotion || win.flying) return;
            const f = event.data.split(",");
            const l = Shell.takeLaunch(f[2]);
            if (!l) return;
            win.opening = { addr: "0x" + f[0].replace(/^0x/, ""), pt: l.pt };
            Hyprland.refreshToplevels();
            openLater.restart();
        }
    }
    Timer {
        id: openLater
        interval: 70
        onTriggered: {
            const o = win.opening;
            const h = o ? Hyprland.toplevels.values.find(t => Shell.addr(t) === o.addr) : null;
            if (!h || !h.lastIpcObject || !h.lastIpcObject.at) return;
            win.target = h;
            win.restoring = true;
            win.from = win.rectOf(h);
            win.to = o.pt ? Qt.point(o.pt.x - win.screen.x, o.pt.y - win.screen.y) : win.tileFor(h);
            ghost.x = win.to.x - 29; ghost.y = win.to.y - 29; ghost.width = 58; ghost.height = 58; ghost.opacity = 0.85;
            win.flying = true;
            grow.restart();
        }
    }

    // wait for the snapshot (max ~200 ms), then hide the window and fly
    Timer {
        id: snapWait
        interval: 30; repeat: true
        onTriggered: {
            snap.waited += 30;
            if (snap.hasContent || snap.waited > 200) {
                stop();
                const a = Shell.addr(win.target);
                Shell.dispatch(`hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:${a}" })`,
                               `movetoworkspacesilent special:minimized,address:${a}`);
                Shell.minimizing = true;
                fly.restart();
            }
        }
    }
    Timer { id: restoreLater; interval: 60; onTriggered: { win.from = win.rectOf(win.target); ghost.x = win.to.x - 29; ghost.y = win.to.y - 29; ghost.width = 58; ghost.height = 58; ghost.opacity = 0.5; win.flying = true; grow.restart(); } }

    Rectangle {
        id: ghost
        radius: 18
        color: Theme.glassPanel
        border.width: 1; border.color: Theme.accentLine
        clip: true
        // the window as it was (a crop of the screen, taken before it left)
        Item {
            anchors.fill: parent
            visible: !win.restoring
            ScreencopyView {
                id: snap
                property int waited: 0
                captureSource: win.flying && !win.restoring ? win.screen : null
                live: false
                width: win.width * (ghost.width / Math.max(1, win.from.width))
                height: win.height * (ghost.height / Math.max(1, win.from.height))
                x: -win.from.x * (ghost.width / Math.max(1, win.from.width))
                y: -win.from.y * (ghost.height / Math.max(1, win.from.height))
            }
        }
        AppTile {
            anchors.centerIn: parent
            visible: win.restoring
            size: Math.min(58, parent.width * 0.6, parent.height * 0.6)
            appId: win.target && win.target.wayland ? win.target.wayland.appId : ""
            entry: win.target && win.target.wayland ? DesktopEntries.heuristicLookup(win.target.wayland.appId) : null
        }
    }

    ParallelAnimation {
        id: fly
        NumberAnimation { target: ghost; property: "x"; to: win.to.x - 29; duration: 300; easing.type: Easing.InOutCubic }
        NumberAnimation { target: ghost; property: "y"; to: win.to.y - 29; duration: 300; easing.type: Easing.InCubic }
        NumberAnimation { target: ghost; property: "width"; to: 58; duration: 300; easing.type: Easing.InOutCubic }
        NumberAnimation { target: ghost; property: "height"; to: 58; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: ghost; property: "opacity"; to: 0.35; duration: 300 }
        onFinished: { win.flying = false; glowOff.restart(); }
    }
    Timer { id: glowOff; interval: 380; onTriggered: Shell.minimizing = false }
    ParallelAnimation {
        id: grow
        NumberAnimation { target: ghost; property: "x"; to: win.from.x; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: ghost; property: "y"; to: win.from.y; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: ghost; property: "width"; to: win.from.width; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: ghost; property: "height"; to: win.from.height; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: ghost; property: "opacity"; to: 0; duration: 260; easing.type: Easing.InQuad }
        onFinished: win.flying = false
    }
}
