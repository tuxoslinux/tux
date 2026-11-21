import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Super + Shift + S: the screen dims slightly; one click takes the whole
// screen under the pointer, dragging takes the area; Esc cancels. One of
// these per screen.
PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property bool active: Shell.overlay === "screenshot"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: active
    WlrLayershell.namespace: "tuxov-shot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active && Shell.overlayScreen === screen.name ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onActiveChanged: { sel.visible = false; if (active) keyCatcher.forceActiveFocus(); }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.18) }

    // the chosen area stays clear, with a blue edge
    Rectangle {
        id: sel
        visible: false
        color: Qt.rgba(143 / 255, 184 / 255, 1, 0.08)
        border.width: 2
        border.color: Theme.accent
        radius: 4
        Text {
            anchors { top: parent.bottom; topMargin: 8; right: parent.right }
            text: `${Math.round(sel.width)} × ${Math.round(sel.height)}`
            font.family: Theme.font; font.pixelSize: Theme.px(13); font.weight: Font.DemiBold
            color: Theme.text
            style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.6)
        }
    }

    // hint
    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.barTop + Theme.barHeight + 18 }
        width: hint.implicitWidth + 36; height: 44; radius: 14
        color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
        visible: !sel.visible
        Row {
            id: hint
            anchors.centerIn: parent
            spacing: 8
            Sym { code: Icons.monitorScreenshot; color: Theme.accent; font.pixelSize: Theme.px(18) }
            Text { text: Tr.t("Click: whole screen   ·   Drag: an area   ·   Esc: cancel"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Item {
        id: keyCatcher
        focus: true
        Keys.onEscapePressed: Shell.hideOverlay("screenshot")
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        property point start
        onPressed: m => { start = Qt.point(m.x, m.y); sel.x = m.x; sel.y = m.y; sel.width = 0; sel.height = 0; }
        onPositionChanged: m => {
            sel.x = Math.min(start.x, m.x); sel.y = Math.min(start.y, m.y);
            sel.width = Math.abs(m.x - start.x); sel.height = Math.abs(m.y - start.y);
            sel.visible = sel.width > 4 || sel.height > 4;
        }
        onReleased: {
            const area = sel.visible && sel.width > 4 && sel.height > 4;
            const g = { x: win.screen.x + sel.x, y: win.screen.y + sel.y, w: sel.width, h: sel.height };
            const out = win.screen.name;
            Shell.hideOverlay("screenshot");
            // wait until the overlay is gone from the screen
            later.area = area; later.g = g; later.out = out;
            later.restart();
        }
    }
    Timer {
        id: later
        property bool area
        property var g
        property string out
        interval: 180
        onTriggered: area ? Screenshot.area(g.x, g.y, g.w, g.h) : Screenshot.full(out)
    }
}
