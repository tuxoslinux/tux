import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// The dock (SPEC "Dock" - approved): floating glass, bottom centre, 14 px
// from the edge; pinned + running apps as 58 px tiles with smart symbols;
// Trash after a divider. It slides away while a window covers its area and
// comes back when the pointer touches the bottom edge.
// Hover a running app: its windows in a droplet (shell2/16-dockprev).
// Right click: pin / unpin, new window, the app's actions, move to a desktop,
// close / close all. Drop files on a tile: they open in that app.
PanelWindow {
    id: dock

    property string screenName: ""
    readonly property var pins: Prefs.pins


    anchors { bottom: true }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.max(frame.width, popupWidth) + 40
    implicitHeight: 58 + 24 + 14 + (popupFor !== null ? popupHeight + 12 : 0)
    color: "transparent"
    WlrLayershell.namespace: "tuxos-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: popupKind === "menu" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ---- apps: pinned (if installed) then running ones that are not pinned
    readonly property var toplevels: ToplevelManager.toplevels.values
    function entryFor(appId) { return DesktopEntries.heuristicLookup(appId); }
    function sameApp(entry, appId) {
        if (!entry) return false;
        const a = AppSymbols.norm(appId);
        return AppSymbols.norm(entry.id) === a || AppSymbols.norm(entry.startupClass) === a
            || (entryFor(appId) !== null && entryFor(appId).id === entry.id);
    }
    readonly property var items: {
        const all = DesktopEntries.applications.values;   // re-evaluate when the app list loads / changes
        const list = [];
        for (const id of pins) {
            const e = DesktopEntries.byId(id);
            if (e && !list.some(x => x.entry === e)) list.push({ entry: e, appId: id, pinned: true });
        }
        for (const t of toplevels) {
            if (!t.appId) continue;
            if (list.some(x => sameApp(x.entry, t.appId) || x.appId === t.appId)) continue;
            list.push({ entry: entryFor(t.appId), appId: t.appId, pinned: false });
        }
        return list;
    }
    function windowsOf(item) {
        return toplevels.filter(t => sameApp(item.entry, t.appId) || t.appId === item.appId);
    }
    function hyprOf(t) { return Hyprland.toplevels.values.find(h => h.wayland === t) || null; }

    function togglePin(item) {
        const id = item.entry ? item.entry.id : item.appId;
        const p = Prefs.pins.slice();
        const i = p.indexOf(id);
        if (i === -1) p.push(id); else p.splice(i, 1);
        Prefs.pins = p;
    }

    // ---- hide while a window covers the dock's area (tiled, maximized or
    // full-screen windows on the visible desktop), show on bottom-edge hover
    property bool covered: false
    function recheck() {
        const ws = Hyprland.focusedWorkspace;
        if (!ws || (dock.screenName && ws.monitor && ws.monitor.name !== dock.screenName)) { covered = false; return; }
        const wins = ws.toplevels.values;
        let c = false;
        for (const w of wins) {
            const o = w.lastIpcObject || {};
            if (o.floating === false || o.fullscreen > 0 || (w.wayland && (w.wayland.maximized || w.wayland.fullscreen))) { c = true; break; }
            if (o.at && o.size && o.at[1] + o.size[1] > (dock.screen ? dock.screen.height : 1080) - 96) { c = true; break; }
        }
        covered = c;
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (/window|workspace|float|fullscreen|move/.test(event.name)) {
                Hyprland.refreshToplevels();
                recheckLater.restart();
            }
        }
    }
    Connections { target: Shell; function onWindowsMoved() { Hyprland.refreshToplevels(); recheckLater.restart(); } }
    // (the refresh above answers later: check again once a window's data
    // really changed, else a window that was just floated still counts as
    // tiled and the dock stays hidden)
    Variants {
        model: Hyprland.toplevels.values
        delegate: Component {
            Connections {
                required property var modelData
                target: modelData
                function onLastIpcObjectChanged() { recheckLater.restart(); }
            }
        }
    }
    Timer { id: recheckLater; interval: 120; onTriggered: dock.recheck() }
    Component.onCompleted: recheckLater.restart()

    readonly property bool shown: !covered || edgeHover.hovered || frameHover.hovered || popupFor !== null || Shell.minimizing

    // ---- popup above a tile: window previews (hover) or the menu (right click)
    property var popupFor: null          // the item
    property string popupKind: ""        // "preview" | "menu"
    property Item popupTile: null
    readonly property real popupX: popupTile ? frame.x + row.x + popupTile.x + popupTile.width / 2 : 0   // tile centre in this window
    readonly property real popupWidth: popupKind === "menu" ? 290 : Math.max(240, Math.min(3, previewWins.length) * 236 + 24)
    readonly property real popupHeight: popupKind === "menu" ? menuCol.implicitHeight + 24 + 32 : 196 + 32
    readonly property var previewWins: popupFor ? windowsOf(popupFor) : []
    function openPopup(kind, item, tile) {
        popupKind = kind;
        popupFor = item;
        popupTile = tile;
    }
    function closePopup() { popupFor = null; popupKind = ""; }
    Timer {
        id: popupClose
        interval: 300
        running: dock.popupKind === "preview" && !frameHover.hovered && !popHover.hovered
        onTriggered: dock.closePopup()
    }
    Timer {
        id: previewDelay
        interval: 500
        property var item
        property var tile
        onTriggered: if (dock.popupKind !== "menu" && dock.windowsOf(item).length > 0) dock.openPopup("preview", item, tile)
    }
    HyprlandFocusGrab {
        windows: [dock]
        active: dock.popupKind === "menu"
        onCleared: dock.closePopup()
    }

    mask: Region {
        item: dock.shown ? maskBox : edge
    }
    Item {
        id: maskBox
        x: Math.min(frame.x, pop.x); y: dock.popupFor !== null ? pop.y : frame.y
        width: Math.max(frame.x + frame.width, pop.x + pop.width) - x
        height: dock.height - y
    }

    Item {
        id: edge
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 3
        HoverHandler { id: edgeHover }
    }

    // ---- the popup droplet
    Droplet {
        id: pop
        up: true
        width: dock.popupWidth
        panelHeight: dock.popupHeight
        x: Math.max(0, Math.min(dock.width - width, dock.popupX - width / 2))
        y: frame.y - height + 6
        neckX: dock.popupX - x
        neckWidth: 70
        progress: dock.popupFor !== null ? 1 : 0
        Behavior on progress { enabled: !Theme.reduceMotion; Spring { unit: true } }
        visible: progress > 0
        HoverHandler { id: popHover }

        // window previews
        Row {
            visible: dock.popupKind === "preview"
            x: 12; y: 12
            spacing: 12
            Repeater {
                model: dock.popupKind === "preview" ? dock.previewWins.slice(0, 3) : []
                delegate: Column {
                    required property var modelData
                    spacing: 4
                    WindowThumb {
                        width: 224; height: 140
                        toplevel: modelData
                        live: false
                        border.width: th.hovered || modelData.activated ? 2 : 1
                        border.color: th.hovered || modelData.activated ? Theme.accent : Theme.glassLine
                        HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { Shell.focusWindow(dock.hyprOf(modelData)); dock.closePopup(); } }
                    }
                    Text {
                        width: 224
                        text: `${dock.popupFor && dock.popupFor.entry ? dock.popupFor.entry.name : ""} · ${modelData.title}`
                        elide: Text.ElideRight
                        font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text
                    }
                }
            }
        }

        // the menu
        Column {
            id: menuCol
            visible: dock.popupKind === "menu"
            x: 12; y: 12
            width: parent.width - 24
            spacing: 4
            readonly property var item: dock.popupFor
            readonly property var wins: item ? dock.windowsOf(item) : []
            Text {
                text: menuCol.item && menuCol.item.entry ? menuCol.item.entry.name : (menuCol.item ? menuCol.item.appId : "")
                font.family: Theme.font; font.pixelSize: Theme.px(13); font.weight: Font.DemiBold; color: Theme.muted
                leftPadding: 8; bottomPadding: 4
            }
            MenuRow { label: Tr.t("New window"); icon: Icons.tabPlus; visible: menuCol.item !== null && menuCol.item.entry !== null; onHit: { Usage.launch(menuCol.item.entry); dock.closePopup(); } }
            Repeater {
                model: menuCol.item && menuCol.item.entry ? menuCol.item.entry.actions : []
                delegate: MenuRow {
                    required property var modelData
                    label: modelData.name
                    icon: Icons.chevronRight
                    onHit: { modelData.execute(); dock.closePopup(); }
                }
            }
            MenuRow {
                label: menuCol.item && Prefs.pins.indexOf(menuCol.item.entry ? menuCol.item.entry.id : menuCol.item.appId) !== -1 ? "Unpin from the dock" : "Pin to the dock"
                icon: Icons.pin
                onHit: { dock.togglePin(menuCol.item); dock.closePopup(); }
            }
            // move to a desktop: a compact row 1-9
            Item {
                visible: menuCol.wins.length > 0
                width: menuCol.width; height: 40
                Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Move to"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                Row {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Repeater {
                        model: 9
                        delegate: Rectangle {
                            required property int index
                            width: 16; height: 22; radius: 6
                            color: dh.hovered ? Theme.accent : Theme.fill
                            Text { anchors.centerIn: parent; text: index + 1; font.family: Theme.font; font.pixelSize: Theme.px(11); color: dh.hovered ? Theme.accentInk : Theme.text }
                            HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    for (const t of menuCol.wins) {
                                        const h = dock.hyprOf(t);
                                        if (h) Shell.dispatch(`hl.dsp.window.move({ workspace = ${index + 1}, follow = false, window = "address:${Shell.addr(h)}" })`, `movetoworkspacesilent ${index + 1},address:${Shell.addr(h)}`);
                                    }
                                    dock.closePopup();
                                }
                            }
                        }
                    }
                }
            }
            MenuRow {
                visible: menuCol.wins.length > 0
                label: menuCol.wins.length > 1 ? `Close all ${menuCol.wins.length} windows` : "Close"
                icon: Icons.close
                danger: true
                onHit: { for (const t of menuCol.wins) t.close(); dock.closePopup(); }
            }
        }
    }

    // ---- the dock itself
    Rectangle {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        y: dock.shown ? dock.height - height - 14 : dock.height + 8
        Behavior on y { enabled: !Theme.reduceMotion; Spring {} }
        width: row.width + 24
        height: 58 + 24
        radius: 26
        color: Theme.glass
        border.width: 1
        border.color: Theme.glassLine
        HoverHandler { id: frameHover }

        Row {
            id: row
            anchors { centerIn: parent; verticalCenterOffset: -2 }
            spacing: 8
            Repeater {
                model: dock.items
                delegate: AppTile {
                    id: tile
                    required property var modelData
                    entry: modelData.entry
                    appId: modelData.appId
                    readonly property var wins: dock.windowsOf(modelData)
                    running: wins.length > 0
                    focused: wins.some(w => w.activated)
                    glow: Shell.minimizeTarget === appId && Shell.minimizing
                    // publish where this app sits, for the minimize flight
                    function publish() {
                        if (typeof dock === "undefined" || !tile.Window.window) return;   // shell shutting down
                        const p = tile.mapToItem(null, tile.width / 2, tile.height / 2);
                        Shell.dockTiles[dock.screenName + "/" + AppSymbols.norm(modelData.appId)] = Qt.point(dock.screen.x + (dock.screen.width - dock.width) / 2 + p.x, dock.screen.y + dock.screen.height - dock.height + p.y);
                        if (modelData.entry) Shell.dockTiles[dock.screenName + "/" + AppSymbols.norm(modelData.entry.id)] = Shell.dockTiles[dock.screenName + "/" + AppSymbols.norm(modelData.appId)];
                    }
                    onXChanged: Qt.callLater(publish)
                    Component.onCompleted: Qt.callLater(publish)

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                if (dock.popupKind === "preview") dock.openPopup("preview", tile.modelData, tile);
                                else { previewDelay.item = tile.modelData; previewDelay.tile = tile; previewDelay.restart(); }
                            } else previewDelay.stop();
                        }
                    }
                    TapHandler {
                        onTapped: {
                            dock.closePopup();
                            const w = parent.wins;
                            if (w.length === 0) { if (parent.entry) Usage.launch(parent.entry); return; }
                            // a minimized window comes back first; otherwise cycle
                            const mini = w.find(x => { const h = dock.hyprOf(x); return h && h.lastIpcObject && h.lastIpcObject.workspace && h.lastIpcObject.workspace.name === "special:minimized"; });
                            if (mini) { Shell.restoreWindow(dock.hyprOf(mini)); return; }
                            const i = w.findIndex(x => x.activated);
                            Shell.focusWindow(dock.hyprOf(w[(i + 1) % w.length]));
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.MiddleButton
                        onTapped: { if (parent.entry) Usage.launch(parent.entry); }   // new window
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: { previewDelay.stop(); dock.openPopup("menu", tile.modelData, tile); }
                    }
                    TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: { previewDelay.stop(); dock.openPopup("menu", tile.modelData, tile); } }
                    // drop files on the tile: open them with this app
                    DropArea {
                        anchors.fill: parent
                        onEntered: drag => drag.accept(Qt.CopyAction)
                        onDropped: drop => {
                            if (!drop.hasUrls || !tile.entry) return;
                            Quickshell.execDetached(["gtk-launch", tile.entry.id].concat(drop.urls.map(u => u.toString())));
                        }
                    }
                }
            }
            Rectangle { width: 1; height: 40; anchors.verticalCenter: parent.verticalCenter; color: Theme.glassLine }
            Rectangle {
                width: 58; height: 58; radius: 17
                color: trashHover.hovered ? Theme.ink(0.10) : Theme.ink(0.07)
                border.width: 1; border.color: Theme.ink(0.06)
                Sym { anchors.centerIn: parent; code: AppSymbols.trash; font.pixelSize: Theme.px(27); color: Theme.muted }
                HoverHandler { id: trashHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Quickshell.execDetached(["gio", "open", "trash:///"]) }
                // drop files on the Trash: move them there
                DropArea {
                    anchors.fill: parent
                    onEntered: drag => drag.accept(Qt.MoveAction)
                    onDropped: drop => { if (drop.hasUrls) Quickshell.execDetached(["gio", "trash"].concat(drop.urls.map(u => u.toString()))); }
                }
            }
        }
    }
}
