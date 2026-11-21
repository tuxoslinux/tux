import QtQuick
import qs.theme

// A one-line text field in the settings style (placeholder, blue ring on focus).
Rectangle {
    id: f
    property alias text: input.text
    property string placeholder: ""
    property alias input: input
    signal accepted()
    implicitWidth: 240; implicitHeight: 34
    radius: 10; color: Theme.ink(0.05); border.width: 1; border.color: input.activeFocus ? Theme.accentLine : Theme.glassLine
    Accessible.role: Accessible.EditableText
    Accessible.name: placeholder
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter; clip: true
        font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text
        selectByMouse: true; selectionColor: Theme.accentFill
        onAccepted: f.accepted()
        Text { visible: !parent.text && !parent.activeFocus; anchors.verticalCenter: parent.verticalCenter; text: f.placeholder; font: parent.font; color: Theme.muted }
    }
}
