import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// App launcher (SPEC "App launcher", mockups desktop-v4-lopen / -lsearch):
// Super alone opens it in the middle of the focused screen over a dimmed
// desktop; typing searches at once; arrows move, Enter opens, Esc / Super
// close. Empty query: all apps as a grid of one-style tiles, most used first.
PanelWindow {
    id: win

    readonly property bool active: Shell.overlay === "launcher"
    property bool shownState: false
    screen: Quickshell.screens.find(s => s.name === Shell.overlayScreen) || Quickshell.screens[0]

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shownState || fade.running
    WlrLayershell.namespace: "tuxov-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // loaded on first open (Desktop.qml), so open at once when created
    Component.onCompleted: openState()
    onActiveChanged: openState()
    function openState() {
        if (active) {
            search.query = "";
            input.text = "";
            sel = 0;
            shownState = true;
            input.forceActiveFocus();
            gamesFocus = false;
        } else { shownState = false; menuEntry = null; }
    }

    Search {
        id: search
        onAction: what => win.doAction(what)
    }
    function close() { Shell.hideOverlay("launcher"); }
    function doAction(what) {
        close();
        if (what === "dnd") Notifs.toggleDnd();
        else if (what.startsWith("focus:")) Notifs.setFocus(what.slice(6));
        else if (what.startsWith("overlay:")) Qt.callLater(() => Shell.showOverlay(what.slice(8)));
        else if (what === "screenshot") Qt.callLater(() => Shell.showOverlay("screenshot"));
        else if (what === "record") Recorder.toggle();
        else if (what === "lock") Power.lock();
        else if (what === "logout") Power.logout();
        else if (what === "suspend") Power.suspend();
        else if (what === "reboot") Qt.callLater(() => Shell.showOverlay("restart"));
        else if (what === "poweroff") Power.poweroff();
        else if (what === "bootmenu") Power.rebootToMenu();
        else if (what === "app:monitor") Apps.openKind("monitor", Prefs.monitorApp);
        else if (what.startsWith("ask:")) Ai.ask(what.slice(4));
    }

    // ---- right-click menu (ctx, inside the card)
    property var menuEntry: null
    property real menuX: 0
    property real menuY: 0
    property var menuItems: []
    function openMenu(e, x, y) {
        const pinned = Prefs.pins.indexOf(e.id) !== -1;
        const items = [
            { label: Tr.t("Open"), icon: Icons.openInNew, run: () => { Usage.launch(e); win.close(); } },
            { label: pinned ? Tr.t("Unpin from the dock") : Tr.t("Pin to the dock"), icon: Icons.pin,
              run: () => { Prefs.pins = pinned ? Prefs.pins.filter(x => x !== e.id) : Prefs.pins.concat([e.id]); } }
        ];
        for (const a of (e.actions || []).slice(0, 4))
            items.push({ label: a.name, icon: Icons.chevronRight, run: () => { Usage.bump(e.id); a.execute(); win.close(); } });
        items.push({ label: Tr.t("Uninstall..."), icon: Icons.deleteOutline, danger: true, run: () => { win.close(); Apps.uninstall(e); } });
        menuItems = items;
        menuX = x; menuY = y;
        menuEntry = e;
    }

    // ---- gamepad: the D-pad moves, A opens, B closes; Y switches between the
    // apps and the games row (then left / right pick a game, A plays it)
    property bool gamesFocus: false
    property int gameSel: 0
    Connections {
        target: Shell
        enabled: win.active
        function onPad(w) {
            if (w === "b") { win.close(); return; }
            if (w === "y" && !win.searching && Games.list.length > 0) { win.gamesFocus = !win.gamesFocus; win.gameSel = 0; return; }
            if (win.gamesFocus) {
                const n = gameRow.count;
                if (w === "left") win.gameSel = Math.max(0, win.gameSel - 1);
                else if (w === "right") win.gameSel = Math.min(n - 1, win.gameSel + 1);
                else if (w === "up") win.gamesFocus = false;
                else if (w === "a") { const g = gameRow.model[win.gameSel]; win.close(); Games.launch(g); }
                gameRow.positionViewAtIndex(win.gameSel, ListView.Contain);
                return;
            }
            if (w === "up") win.move(0, -1); else if (w === "down") win.move(0, 1);
            else if (w === "left") win.move(-1, 0); else if (w === "right") win.move(1, 0);
            else if (w === "a") win.openSel();
        }
    }

    // ---- selection: grid index (no query) or result index
    property int sel: 0
    readonly property bool searching: search.query.trim().length > 0
    readonly property var items: searching ? search.results : search.apps
    readonly property int cols: 6
    function move(dx, dy) {
        const n = items.length;
        if (n === 0) return;
        if (searching) sel = Math.max(0, Math.min(n - 1, sel + dy + dx * 0));
        else sel = Math.max(0, Math.min(n - 1, sel + dx + dy * cols));
        if (!searching) grid.positionViewAtIndex(sel, GridView.Contain);
    }
    function openSel() {
        const it = items[sel];
        if (!it) return;
        if (searching) { it.run(); if (it.tag !== "Answer") close(); }
        else { Usage.launch(it, Qt.point(win.screen.x + win.width / 2, win.screen.y + win.height / 2)); close(); }
    }

    // ---- Konami code: up up down down left right left right b a
    readonly property var konami: [Qt.Key_Up, Qt.Key_Up, Qt.Key_Down, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Left, Qt.Key_Right, Qt.Key_B, Qt.Key_A]
    property int konamiPos: 0
    function konamiKey(k) {
        konamiPos = (k === konami[konamiPos]) ? konamiPos + 1 : (k === konami[0] ? 1 : 0);
        if (konamiPos === konami.length) { konamiPos = 0; tuxRun.restart(); }
    }

    // dimmed desktop; a click outside the card closes
    Rectangle {
        id: dim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.32)
        opacity: win.shownState ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Theme.fade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
        MouseArea { anchors.fill: parent; onClicked: win.close() }
    }

    Rectangle {
        id: card
        width: Math.min(760, win.width - 48)
        height: col.implicitHeight + 44
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(win.height * 0.155)
        radius: Theme.panelRadius
        color: Theme.glassPanel
        border.width: 1
        border.color: Theme.glassLine
        opacity: win.shownState ? 1 : 0
        scale: win.shownState ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
        Behavior on scale { enabled: !Theme.reduceMotion; Spring { unit: true } }
        Behavior on height { enabled: !Theme.reduceMotion; Spring {} }
        clip: true
        MouseArea { anchors.fill: parent; onClicked: win.menuEntry = null }   // clicks inside never close (but close a menu)

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 12

            // ---- search field
            Rectangle {
                width: parent.width
                height: 58
                radius: 18
                color: Theme.ink(0.05)
                border.width: 1
                border.color: Theme.accentLine
                Sym { id: mag; code: Icons.magnify; color: Theme.accent; font.pixelSize: Theme.px(20); anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } }
                TextInput {
                    id: input
                    anchors { left: mag.right; leftMargin: 12; right: hintKey.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font.family: Theme.font
                    font.pixelSize: Theme.px(21)
                    color: Theme.text
                    selectionColor: Theme.accentDeep
                    clip: true
                    onTextChanged: { search.query = text; win.sel = 0; }
                    Keys.onPressed: event => {
                        win.konamiKey(event.key);
                        if (event.key === Qt.Key_Escape) { if (win.menuEntry) win.menuEntry = null; else win.close(); event.accepted = true; }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.openSel(); event.accepted = true; }
                        else if (event.key === Qt.Key_Down) { win.move(0, 1); event.accepted = true; }
                        else if (event.key === Qt.Key_Up) { win.move(0, -1); event.accepted = true; }
                        else if (event.key === Qt.Key_Tab) { win.move(0, 1); event.accepted = true; }
                        else if (!win.searching && event.key === Qt.Key_Right) { win.move(1, 0); event.accepted = true; }
                        else if (!win.searching && event.key === Qt.Key_Left) { win.move(-1, 0); event.accepted = true; }
                    }
                    Text {
                        visible: input.text.length === 0
                        text: Tr.t("Search apps, files and settings")
                        font: input.font
                        color: Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Rectangle {
                    id: hintKey
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    width: hk.implicitWidth + 18; height: 26; radius: 7
                    color: Theme.ink(0.05); border.width: 1; border.color: Theme.glassLine
                    Text { id: hk; anchors.centerIn: parent; text: Tr.t("Super"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                }
            }

            // ---- empty query: the app grid
            Text {
                visible: !win.searching
                text: Tr.t("APPS"); leftPadding: 4
                font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold; letterSpacing: 1.2 }
                color: Theme.muted
            }
            GridView {
                id: grid
                visible: !win.searching
                width: parent.width
                cellWidth: Math.floor(width / win.cols)
                cellHeight: 128
                // rows that fit: two when the games row needs room on a short screen
                readonly property int rows: Games.list.length > 0 && win.height < 1000 ? 2 : 3
                height: Math.min(rows, Math.ceil(count / win.cols)) * cellHeight
                clip: true
                model: win.searching ? [] : search.apps
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: grid.cellWidth; height: grid.cellHeight
                    Rectangle {
                        anchors { fill: parent; margins: 4 }
                        radius: 16
                        color: win.sel === index ? Theme.accentFill : (cellHover.hovered ? Theme.fill : "transparent")
                        border.width: win.sel === index ? 1 : 0
                        border.color: Theme.accentLine
                    }
                    AppTile {
                        id: tile
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 16 }
                        entry: modelData
                        appId: modelData.id
                        size: 62
                    }
                    Text {
                        anchors { top: tile.bottom; topMargin: 12; horizontalCenter: parent.horizontalCenter }
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.name
                        font.family: Theme.font; font.pixelSize: Theme.px(14)
                        color: Theme.text
                    }
                    HoverHandler { id: cellHover }
                    TapHandler { onTapped: { const p = tile.mapToItem(null, tile.width / 2, tile.height / 2); Usage.launch(modelData, Qt.point(win.screen.x + p.x, win.screen.y + p.y)); win.close(); } }
                    TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: { const ev = point; const p = parent.mapToItem(card, ev.position.x, ev.position.y); win.openMenu(modelData, p.x, p.y); } } TapHandler { acceptedButtons: Qt.RightButton; onTapped: ev => { const p = parent.mapToItem(card, ev.position.x, ev.position.y); win.openMenu(modelData, p.x, p.y); } }
                }
            }

            // ---- empty query: the games (cover art), newest played first
            Text {
                visible: !win.searching && Games.list.length > 0
                text: Tr.t("GAMES"); leftPadding: 4; topPadding: 4
                font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold; letterSpacing: 1.2 }
                color: Theme.muted
            }
            ListView {
                id: gameRow
                visible: !win.searching && Games.list.length > 0
                width: parent.width
                height: 150
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.searching ? [] : Games.list.slice().sort((a, b) => Usage.count(b.id) - Usage.count(a.id))
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: 84; height: gameRow.height
                    readonly property var badge: Games.badgeOf(modelData)
                    Rectangle {
                        id: cover
                        width: 84; height: 126; radius: 12
                        clip: true
                        color: Theme.ink(0.08)
                        readonly property bool picked: gh.hovered || (win.gamesFocus && win.gameSel === index)
                        border.width: picked ? 2 : 1
                        border.color: picked ? Theme.accent : Theme.glassLine
                        Image { anchors.fill: parent; anchors.margins: 1; source: modelData.cover ? "file://" + modelData.cover : ""; sourceSize.height: 252; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        Sym { anchors.centerIn: parent; visible: !modelData.cover; code: Icons.gamepadVariant; font.pixelSize: Theme.px(28); color: Theme.muted }
                        // "Will it run?" dot
                        Rectangle { visible: badge !== null; anchors { right: parent.right; top: parent.top; margins: 6 } width: 10; height: 10; radius: 5; color: Games.tierColor(badge); border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.4) }
                        scale: picked ? 1.04 : 1
                        Behavior on scale { enabled: !Theme.reduceMotion; Spring { unit: true } }
                    }
                    Text {
                        anchors { top: cover.bottom; topMargin: 6; horizontalCenter: cover.horizontalCenter }
                        width: 84; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: modelData.name
                        font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.text
                    }
                    HoverHandler { id: gh; cursorShape: Qt.PointingHandCursor }
                    // close first: launching re-sorts this row (most played first)
                    TapHandler { onTapped: { const g = modelData; win.close(); Games.launch(g); } }
                }
            }

            // ---- results
            Column {
                visible: win.searching
                width: parent.width
                spacing: 4
                Text {
                    text: Tr.t("TOP RESULT"); leftPadding: 4
                    visible: win.items.length > 0
                    font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold; letterSpacing: 1.2 }
                    color: Theme.muted
                }
                Repeater {
                    model: win.searching ? win.items.slice(0, 7) : []
                    delegate: Column {
                        id: rowItem
                        required property var modelData
                        required property int index
                        width: parent.width
                        spacing: 4
                        Text {
                            visible: index === 1
                            text: Tr.t("MORE"); leftPadding: 4; topPadding: 8
                            font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold; letterSpacing: 1.2 }
                            color: Theme.muted
                        }
                        ResultRow {
                            width: parent.width
                            item: rowItem.modelData
                            big: rowItem.index === 0
                            selected: win.sel === rowItem.index
                            onClicked: { win.sel = rowItem.index; win.openSel(); }
                        }
                    }
                }
            }

            // ---- key hints
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Repeater {
                    model: [["↑↓←→", "move"], ["Enter", "open"], ["Esc", "close"], ["=", "calculate"]].concat(Theme.lite && !Prefs.aiEnabled ? [] : [["?", "ask"]])
                    delegate: Row {
                        required property var modelData
                        spacing: 4
                        Text { text: modelData[0]; font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; color: Theme.muted }
                        Text { text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim }
                    }
                }
            }
        }

        // ---- right-click menu of an app: open, pin / unpin, its actions, uninstall
        Rectangle {
            id: ctx
            visible: win.menuEntry !== null
            z: 20
            x: Math.min(win.menuX, card.width - width - 8); y: Math.min(win.menuY, card.height - height - 8)
            width: 250; height: ctxCol.implicitHeight + 12; radius: 16
            color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
            Column {
                id: ctxCol
                x: 6; y: 6; width: parent.width - 12
                Repeater {
                    model: win.menuItems
                    delegate: MenuRow {
                        required property var modelData
                        width: ctxCol.width
                        label: modelData.label; icon: modelData.icon || 0; danger: !!modelData.danger
                        onHit: { const r = modelData.run; win.menuEntry = null; r(); }
                    }
                }
            }
        }

        // Konami easter egg: Tux waddles across the launcher
        Image {
            id: tux
            source: Qt.resolvedUrl("../assets/tux.png")
            width: 64; height: 64
            sourceSize: Qt.size(128, 128)
            y: card.height - 80
            x: -80
            visible: tuxRun.running
            SequentialAnimation {
                id: tuxRun
                ParallelAnimation {
                    NumberAnimation { target: tux; property: "x"; from: -80; to: card.width + 20; duration: 2400 }
                    SequentialAnimation {
                        loops: 6
                        NumberAnimation { target: tux; property: "rotation"; from: -10; to: 10; duration: 200 }
                        NumberAnimation { target: tux; property: "rotation"; from: 10; to: -10; duration: 200 }
                    }
                }
            }
        }
    }
}
