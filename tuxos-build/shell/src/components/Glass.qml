import QtQuick
import qs.theme

// The shell's one glass surface. The blur itself comes from the compositor
// (the window's BackgroundEffect.blurRegion / Hyprland layer blur); this
// item adds the tint, the thin edge and the faint top highlight.
Rectangle {
    id: glass
    radius: Theme.barRadius
    color: Theme.glass
    border.width: 1
    border.color: Theme.glassLine

    Rectangle {
        // 1 px highlight along the top edge
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: glass.radius / 2 }
        anchors.topMargin: 1
        height: 1
        color: Theme.glassHighlight
    }
}
