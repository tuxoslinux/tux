import QtQuick
import qs.theme

// One item in the Files grid: a rounded tile with the kind's symbol (folders
// in the accent, images as a small picture), name and size / item count.
Item {
    id: tile
    property var item
    property var view
    readonly property bool sel: view.selected.indexOf(item.path) !== -1
    readonly property string kind: view.kindOf(item)

    Rectangle {
        anchors { fill: parent; margins: 4 }
        radius: 16
        color: tile.sel ? Theme.accentFill : (hov.hovered ? Theme.fill : "transparent")
        border.width: tile.sel ? 1 : 0; border.color: Theme.accentLine
    }
    Rectangle {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16; width: 72; height: 72; radius: 18
        color: tile.kind === "folder" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30) : Theme.ink(0.08)
        clip: true
        Text {
            anchors.centerIn: parent
            visible: thumb.status !== Image.Ready
            text: String.fromCodePoint(tile.view.symbols[tile.kind] || 0xf0214)
            font.family: Theme.symbols; font.pixelSize: Theme.px(30)
            color: tile.kind === "folder" ? Theme.text : Theme.text
        }
        Image {
            id: thumb
            anchors.fill: parent
            visible: status === Image.Ready
            source: tile.kind === "image" && tile.item.size < 40000000 ? "file://" + tile.item.path : ""
            sourceSize: Qt.size(144, 144)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }
    Text {
        id: name
        visible: tile.view.renaming !== tile.item.path
        anchors { top: icon.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
        horizontalAlignment: Text.AlignHCenter
        text: tile.item.name
        elide: Text.ElideMiddle
        font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text
    }
    RenameField { visible: !name.visible; anchors { top: icon.bottom; topMargin: 4; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 } view: tile.view; path: tile.item.path }
    Text {
        anchors { top: name.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
        text: tile.view.sub(tile.item)
        font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim
    }
    HoverHandler { id: hov }
    FileDrag { item: tile.item; view: tile.view }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: (ev) => tile.view.select(tile.item.path, ev.modifiers & Qt.ControlModifier)
        onDoubleTapped: tile.view.open(tile.item)
    }
    TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: { const ev = point; const p = tile.mapToItem(null, ev.position.x, ev.position.y); tile.view.menuAt(tile.item, p.x, p.y - 55); } } TapHandler { acceptedButtons: Qt.RightButton; onTapped: ev => { const p = tile.mapToItem(null, ev.position.x, ev.position.y); tile.view.menuAt(tile.item, p.x, p.y - 55); } }
}
