import QtQuick
import qs.theme

// A row of choices, the chosen one filled blue (e.g. power profile).
Rectangle {
    id: seg
    property var options: []       // labels
    property int current: 0
    signal picked(int index)
    property string label: ""
    Accessible.role: Accessible.PageTabList
    Accessible.name: label !== "" ? label : (parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : "")

    implicitHeight: 40
    radius: 14
    color: Theme.ink(0.04)
    // keyboard: Tab reaches it (a blue ring), ← / → pick
    activeFocusOnTab: true
    border.width: activeFocus ? 2 : 0; border.color: Theme.accentLine
    Keys.onLeftPressed: if (current > 0) picked(current - 1)
    Keys.onRightPressed: if (current < options.length - 1) picked(current + 1)

    Row {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4
        Repeater {
            model: seg.options
            delegate: Rectangle {
                required property int index
                required property string modelData
                Accessible.role: Accessible.RadioButton
                Accessible.name: Tr.t(modelData)
                Accessible.checkable: true
                Accessible.checked: index === seg.current
                Accessible.onPressAction: seg.picked(index)
                width: (seg.width - 8 - 4 * (seg.options.length - 1)) / seg.options.length
                height: parent.height
                radius: 11
                color: index === seg.current ? Theme.accent : (cellHover.hovered ? Theme.fillHover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Text {
                    anchors.centerIn: parent
                    text: Tr.t(parent.modelData)
                    font.family: Theme.font
                    font.pixelSize: Theme.px(13)
                    font.weight: parent.index === seg.current ? Font.DemiBold : Font.Normal
                    color: parent.index === seg.current ? Theme.accentInk : Theme.muted
                }
                HoverHandler { id: cellHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: seg.picked(parent.index) }
            }
        }
    }
}
