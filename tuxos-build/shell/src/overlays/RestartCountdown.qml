import QtQuick
import qs.theme
import qs.components
import qs.services

// Super + ` (SPEC, mockup desktop-v7-restart): "Restarting in 10 s" with a
// bar that drains over the 10 seconds; Esc cancels, Enter restarts now.
OverlayWindow {
    id: ov
    name: "restart"

    property real left: 10
    onOpened: { left = 10; drain.restart(); keyCatcher.forceActiveFocus(); }
    onClosing: drain.stop()
    NumberAnimation {
        id: drain
        target: ov; property: "left"; from: 10; to: 0; duration: 10000
        onFinished: if (ov.active) ov.go()
    }
    function go() { ov.close(); Shell.showOverlay("shutdown", "reboot"); }

    Item {
        id: keyCatcher
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { ov.close(); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { ov.go(); event.accepted = true; }
        }
    }

    Card {
        anchors.centerIn: parent
        width: 420; height: 230
        Column {
            anchors { fill: parent; margins: 28 }
            spacing: 12
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 46; height: 46; radius: 23
                color: Theme.accent
                Sym { anchors.centerIn: parent; code: Icons.restart; color: Theme.accentInk; font.pixelSize: Theme.px(22) }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `Restarting in ${Math.ceil(ov.left)} s`
                font.family: Theme.font; font.pixelSize: Theme.px(22); font.weight: Font.DemiBold; color: Theme.text
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Tr.t("Unsaved work in open apps will be lost.")
                font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted
            }
            Rectangle {
                width: parent.width; height: 6; radius: 3
                color: Theme.ink(0.10)
                Rectangle { width: parent.width * ov.left / 10; height: 6; radius: 3; color: Theme.accent }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                Rectangle {
                    width: 160; height: 38; radius: 12
                    color: ch.hovered ? Theme.fillHover : Theme.fill
                    border.width: 1; border.color: Theme.glassLine
                    Row { anchors.centerIn: parent; spacing: 8
                        Rectangle { width: k1.implicitWidth + 10; height: 18; radius: 5; color: Theme.ink(0.10); anchors.verticalCenter: parent.verticalCenter
                            Text { id: k1; anchors.centerIn: parent; text: Tr.t("Esc"); font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.muted } }
                        Text { text: Tr.t("Cancel"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                    }
                    HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: ov.close() }
                }
                Rectangle {
                    width: 180; height: 38; radius: 12
                    color: Theme.accent
                    Row { anchors.centerIn: parent; spacing: 8
                        Rectangle { width: k2.implicitWidth + 10; height: 18; radius: 5; color: Qt.rgba(0, 0, 0, 0.15); anchors.verticalCenter: parent.verticalCenter
                            Text { id: k2; anchors.centerIn: parent; text: Tr.t("Enter"); font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.accentInk } }
                        Text { text: Tr.t("Restart now"); font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.accentInk }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: ov.go() }
                }
            }
        }
    }
}
