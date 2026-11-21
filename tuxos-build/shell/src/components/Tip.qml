import QtQuick
import qs.theme

// A tooltip inside an app window (SPEC polish: tooltips with the shortcut):
// a small glass label under (or above) its parent after a short pause.
// Tip { text: "Close"; keys: "Super + Q"; shown: hover.hovered }
Rectangle {
    id: tip
    property string text: ""
    property string keys: ""
    property bool shown: false
    property bool above: false
    z: 100
    anchors.horizontalCenter: parent.horizontalCenter
    y: above ? -height - 6 : parent.height + 6
    width: row.implicitWidth + 20; height: 28; radius: 9
    color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
    opacity: 0
    visible: opacity > 0
    states: State { when: tip.shown && tip.text !== ""; PropertyChanges { tip.opacity: 1 } }
    transitions: Transition { SequentialAnimation { PauseAnimation { duration: tip.shown ? 450 : 0 } NumberAnimation { property: "opacity"; duration: Theme.fast } } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text { text: Tr.t(tip.text); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.text }
        Text { visible: tip.keys !== ""; text: tip.keys; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
    }
}
