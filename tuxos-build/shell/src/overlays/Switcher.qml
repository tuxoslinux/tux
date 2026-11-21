import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Alt + Tab (mockup shell2/03-alttab): window thumbnails in a glass strip,
// most recently used first. Tab / Shift + Tab move while Alt is held;
// releasing Alt switches. Minimized windows come back when chosen.
OverlayWindow {
    id: ov
    name: "switcher"
    dimAlpha: 0.18

    property var list: []
    property int sel: 0

    function build() {
        Hyprland.refreshToplevels();
        const ws = [];
        for (const h of Hyprland.toplevels.values) {
            const o = h.lastIpcObject || {};
            if (!h.wayland) continue;
            ws.push({ h: h, t: h.wayland, order: o.focusHistoryID !== undefined ? o.focusHistoryID : 99, minimized: o.workspace && o.workspace.name === "special:minimized" });
        }
        ws.sort((a, b) => a.order - b.order);
        list = ws;
    }
    onOpened: {
        build();
        const back = Shell.overlayArg && Shell.overlayArg.reverse;
        sel = list.length < 2 ? 0 : (back ? list.length - 1 : 1);
        keyCatcher.forceActiveFocus();
    }
    function step(d) { if (list.length) sel = (sel + d + list.length) % list.length; }
    Connections { target: Shell; function onSwitcherStep(d) { ov.step(d); } }
    function choose() {
        const w = list[sel];
        ov.close();
        if (w) Shell.focusWindowSoon(w.h);
    }

    Item {
        id: keyCatcher
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab) { ov.step(1); event.accepted = true; }
            else if (event.key === Qt.Key_Backtab) { ov.step(-1); event.accepted = true; }
            else if (event.key === Qt.Key_Right) { ov.step(1); event.accepted = true; }
            else if (event.key === Qt.Key_Left) { ov.step(-1); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { ov.choose(); event.accepted = true; }
            else if (event.key === Qt.Key_Escape) { ov.close(); event.accepted = true; }
        }
        Keys.onReleased: event => { if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) { ov.choose(); event.accepted = true; } }
    }

    Card {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, row.implicitWidth + 32)
        height: 214
        visible: ov.list.length > 0
        Flickable {
            anchors { fill: parent; margins: 16 }
            contentWidth: row.implicitWidth
            clip: true
            Row {
                id: row
                spacing: 12
                Repeater {
                    model: ov.list
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: 220; height: 182
                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: ov.sel === index ? Theme.accentFill : (ih.hovered ? Theme.fill : "transparent")
                            border.width: ov.sel === index ? 2 : 0
                            border.color: Theme.accent
                        }
                        WindowThumb {
                            x: 8; y: 8
                            width: 200; height: 125
                            toplevel: modelData.t
                            live: false
                            opacity: modelData.minimized ? 0.55 : 1
                        }
                        Row {
                            x: 12; y: 146
                            spacing: 8
                            AppTile { size: 24; appId: modelData.t.appId; entry: DesktopEntries.heuristicLookup(modelData.t.appId) }
                            Text {
                                width: 170
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.t.title || modelData.t.appId
                                elide: Text.ElideRight
                                font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text
                            }
                        }
                        HoverHandler { id: ih; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { ov.sel = index; ov.choose(); } }
                    }
                }
            }
        }
    }
    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.verticalCenter; topMargin: 120 }
        visible: ov.list.length > 0
        width: hintText.implicitWidth + 28; height: 32; radius: 11
        color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
        Text {
            id: hintText
            anchors.centerIn: parent
            text: Tr.t("Hold Alt and press Tab to move · release Alt to switch")
            font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text
        }
    }
}
