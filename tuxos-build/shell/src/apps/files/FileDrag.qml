import QtQuick

// Dragging files out of Files (onto a dock tile, the Trash, a browser, any
// app that takes files): a drag of the item, or of the whole selection when
// the item is part of it, handed to the compositor as a text/uri-list.
Item {
    id: fd
    property var item
    property var view
    anchors.fill: parent

    // the paths the drag carries, fixed when it starts
    property var paths: []
    function uris() {
        return paths.map(p => "file://" + p.split("/").map(encodeURIComponent).join("/")).join("\r\n") + "\r\n";
    }

    Item {
        id: proxy
        width: 1; height: 1
        Drag.active: dh.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.mimeData: ({ "text/uri-list": fd.uris() })
    }
    DragHandler {
        id: dh
        target: proxy
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        onActiveChanged: {
            if (active) {
                const sel = fd.view.selected;
                if (sel.indexOf(fd.item.path) === -1) fd.view.select(fd.item.path, false);
                fd.paths = fd.view.selected.indexOf(fd.item.path) !== -1 ? fd.view.selected.slice() : [fd.item.path];
            } else {
                proxy.x = 0; proxy.y = 0;
            }
        }
    }
}
