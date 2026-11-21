import QtQuick
import qs.theme

// A rounded card holding SettingRows (and a caps header above it).
Column {
    id: card
    property string header: ""
    default property alias rows: inner.data
    width: parent ? parent.width : 800
    spacing: 8
    Text {
        visible: card.header !== ""
        text: Tr.t(card.header).toUpperCase()
        font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2
        color: Theme.muted
        topPadding: 8
    }
    Rectangle {
        width: parent.width
        height: inner.implicitHeight
        radius: 18
        color: Theme.ink(0.035)
        border.width: 1; border.color: Theme.glassLine
        Column { id: inner; width: parent.width }
    }
}
