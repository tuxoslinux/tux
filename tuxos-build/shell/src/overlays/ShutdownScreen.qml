import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Shutdown / restart / log out screen (SPEC round 3): the screen fades to
// black, "Shutting down..." with a small Tux; open apps are asked to close
// first; any that are still open after a few seconds (unsaved work) are
// listed with "Close anyway" and "Cancel"; clicking one cancels and brings
// it forward, to save.
OverlayWindow {
    id: ov
    name: "shutdown"
    dimAlpha: 0.85
    closeOnOutside: false

    readonly property string what: Shell.overlayArg || "poweroff"
    readonly property string title: what === "reboot" ? Tr.t("Restarting...") : what === "logout" ? Tr.t("Logging out...") : Tr.t("Shutting down...")
    readonly property var open: ToplevelManager.toplevels.values
    property bool waiting: false

    onOpened: {
        waiting = false;
        // remember what was open, for "Open your apps again?" at the next login
        Session.save();
        // ask every app to close (they may ask to save)
        for (const t of ToplevelManager.toplevels.values) t.close();
        settle.restart();
    }
    onClosing: settle.stop()
    Timer {
        id: settle
        interval: 4000
        onTriggered: { if (ToplevelManager.toplevels.values.length === 0) ov.finish(); else ov.waiting = true; }
    }
    // everything closed: go on at once
    onOpenChanged: if (active && open.length === 0 && !waiting) Qt.callLater(finish)
    function finish() {
        if (what === "reboot") Power.reboot();
        else if (what === "logout") Power.logout();
        else Power.poweroff();
    }

    Column {
        anchors.centerIn: parent
        spacing: 16
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: Qt.resolvedUrl("../assets/tux.png")
            width: 72; height: 72; sourceSize: Qt.size(144, 144)
            mipmap: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ov.waiting ? Tr.t("These apps are still open") : ov.title
            font.family: Theme.font; font.pixelSize: Theme.px(22); font.weight: Font.DemiBold; color: Theme.text
        }
        Card {
            visible: ov.waiting
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            height: list.implicitHeight + 90
            Column {
                id: list
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 8
                Repeater {
                    model: ov.open
                    delegate: Row {
                        required property var modelData
                        spacing: 12
                        AppTile { size: 34; appId: modelData.appId; entry: DesktopEntries.heuristicLookup(modelData.appId) }
                        Text { anchors.verticalCenter: parent.verticalCenter; width: 320; elide: Text.ElideRight; text: modelData.title || modelData.appId; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                        // click an app: stop here and bring it forward (to save first)
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { const t = parent.modelData; ov.close(); Qt.callLater(() => t.activate()); } }
                    }
                }
            }
            Row {
                anchors { right: parent.right; bottom: parent.bottom; margins: 16 }
                spacing: 8
                Rectangle {
                    width: 110; height: 36; radius: 11
                    color: cancelH.hovered ? Theme.fillHover : Theme.fill; border.width: 1; border.color: Theme.glassLine
                    Text { anchors.centerIn: parent; text: Tr.t("Cancel"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                    HoverHandler { id: cancelH; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: ov.close() }
                }
                Rectangle {
                    width: 140; height: 36; radius: 11
                    color: Qt.rgba(1, 0.48, 0.54, 0.85)
                    Text { anchors.centerIn: parent; text: Tr.t("Close anyway"); font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.accentInk }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: ov.finish() }
                }
            }
        }
    }
}
