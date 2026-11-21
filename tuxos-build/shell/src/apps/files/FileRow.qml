import QtQuick
import qs.theme

// One item in the Files list view: symbol, name, kind, size, modified.
Rectangle {
    id: row
    property var item
    property var view
    readonly property bool sel: view.selected.indexOf(item.path) !== -1
    readonly property string kind: view.kindOf(item)
    height: 40; radius: 10
    color: sel ? Theme.accentFill : (hov.hovered ? Theme.fill : "transparent")
    border.width: sel ? 1 : 0; border.color: Theme.accentLine
    Text { id: sym; x: 12; anchors.verticalCenter: parent.verticalCenter; text: String.fromCodePoint(row.view.symbols[row.kind] || 0xf0214); font.family: Theme.symbols; font.pixelSize: Theme.px(17); color: row.kind === "folder" ? Theme.accent : Theme.muted }
    Text {
        id: nm
        visible: row.view.renaming !== row.item.path
        x: 44; width: parent.width * 0.48 - 44; anchors.verticalCenter: parent.verticalCenter
        text: row.item.name; elide: Text.ElideMiddle
        font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text
    }
    RenameField { visible: !nm.visible; x: 40; width: parent.width * 0.48 - 44; anchors.verticalCenter: parent.verticalCenter; view: row.view; path: row.item.path }
    Text { x: parent.width * 0.50; anchors.verticalCenter: parent.verticalCenter; text: Tr.t(row.view.kindNames[row.kind]); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
    Text { x: parent.width * 0.66; anchors.verticalCenter: parent.verticalCenter; text: row.view.sub(row.item); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
    Text { x: parent.width * 0.78; anchors.verticalCenter: parent.verticalCenter; text: row.view.when(row.item.time); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
    HoverHandler { id: hov }
    FileDrag { item: row.item; view: row.view }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: (ev) => row.view.select(row.item.path, ev.modifiers & Qt.ControlModifier)
        onDoubleTapped: row.view.open(row.item)
    }
    TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: { const ev = point; const p = row.mapToItem(null, ev.position.x, ev.position.y); row.view.menuAt(row.item, p.x, p.y - 55); } } TapHandler { acceptedButtons: Qt.RightButton; onTapped: ev => { const p = row.mapToItem(null, ev.position.x, ev.position.y); row.view.menuAt(row.item, p.x, p.y - 55); } }
}
