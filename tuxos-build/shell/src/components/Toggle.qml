import QtQuick
import qs.theme
import qs.components

// On / off switch (blue when on).
Rectangle {
    id: toggle
    property bool checked: false
    signal toggled(bool value)
    // screen readers: named after its settings row
    property string label: ""
    Accessible.role: Accessible.CheckBox
    Accessible.name: label !== "" ? label : (parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : "")
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: toggled(!checked)
    Accessible.onPressAction: toggled(!checked)

    implicitWidth: 40
    implicitHeight: 24
    radius: height / 2
    color: checked ? Theme.accent : Theme.ink(0.12)
    // keyboard: Tab reaches it (a blue ring), Space flips it
    activeFocusOnTab: true
    border.width: activeFocus ? 2 : 0; border.color: Theme.accentLine
    Keys.onPressed: e => { if (e.key === Qt.Key_Space || e.key === Qt.Key_Return) { toggle.toggled(!toggle.checked); e.accepted = true; } }
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Rectangle {
        width: 18; height: 18; radius: 9
        y: 4
        x: toggle.checked ? toggle.width - width - 3 : 3
        color: toggle.checked ? Theme.accentInk : "#c6cfdb"
        Behavior on x { enabled: !Theme.reduceMotion; Spring {} }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled(!toggle.checked)
    }
}
