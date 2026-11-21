import QtQuick
import qs.theme
import qs.components

// Horizontal slider 0..1 with a white knob; drag, click or scroll.
Item {
    id: slider
    property real value: 0
    property bool muted: false
    signal moved(real value)
    property string label: ""
    Accessible.role: Accessible.Slider
    Accessible.name: label !== "" ? label : (parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : "")

    implicitWidth: 240
    implicitHeight: 22

    function set(v) { slider.moved(Math.max(0, Math.min(1, v))); }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 6; radius: 3
        color: Theme.ink(0.10)
        Rectangle {
            width: track.width * slider.value
            height: parent.height; radius: 3
            color: slider.muted ? Theme.dim : Theme.accent
            Behavior on width { enabled: !area.pressed && !Theme.reduceMotion; Spring {} }
        }
    }
    Rectangle {
        width: 16; height: 16; radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(slider.width - width, slider.width * slider.value - width / 2))
        color: "white"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.25)
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => slider.set((mouse.x - 6) / slider.width)
        onPositionChanged: mouse => { if (pressed) slider.set((mouse.x - 6) / slider.width); }
        onWheel: wheel => slider.set(slider.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
