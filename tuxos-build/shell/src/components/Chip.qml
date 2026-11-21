import QtQuick
import qs.theme

// A small toggle chip (status droplet quick toggles): symbol + label, blue when on.
Rectangle {
    property string label
    property int icon
    property bool on: false
    signal hit()
    Accessible.role: Accessible.Button
    Accessible.name: Tr.t(label)
    Accessible.onPressAction: hit()
    width: chipRow.implicitWidth + 24; height: 34; radius: 11
    color: on ? Theme.accent : (chH.hovered ? Theme.fillHover : Theme.fill)
    border.width: on ? 0 : 1; border.color: Theme.glassLine
    Row { id: chipRow; anchors.centerIn: parent; spacing: 4
        Sym { code: parent.parent.icon; font.pixelSize: Theme.px(14); color: parent.parent.on ? Theme.accentInk : Theme.text }
        Text { text: Tr.t(parent.parent.label); font.family: Theme.font; font.pixelSize: Theme.px(13); color: parent.parent.on ? Theme.accentInk : Theme.text }
    }
    HoverHandler { id: chH; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: parent.hit() }
}
