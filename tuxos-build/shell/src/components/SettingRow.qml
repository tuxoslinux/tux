import QtQuick
import qs.theme

// One row in a settings card: title, optional description, the control on
// the right (default property). Rows inside a SettingCard get thin dividers.
Item {
    id: row
    property string title: ""
    property string description: ""
    property bool last: false
    default property alias control: slot.data
    width: parent ? parent.width : 600
    height: Math.max(description ? 64 : 52, slot.childrenRect.height + 20)

    Column {
        anchors { left: parent.left; leftMargin: 24; right: slot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 4
        Text { width: parent.width; text: Tr.t(row.title); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.text }
        Text { width: parent.width; visible: row.description !== ""; text: Tr.t(row.description); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
    }
    Item {
        id: slot
        anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
        width: childrenRect.width; height: childrenRect.height
    }
    Rectangle {
        visible: !row.last
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 24; rightMargin: 24 }
        height: 1; color: Theme.glassLine
    }
}
