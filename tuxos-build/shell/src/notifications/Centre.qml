import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// Notification centre (Super + N, mockup shell2/02-ncenter): a glass panel on
// the right; focus modes on top (Do not disturb, Work, Gaming, Sleep),
// notifications grouped by app, "Clear all", phone link card at the bottom.
PanelWindow {
    id: win

    readonly property bool active: Shell.overlay === "centre"
    screen: Quickshell.screens.find(s => s.name === Shell.overlayScreen) || Quickshell.screens[0]
    anchors { top: true; bottom: true; right: true }
    margins { top: Theme.barTop + Theme.barHeight + 10; bottom: Theme.edge; right: Theme.edge }
    implicitWidth: 430
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: active || slide.running
    WlrLayershell.namespace: "tuxos-centre"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab { windows: [win]; active: win.active; onCleared: Shell.hideOverlay("centre") }

    Rectangle {
        id: panel
        width: parent.width
        height: parent.height
        x: win.active ? 0 : 450
        Behavior on x { enabled: !Theme.reduceMotion; Spring { id: slide; } }
        radius: Theme.panelRadius
        color: Theme.glassPanel
        border.width: 1
        border.color: Theme.glassLine
        focus: win.active
        Keys.onEscapePressed: Shell.hideOverlay("centre")
        // keyboard / gamepad: up / down pick a notification (blue ring),
        // Enter / A opens it, Delete / X dismisses it, Esc / B closes
        Keys.onUpPressed: panel.pick(-1)
        Keys.onDownPressed: panel.pick(1)
        Keys.onReturnPressed: panel.open()
        Keys.onDeletePressed: panel.dismiss()
        property int sel: -1
        readonly property var flat: Notifs.groups.reduce((a, g) => a.concat(g.items.slice(0, 4)), [])
        function pick(d) { if (flat.length) sel = Math.max(0, Math.min(flat.length - 1, sel < 0 ? 0 : sel + d)); }
        function open() {
            const n = flat[sel];
            if (!n) return;
            const d = n.actions.find(a => a.identifier === "default");
            if (d) d.invoke();
            n.dismiss();
        }
        function dismiss() { const n = flat[sel]; if (n) { n.dismiss(); sel = Math.min(sel, flat.length - 2); } }
        Connections {
            target: Shell
            enabled: win.active
            function onPad(w) {
                if (w === "up") panel.pick(-1); else if (w === "down") panel.pick(1);
                else if (w === "a") panel.open(); else if (w === "x") panel.dismiss();
                else if (w === "b") Shell.hideOverlay("centre");
            }
        }

        Column {
            id: top
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 12

            Item {
                width: parent.width; height: 34
                Text {
                    text: Tr.t("Notifications")
                    font.family: Theme.font; font.pixelSize: Theme.px(21); font.weight: Font.DemiBold
                    color: Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: Notifs.history.length > 0
                    width: clr.implicitWidth + 24; height: 32; radius: 10
                    color: ch.hovered ? Theme.fillHover : Theme.fill
                    border.width: 1; border.color: Theme.glassLine
                    Text { id: clr; anchors.centerIn: parent; text: Tr.t("Clear all"); font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.text }
                    HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Notifs.clearAll() }
                }
            }

            // focus modes
            Row {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [["dnd", "Do not\ndisturb", Icons.bellOff], ["work", "Work", Icons.application], ["gaming", "Gaming", Icons.gamepadVariant], ["sleep", "Sleep", Icons.weatherNight]]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: modelData[0] === "dnd" ? (Notifs.dndUntil > Notifs.now && Notifs.focus === "") || Notifs.focus === "dnd" : Notifs.focus === modelData[0]
                        width: (parent.width - 24) / 4; height: 84; radius: 16
                        color: on ? Theme.accent : (fh.hovered ? Theme.fillHover : Theme.fill)
                        border.width: on ? 0 : 1; border.color: Theme.glassLine
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Sym { anchors.horizontalCenter: parent.horizontalCenter; code: modelData[2]; font.pixelSize: Theme.px(20); color: parent.parent.on ? Theme.accentInk : Theme.text }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData[1]
                                font.family: Theme.font; font.pixelSize: Theme.px(13); font.weight: parent.parent.on ? Font.DemiBold : Font.Normal
                                color: parent.parent.on ? Theme.accentInk : Theme.text
                            }
                        }
                        HoverHandler { id: fh; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (modelData[0] === "dnd") Notifs.toggleDnd();
                                else Notifs.setFocus(parent.on ? "" : modelData[0]);
                            }
                        }
                    }
                }
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: Notifs.focus !== "" ? Notifs.focusInfo[Notifs.focus]
                    : Notifs.dndUntil > Notifs.now ? `Do not disturb until ${Qt.formatTime(new Date(Notifs.dndUntil), "HH:mm")}` : ""
                wrapMode: Text.Wrap
                font.family: Theme.font; font.pixelSize: Theme.px(13)
                color: Theme.muted
                leftPadding: 4
            }
        }

        // grouped history
        Flickable {
            id: list
            anchors { left: parent.left; right: parent.right; top: top.bottom; topMargin: 12; bottom: phone.visible ? phone.top : parent.bottom; bottomMargin: 12; leftMargin: 20; rightMargin: 20 }
            contentHeight: groups.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: groups
                width: parent.width
                spacing: 8
                Repeater {
                    model: Notifs.groups
                    delegate: Rectangle {
                        id: grp
                        required property var modelData
                        width: groups.width
                        height: gcol.implicitHeight + 28
                        radius: 18
                        color: Theme.fill
                        border.width: 1; border.color: Theme.glassLine
                        Column {
                            id: gcol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 16; rightMargin: 16 }
                            spacing: 8
                            Item {
                                width: parent.width; height: 24
                                Row {
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        width: 24; height: 24; radius: 7; color: Theme.ink(0.10)
                                        Text {
                                            anchors.centerIn: parent
                                            readonly property var sym: AppSymbols.forEntry(DesktopEntries.heuristicLookup(grp.modelData.desktopEntry || grp.modelData.app), grp.modelData.desktopEntry || grp.modelData.app)
                                            text: sym.code !== undefined ? String.fromCodePoint(sym.code) : sym.letter
                                            font.family: sym.code !== undefined ? Theme.symbols : Theme.font
                                            font.pixelSize: Theme.px(13); color: Theme.text
                                        }
                                    }
                                    Text { text: grp.modelData.app; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Text {
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    text: `${grp.modelData.items.length} new`
                                    font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted
                                }
                            }
                            Repeater {
                                model: grp.modelData.items.slice(0, 4)
                                delegate: Item {
                                    required property var modelData
                                    width: gcol.width
                                    height: ncol.implicitHeight
                                    Rectangle {
                                        // picked with the keyboard / gamepad
                                        anchors { fill: parent; margins: -6 }
                                        radius: 10
                                        color: "transparent"
                                        border.width: 2; border.color: Theme.accent
                                        visible: panel.flat[panel.sel] === parent.modelData
                                    }
                                    Column {
                                        id: ncol
                                        width: parent.width - 70
                                        spacing: 4
                                        Text { width: parent.width; text: modelData.summary; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
                                        Text { width: parent.width; visible: text.length > 0; text: modelData.body; textFormat: Text.StyledText; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                                    }
                                    Text {
                                        anchors { right: parent.right; top: parent.top }
                                        text: Notifs.ago(Notifs.timeOf(modelData)).replace(" ago", "")
                                        font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim
                                    }
                                    TapHandler {
                                        onTapped: {
                                            const d = modelData.actions.find(a => a.identifier === "default");
                                            if (d) d.invoke();
                                            modelData.dismiss();
                                        }
                                    }
                                    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: modelData.dismiss() }
                                }
                            }
                        }
                    }
                }
            }
        }
        // empty state with line-art Tux
        Column {
            anchors.centerIn: list
            visible: Notifs.history.length === 0
            spacing: 8
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: Qt.resolvedUrl(Theme.light ? "../assets/tux-line-dark.svg" : "../assets/tux-line.svg")
                width: 72; height: 84
                sourceSize: Qt.size(144, 168)
                opacity: 0.55
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Tr.t("All caught up"); font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Tr.t("New notifications show up here"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        }

        // phone link (KDE Connect), shown when a phone is paired and reachable
        Rectangle {
            id: phone
            visible: win.phoneName !== ""
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 }
            height: 132; radius: 18
            color: Theme.fill
            border.width: 1; border.color: Theme.glassLine
            Row {
                anchors { left: parent.left; top: parent.top; margins: 16 }
                spacing: 12
                Rectangle {
                    width: 40; height: 40; radius: 12; color: Theme.ink(0.10)
                    Sym { anchors.centerIn: parent; code: Icons.cellphone; font.pixelSize: Theme.px(21) }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: win.phoneName; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: Tr.t("Connected · phone link"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                }
            }
            Row {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
                spacing: 8
                Repeater {
                    model: [["Send file", Icons.upload, "--share"], ["Clipboard", Icons.contentCopy, "--send-clipboard"], ["Ring phone", Icons.bell, "--ring"]]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 16) / 3; height: 44; radius: 12
                        color: ph.hovered ? Theme.fillHover : Theme.ink(0.06)
                        border.width: 1; border.color: Theme.glassLine
                        Row {
                            anchors.centerIn: parent; spacing: 4
                            Sym { code: modelData[1]; font.pixelSize: Theme.px(15) }
                            Text { text: modelData[0]; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                        }
                        HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (modelData[2] === "--share") Quickshell.execDetached(["sh", "-c", "tuxos-pick openmulti 'Send to your phone' | while read -r f; do kdeconnect-cli -n \"$1\" --share \"$f\"; done", "sh", win.phoneName]);
                                else Quickshell.execDetached(["kdeconnect-cli", "-n", win.phoneName, modelData[2]]);
                            }
                        }
                    }
                }
            }
        }
    }

    property string phoneName: ""
    Process {
        id: phoneProc
        running: win.active
        command: ["sh", "-c", "command -v kdeconnect-cli >/dev/null && kdeconnect-cli -a --name-only 2>/dev/null | head -n1"]
        stdout: StdioCollector { onStreamFinished: win.phoneName = text.trim() }
    }
}
