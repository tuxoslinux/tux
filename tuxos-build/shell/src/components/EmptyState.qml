import QtQuick
import qs.theme

// "Nothing here" with the line-art Tux (SPEC polish: empty states):
// EmptyState { title: "No songs yet"; hint: "Put music in ~/Music" }
Column {
    id: es
    property string title: ""
    property string hint: ""
    property real size: 72
    spacing: 8
    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        source: Qt.resolvedUrl(Theme.light ? "../assets/tux-line-dark.svg" : "../assets/tux-line.svg")
        width: es.size; height: es.size * 84 / 72
        sourceSize: Qt.size(es.size * 2, es.size * 168 / 72)
        opacity: 0.55
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Tr.t(es.title); font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text }
    Text { anchors.horizontalCenter: parent.horizontalCenter; visible: es.hint !== ""; text: Tr.t(es.hint); width: Math.min(implicitWidth, 420); wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
}
