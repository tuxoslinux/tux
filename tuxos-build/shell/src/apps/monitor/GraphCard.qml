import QtQuick
import qs.theme
import qs.components

// A rounded card with a title, a right-hand note and a live graph.
Rectangle {
    property string title
    property string note: "last 60 s"
    property var values: []
    property real max: 100
    property color lineColor: Theme.accent
    width: parent ? parent.width : 600; height: 190; radius: 20
    color: Theme.ink(0.035); border.width: 1; border.color: Theme.glassLine
    Text { x: 20; y: 16; text: parent.title; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
    Text { anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 16 } text: parent.note; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
    Graph { anchors { fill: parent; margins: 20; topMargin: 48 } values: parent.values; max: parent.max; color: parent.lineColor; grid: true }
}
