import QtQuick
import qs.theme

// Title + one-line description at the top of a settings page.
Column {
    property string title: ""
    property string description: ""
    width: parent ? parent.width : 800
    spacing: 4
    bottomPadding: 4
    Text { text: Tr.t(parent.title); font.family: Theme.font; font.pixelSize: Theme.px(30); font.weight: Font.Bold; color: Theme.text }
    Text { width: parent.width; text: Tr.t(parent.description); wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.muted }
}
