import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Game launch card (SPEC round 7 #5): while a game started from the shell
// is loading, its cover art and status ("Starting...", "Preparing
// shaders...", "Ready") sit in a glass card in the middle of the screen
// until the game's window appears (90 s at most). Never takes input.
PanelWindow {
    id: win

    readonly property var g: Games.starting
    property var shownGame: null
    onGChanged: if (g) shownGame = g
    screen: Quickshell.screens.find(s => s.name === Shell.focusedScreen) || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: card.opacity > 0
    mask: Region {}
    WlrLayershell.namespace: "tuxos-launchcard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 380; height: 236
        radius: Theme.panelRadius
        color: Theme.glassPanel
        border.width: 1; border.color: Theme.glassLine
        opacity: win.g ? 1 : 0
        scale: win.g ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
        Behavior on scale { enabled: !Theme.reduceMotion; Spring { unit: true } }

        Rectangle {
            id: cover
            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
            width: 132; height: 196; radius: 14
            clip: true
            color: Theme.ink(0.08)
            Image {
                anchors.fill: parent
                source: win.shownGame && win.shownGame.cover ? "file://" + win.shownGame.cover : ""
                sourceSize.height: 392
                fillMode: Image.PreserveAspectCrop
            }
            Sym { anchors.centerIn: parent; visible: !(win.shownGame && win.shownGame.cover); code: Icons.gamepadVariant; font.pixelSize: Theme.px(40); color: Theme.muted }
        }
        Column {
            anchors { left: cover.right; leftMargin: 20; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                width: parent.width
                text: win.shownGame ? win.shownGame.name : ""
                wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.px(20); font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                width: parent.width
                text: win.shownGame ? win.shownGame.source : ""
                font.family: Theme.font; font.pixelSize: Theme.px(13)
                color: Theme.muted
            }
            Item { width: 1; height: 8 }
            Text {
                text: Games.startStatus
                font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.Medium
                color: Games.startStatus === Tr.t("Ready") ? Theme.good : Theme.accent
            }
            // an indeterminate bar while it loads
            Rectangle {
                width: parent.width; height: 4; radius: 2
                color: Theme.ink(0.08)
                clip: true
                Rectangle {
                    id: runner
                    width: parent.width * 0.35; height: parent.height; radius: 2
                    color: Theme.accent
                    visible: Games.startStatus !== Tr.t("Ready")
                    NumberAnimation on x {
                        from: -runner.width; to: runner.parent.width
                        duration: 1400; loops: Animation.Infinite
                        running: card.opacity > 0 && !Theme.reduceMotion
                    }
                }
            }
        }
    }
}
