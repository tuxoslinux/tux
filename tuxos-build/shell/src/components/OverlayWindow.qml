import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Base of the shell's full-screen overlays (power menu, restart countdown,
// clipboard, emoji, Alt + Tab, Mission Control, ...): on the focused
// screen, dimmed desktop (sharp; only the glass cards are blurred), keyboard
// grabbed, Esc or a click outside closes, fade + slight grow in.
PanelWindow {
    id: ov

    property string name: ""
    property real dimAlpha: 0.32
    property bool closeOnOutside: true
    default property alias content: holder.data
    readonly property bool active: Shell.overlay === name
    property bool shownState: false
    signal opened()
    signal closing()

    screen: Quickshell.screens.find(s => s.name === Shell.overlayScreen) || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shownState || fader.running
    WlrLayershell.namespace: "tuxov-" + name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onActiveChanged: {
        shownState = active;
        if (active) { keys.forceActiveFocus(); opened(); }
        else closing();
    }
    function close() { Shell.hideOverlay(name); }
    // loaded on first use: already active when created
    Component.onCompleted: if (active) { shownState = true; Qt.callLater(() => { opened(); }); }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, ov.dimAlpha)
        opacity: ov.shownState ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fader; duration: Theme.fade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
        MouseArea { anchors.fill: parent; enabled: ov.closeOnOutside; onClicked: ov.close() }
    }
    Item {
        id: holder
        anchors.fill: parent
        opacity: ov.shownState ? 1 : 0
        scale: ov.shownState ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
        Behavior on scale { enabled: !Theme.reduceMotion; Spring { unit: true } }
        // Esc from a focused child (a text field) bubbles up to here
        Keys.onEscapePressed: ov.close()
    }
    // Esc closes unless a child handles it first
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: ov.close()
    }
}
