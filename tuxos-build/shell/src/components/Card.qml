import QtQuick
import qs.theme

// A glass card on an overlay (the one glass; the compositor blurs behind it).
Rectangle {
    radius: Theme.panelRadius
    color: Theme.glassPanel
    border.width: 1
    border.color: Theme.glassLine
    MouseArea { anchors.fill: parent; z: -1 }   // clicks on the card never close the overlay
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: parent.radius; rightMargin: parent.radius; topMargin: 1 }
        height: 1
        color: Theme.glassHighlight
    }
}
