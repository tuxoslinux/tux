import QtQuick
import qs.theme

// Pick one of many (apps, time zones, resolutions): shows the current
// choice; a click opens the list right under it (type to filter).
Column {
    id: c
    property var options: []          // [{ value, label, sub }]
    property var current: null        // value
    property bool open: false
    signal picked(var value)
    width: 280
    spacing: 4
    readonly property var cur: options.find(o => o.value === current)

    Rectangle {
        width: parent.width; height: 36; radius: 11
        color: hh.hovered ? Theme.fillHover : Theme.ink(0.06)
        border.width: 1; border.color: c.open ? Theme.accentLine : Theme.glassLine
        Text { anchors { left: parent.left; leftMargin: 12; right: arrow.left; rightMargin: 8; verticalCenter: parent.verticalCenter } text: c.cur ? Tr.t(c.cur.label) : Tr.t("Choose"); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
        Text { id: arrow; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: String.fromCodePoint(c.open ? 0xf0143 : 0xf0140); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: Theme.muted }
        HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: { c.open = !c.open; if (c.open) filter.forceActiveFocus(); } }
    }
    Rectangle {
        visible: c.open
        width: parent.width; height: Math.min(8, list.count) * 36 + (c.options.length > 8 ? 44 : 8)
        radius: 12
        color: Theme.ink(0.05); border.width: 1; border.color: Theme.glassLine
        TextInput {
            id: filter
            visible: c.options.length > 8
            x: 12; y: 8; width: parent.width - 24; height: 24
            font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text
            Text { visible: filter.text === ""; text: Tr.t("Type to filter"); font: filter.font; color: Theme.dim }
        }
        ListView {
            id: list
            anchors { fill: parent; topMargin: c.options.length > 8 ? 40 : 4; bottomMargin: 4 }
            clip: true
            model: c.options.filter(o => !filter.text || o.label.toLowerCase().indexOf(filter.text.toLowerCase()) !== -1)
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property var modelData
                width: list.width; height: 36; radius: 9
                color: modelData.value === c.current ? Theme.accentFill : (dh.hovered ? Theme.fill : "transparent")
                Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } width: parent.width - 24; elide: Text.ElideRight; text: Tr.t(modelData.label) + (modelData.sub ? "  ·  " + Tr.t(modelData.sub) : ""); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { c.picked(modelData.value); c.open = false; } }
            }
        }
    }
}
