import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Mission Control (Super + Space / Super + Tab, mockup shell2/04-mission):
// the desktops along the top (1-5, the ones in use, "+" for a new one), every
// window of the current desktop spread out below. Click a window to open it,
// drag it onto a desktop to move it there, click a desktop to go there.
OverlayWindow {
    id: ov
    name: "mission"
    dimAlpha: 0.55

    property var wins: []
    readonly property int current: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property var desktops: {
        const used = Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id);
        const s = [1, 2, 3, 4, 5];
        for (const id of used) if (s.indexOf(id) === -1 && id <= 9) s.push(id);
        return s.sort((a, b) => a - b);
    }
    function count(id) {
        const w = Hyprland.workspaces.values.find(x => x.id === id);
        return w ? w.toplevels.values.length : 0;
    }
    // keyboard / gamepad: arrows pick a window (blue ring), Enter / A opens
    // it, [ ] / LB RB go to the previous / next desktop
    property int sel: -1
    function navigate(dx, dy) {
        const n = wins.length;
        if (n === 0) return;
        if (sel < 0) { sel = 0; return; }
        sel = Math.max(0, Math.min(n - 1, sel + dx + dy * area.cols));
    }
    function activate() { if (sel >= 0 && sel < wins.length) { const h = wins[sel]; close(); Shell.focusWindowSoon(h); } }
    function step(d) {
        const i = desktops.indexOf(current);
        const t = desktops[Math.max(0, Math.min(desktops.length - 1, i + d))];
        if (t !== undefined && t !== current) { go(t); Qt.callLater(() => { Hyprland.refreshToplevels(); const ws = Hyprland.focusedWorkspace; ov.wins = ws ? ws.toplevels.values.filter(h => h.wayland) : []; ov.sel = -1; }); }
    }
    Connections {
        target: Shell
        enabled: Shell.overlay === "mission"
        function onPad(w) {
            if (w === "up") ov.navigate(0, -1); else if (w === "down") ov.navigate(0, 1);
            else if (w === "left") ov.navigate(-1, 0); else if (w === "right") ov.navigate(1, 0);
            else if (w === "a") ov.activate(); else if (w === "b" || w === "select") ov.close();
            else if (w === "lb") ov.step(-1); else if (w === "rb") ov.step(1);
        }
    }
    onOpened: {
        sel = -1;
        Hyprland.refreshToplevels();
        const ws = Hyprland.focusedWorkspace;
        wins = ws ? ws.toplevels.values.filter(h => h.wayland) : [];
        keyCatcher.forceActiveFocus();
    }
    function go(id) { Shell.dispatch(`hl.dsp.focus({ workspace = ${id} })`, `workspace ${id}`); }
    function moveTo(h, id) {
        const a = Shell.addr(h);
        Shell.dispatch(`hl.dsp.window.move({ workspace = ${id}, follow = false, window = "address:${a}" })`, `movetoworkspacesilent ${id},address:${a}`);
        wins = wins.filter(x => x !== h);
    }

    Item {
        id: keyCatcher
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space || event.key === Qt.Key_Tab) { ov.close(); event.accepted = true; }
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) { ov.go(event.key - Qt.Key_0); ov.close(); event.accepted = true; }
            else if (event.key === Qt.Key_Left) { ov.navigate(-1, 0); event.accepted = true; }
            else if (event.key === Qt.Key_Right) { ov.navigate(1, 0); event.accepted = true; }
            else if (event.key === Qt.Key_Up) { ov.navigate(0, -1); event.accepted = true; }
            else if (event.key === Qt.Key_Down) { ov.navigate(0, 1); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { ov.activate(); event.accepted = true; }
            else if (event.key === Qt.Key_BracketLeft) { ov.step(-1); event.accepted = true; }
            else if (event.key === Qt.Key_BracketRight) { ov.step(1); event.accepted = true; }
        }
    }

    // ---- desktops along the top
    Row {
        id: deskRow
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 28 }
        spacing: 12
        Repeater {
            model: ov.desktops
            delegate: Column {
                required property int modelData
                spacing: 4
                Rectangle {
                    id: tile
                    width: 150; height: 90; radius: 14
                    clip: true
                    color: Theme.ink(0.05)
                    border.width: modelData === ov.current || drop.containsDrag ? 2 : 1
                    border.color: modelData === ov.current || drop.containsDrag ? Theme.accent : Theme.glassLine
                    // this desktop's own wallpaper (per desktop / monitor / live)
                    readonly property string wall: Wallpapers.pathFor(ov.screen ? ov.screen.name : "", modelData)
                    Image {
                        anchors { fill: parent; margins: 4 }
                        visible: !Wallpapers.isLive(tile.wall)
                        source: visible ? "file://" + tile.wall + "?s=" + Wallpapers.stamp : ""
                        sourceSize: Qt.size(300, 180)
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0.75
                    }
                    // a live wallpaper: its shader (only made for those)
                    Loader {
                        anchors { fill: parent; margins: 4 }
                        active: Wallpapers.isShader(tile.wall)
                        sourceComponent: ShaderEffect {
                            property real time: 20
                            property vector2d resolution: Qt.vector2d(width, height)
                            property color accent: Theme.accent
                            fragmentShader: Qt.resolvedUrl("../assets/shaders/" + tile.wall.slice(7) + ".frag.qsb")
                            opacity: 0.75
                        }
                    }
                    Sym { anchors.centerIn: parent; visible: Wallpapers.isVideo(tile.wall); code: 0xf022b; font.pixelSize: Theme.px(22); color: Theme.muted }
                    Rectangle {
                        anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                        visible: ov.count(modelData) > 0
                        width: cn.implicitWidth + 12; height: 20; radius: 10
                        color: Theme.glassPanel
                        Text { id: cn; anchors.centerIn: parent; text: ov.count(modelData) + (ov.count(modelData) === 1 ? " window" : " windows"); font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.text }
                    }
                    DropArea { id: drop; anchors.fill: parent; keys: ["tuxos-window"]; onDropped: d => ov.moveTo(d.source.hyprWin, modelData) }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { ov.go(modelData); ov.close(); } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // the desktop's own name (Settings > Desktop & dock), else "Desktop N"
                    text: Prefs.desktopNames[String(modelData)] || (Tr.t("Desktop ") + modelData)
                    font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: modelData === ov.current ? Font.DemiBold : Font.Normal
                    color: modelData === ov.current ? Theme.text : Theme.muted
                }
            }
        }
        // a new, empty desktop
        Rectangle {
            width: 90; height: 90; radius: 14
            visible: ov.desktops.length < 9
            color: nh.hovered ? Theme.fillHover : Theme.fill
            border.width: 1; border.color: Theme.glassLine
            Sym { anchors.centerIn: parent; code: Icons.tabPlus; font.pixelSize: Theme.px(24); color: Theme.muted }
            HoverHandler { id: nh; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    for (let i = 1; i <= 9; i++) if (ov.desktops.indexOf(i) === -1 || ov.count(i) === 0 && i > 5) { ov.go(i); break; }
                    ov.close();
                }
            }
        }
    }

    // ---- the windows of this desktop, spread out
    Item {
        id: area
        anchors { left: parent.left; right: parent.right; top: deskRow.bottom; bottom: hint.top; margins: 40 }
        readonly property int n: ov.wins.length
        readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(n * width / Math.max(1, height) / 1.6)))
        readonly property int rows: Math.max(1, Math.ceil(n / cols))
        readonly property real cw: width / cols
        readonly property real ch: height / rows

        Repeater {
            model: ov.wins
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property var ipc: modelData.lastIpcObject || {}
                readonly property real aspect: ipc.size ? ipc.size[0] / Math.max(1, ipc.size[1]) : 1.6
                readonly property real maxW: area.cw - 30
                readonly property real maxH: area.ch - 50
                width: Math.min(maxW, maxH * aspect)
                height: width / aspect + 30
                x: (index % area.cols) * area.cw + (area.cw - width) / 2
                y: Math.floor(index / area.cols) * area.ch + (area.ch - height) / 2
                property var hyprWin: modelData

                Drag.active: dh.active
                Drag.keys: ["tuxos-window"]
                Drag.source: cell
                Drag.hotSpot: Qt.point(width / 2, height / 2)
                DragHandler {
                    id: dh
                    // put it back first: a drop on a desktop removes this cell
                    onActiveChanged: if (!active) { cell.x = Qt.binding(() => (cell.index % area.cols) * area.cw + (area.cw - cell.width) / 2); cell.y = Qt.binding(() => Math.floor(cell.index / area.cols) * area.ch + (area.ch - cell.height) / 2); cell.Drag.drop(); }
                }
                readonly property bool picked: wh.hovered || ov.sel === index
                scale: dh.active ? 0.6 : (picked ? 1.02 : 1)
                Behavior on scale { enabled: !Theme.reduceMotion; Spring { unit: true } }

                WindowThumb {
                    width: parent.width; height: parent.height - 30
                    toplevel: cell.modelData.wayland
                    live: false
                    radius: 16
                    border.width: cell.picked ? 2 : 1
                    border.color: cell.picked ? Theme.accent : Theme.glassLine
                }
                Row {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                    spacing: 4
                    AppTile { size: 20; appId: cell.modelData.wayland.appId; entry: DesktopEntries.heuristicLookup(cell.modelData.wayland.appId) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, cell.width - 30)
                        elide: Text.ElideRight
                        text: cell.modelData.wayland.title || cell.modelData.wayland.appId
                        font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text
                    }
                }
                HoverHandler { id: wh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { ov.close(); Shell.focusWindowSoon(cell.modelData); } }
            }
        }
        EmptyState {
            anchors.centerIn: parent
            visible: ov.wins.length === 0
            title: "No windows on this desktop"; hint: "Pick another desktop above, or open an app (Super)"
        }
    }
    Text {
        id: hint
        // above the dock (which stays visible over Mission Control)
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 112 }
        text: Tr.t("Click a window to open it · drag a window onto a desktop to move it · arrows + Enter pick one · 1-9 or [ ] change desktop · Esc closes")
        font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted
    }
}
