import QtQuick
import qs.theme

// A figure with its label (CPU header: Usage 23 %, Speed 5.32 GHz, ...).
Column {
    property string label
    property string value
    spacing: 4
    Text { text: parent.label; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
    Text { text: parent.value; font.family: Theme.font; font.pixelSize: Theme.px(19); font.weight: Font.DemiBold; color: Theme.text }
}
