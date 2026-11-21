import QtQuick
import qs.theme

// One row per item: name, a bar (share of the largest) and the figure.
// items: [{ name, value, text }]
Column {
    id: bars
    property var items: []
    property int max: 12
    spacing: 10
    readonly property real peak: items.length ? Math.max(...items.map(i => i.value)) : 1
    Repeater {
        model: bars.items.slice(0, bars.max)
        delegate: Item {
            required property var modelData
            width: bars.width; height: Theme.px(34)
            Text { id: nm; width: parent.width * 0.32; text: modelData.name; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                id: track
                x: nm.width + 12; width: parent.width - nm.width - fig.width - 24; height: Theme.px(8); radius: height / 2
                anchors.verticalCenter: parent.verticalCenter; color: Theme.fill
                Rectangle { width: Math.max(height, parent.width * modelData.value / Math.max(0.0001, bars.peak)); height: parent.height; radius: parent.radius; color: Theme.accent }
            }
            Text { id: fig; width: Theme.px(96); horizontalAlignment: Text.AlignRight; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                   text: modelData.text; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        }
    }
}
