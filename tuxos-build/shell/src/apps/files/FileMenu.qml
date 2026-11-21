import QtQuick
import Quickshell
import qs.theme
import qs.components

// Right-click menu of Files: on an item (open, open in terminal / with,
// copy, cut, rename, compress / extract, copy path, Trash) or on empty
// space (paste, new folder, terminal here, hidden files).
Rectangle {
    id: m
    property var view
    property var it: null
    visible: false
    z: 50
    width: 230
    height: col.implicitHeight + 12
    radius: 14
    color: Theme.glassPanel
    border.width: 1; border.color: Theme.glassLine
    function show(item, x, y) {
        it = item;
        this.x = Math.min(x, parent.width - width - 8);
        this.y = Math.min(y, parent.height - height - 8);
        visible = true;
        catcher.forceActiveFocus();
    }
    function close() { visible = false; }
    readonly property bool archive: it && !it.dir && view.kindOf(it) === "archive"
    readonly property var entries: {
        if (!it) return [["Paste", "paste", 0xf0192], ["New folder", "newFolder", 0xf0b9d], ["Open terminal here", "terminal", 0xf018d], [view.hidden ? "Hide hidden files" : "Show hidden files", "hidden", 0xf0208]].concat(view.inTrash ? [["Empty the Trash", "empty", 0xf0a7a]] : []);
        if (view.inTrash) return [["Restore", "restore", 0xf099b], ["Delete for good", "trash", 0xf09e7]];
        return [["Open", "open", 0xf0214], ["Quick look", "quick", 0xf0208], ["Copy", "copy", 0xf018f], ["Cut", "cut", 0xf0190], ["Rename", "rename", 0xf03eb]]
            .concat(archive ? [["Extract here", "extract", 0xf05c4]] : [["Compress to .zip", "compress", 0xf05c4]])
            .concat([["Copy path", "path", 0xf0bc5], ["Move to Trash", "trash", 0xf0a7a]]);
    }
    function run(what) {
        close();
        const v = view;
        if (what === "open") v.open(it);
        else if (what === "quick") v.quickLook = true;
        else if (what === "copy") v.copy(false);
        else if (what === "cut") v.copy(true);
        else if (what === "rename") v.renaming = it.path;
        else if (what === "extract") v.extract(it.path);
        else if (what === "compress") v.compress();
        else if (what === "path") { Quickshell.clipboardText = it.path; v.flash(Tr.t("Path copied")); }
        else if (what === "trash") v.trash();
        else if (what === "restore") v.restore();
        else if (what === "paste") v.paste();
        else if (what === "newFolder") v.newFolder();
        else if (what === "terminal") v.terminalHere();
        else if (what === "hidden") v.hidden = !v.hidden;
        else if (what === "empty") v.emptyTrash();
    }
    Item { id: catcher; focus: m.visible; Keys.onEscapePressed: m.close() }
    // clicking anywhere else closes it
    MouseArea { parent: m.parent; anchors.fill: parent; z: 49; visible: m.visible; acceptedButtons: Qt.AllButtons; onPressed: m.close() }
    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
        Repeater {
            model: m.entries
            delegate: Rectangle {
                required property var modelData
                width: col.width; height: 36; radius: 9
                color: eh.hovered ? Theme.fillHover : "transparent"
                Row {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 12
                    Text { text: String.fromCodePoint(modelData[2]); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: modelData[1] === "trash" ? Theme.danger : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: Tr.t(modelData[0]); font.family: Theme.font; font.pixelSize: Theme.px(14); color: modelData[1] === "trash" ? Theme.danger : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                }
                HoverHandler { id: eh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: m.run(modelData[1]) }
            }
        }
    }
}
