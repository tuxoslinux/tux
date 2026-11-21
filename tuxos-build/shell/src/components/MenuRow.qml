import QtQuick
import qs.theme

// One row of a shell menu (dock right-click, bar menus): symbol, label;
// red for destructive rows.
Rectangle {
    property string label
    property int icon: 0
    property bool danger: false
    signal hit()
    Accessible.role: Accessible.MenuItem
    Accessible.name: Tr.t(label)
    Accessible.onPressAction: hit()
    width: parent ? parent.width : 220; height: 36; radius: 11
    color: mh.hovered ? (danger ? Qt.rgba(1, 0.48, 0.54, 0.18) : Theme.fillHover) : "transparent"
    Row {
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 8
        Sym { code: parent.parent.icon; font.pixelSize: Theme.px(15); color: parent.parent.danger ? Theme.danger : Theme.muted; width: 18 }
        Text { text: Tr.t(parent.parent.label); font.family: Theme.font; font.pixelSize: Theme.px(14); color: parent.parent.danger ? Theme.danger : Theme.text }
    }
    HoverHandler { id: mh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: parent.hit() }
}
