import QtQuick
import Quickshell.Io
import qs.theme

// Quick look (Space): the selected item big over the window - pictures at
// full size, the start of text files, otherwise its symbol and details.
// Space or Esc closes; arrows move to the next item.
Rectangle {
    id: ql
    property var view
    readonly property var it: { const i = view.indexOfPath(view.focusPath); return i >= 0 ? view.itemAt(i) : null; }
    readonly property string kind: it ? view.kindOf(it) : ""
    color: Qt.rgba(0, 0, 0, 0.55)
    radius: 18
    TapHandler { onTapped: ql.view.quickLook = false }

    FileView {
        id: textFile
        path: ql.visible && ql.it && (ql.kind === "text" || ql.kind === "code") && ql.it.size < 2000000 ? ql.it.path : ""
        printErrors: false
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.78; height: parent.height * 0.84; radius: 20
        color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
        Text {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            text: ql.it ? ql.it.name + "   ·   " + (ql.it.dir ? "" : ql.view.size(ql.it.size)) : ""
            elide: Text.ElideMiddle
            font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text
        }
        Item {
            anchors { fill: parent; margins: 16; topMargin: 52 }
            clip: true
            Image {
                anchors.fill: parent
                visible: ql.kind === "image"
                source: ql.visible && ql.kind === "image" ? "file://" + ql.it.path : ""
                sourceSize: Qt.size(1600, 1200)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
            Text {
                anchors.fill: parent
                visible: ql.kind === "text" || ql.kind === "code"
                text: textFile.loaded ? textFile.text().slice(0, 12000) : ""
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Theme.px(13); color: Theme.text
                wrapMode: Text.WrapAnywhere
                textFormat: Text.PlainText
            }
            Column {
                anchors.centerIn: parent
                visible: ql.kind !== "image" && ql.kind !== "text" && ql.kind !== "code"
                spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(ql.view.symbols[ql.kind] || 0xf0214); font.family: Theme.symbols; font.pixelSize: Theme.px(96); color: Theme.muted }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: ql.it ? Tr.t(ql.view.kindNames[ql.kind]) : ""; font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.muted }
            }
        }
    }
}
