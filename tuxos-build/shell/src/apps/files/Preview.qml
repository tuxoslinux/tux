import QtQuick
import Quickshell
import qs.theme
import qs.components

// The right-hand panel: a preview of the selected item (picture, or its
// symbol), name, kind and size, details (picture size, modified, folder),
// Open / Rename / Trash (Restore in the Trash). Nothing selected: the folder.
Rectangle {
    id: pv
    property var view
    readonly property var it: {
        const p = view.focusPath;
        if (!p) return null;
        const i = view.indexOfPath(p);
        return i >= 0 ? view.itemAt(i) : null;
    }
    readonly property string kind: it ? view.kindOf(it) : "folder"
    radius: 20
    color: Theme.fill
    border.width: 1; border.color: Theme.glassLine

    // details from `file` (picture size, text kind) and `du` for folders
    property string info: ""
    property string dirSize: ""
    Cmd {
        id: infoProc
        command: ["sh", "-c", "file -b -- \"$1\" 2>/dev/null | head -c 200; [ -d \"$1\" ] && printf '\\n%s' \"$(du -sb -- \"$1\" 2>/dev/null | cut -f1)\"", "sh", pv.it ? pv.it.path : ""]
        onDone: out => { const l = out.split("\n"); pv.info = l[0] || ""; pv.dirSize = l[1] || ""; }
    }
    onItChanged: { info = ""; dirSize = ""; if (it) Qt.callLater(() => infoProc.run()); }   // after the command follows the new item
    readonly property string dims: { const m = /(\d+)\s*x\s*(\d+)/.exec(info); return m ? m[1] + " × " + m[2] : ""; }

    Column {
        anchors { fill: parent; margins: 16 }
        spacing: 12
        Rectangle {
            width: parent.width; height: 180; radius: 14
            color: Theme.ink(0.05)
            clip: true
            Image {
                id: big
                anchors.fill: parent
                visible: status === Image.Ready
                source: pv.it && pv.kind === "image" && pv.it.size < 60000000 ? "file://" + pv.it.path : ""
                sourceSize: Qt.size(520, 360)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
            Text {
                anchors.centerIn: parent
                visible: !big.visible
                text: String.fromCodePoint(pv.view.symbols[pv.kind] || 0xf0214)
                font.family: Theme.symbols; font.pixelSize: Theme.px(56)
                color: pv.kind === "folder" ? Theme.accent : Theme.muted
            }
        }
        Column {
            width: parent.width
            spacing: 4
            Text { width: parent.width; text: pv.it ? pv.it.name : pv.view.crumbName(pv.view.cwd); elide: Text.ElideMiddle; font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: pv.it ? Tr.t(pv.view.kindNames[pv.kind]) + (pv.it.dir ? (pv.dirSize ? " · " + pv.view.size(+pv.dirSize) : "") : " · " + pv.view.size(pv.it.size))
                            : Tr.f(pv.view.itemCount === 1 ? "{n} item" : "{n} items", { n: pv.view.itemCount })
                font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted
            }
        }
        Rectangle { width: parent.width; height: 1; color: Theme.glassLine; visible: pv.it !== null }
        Repeater {
            model: pv.it ? [["Size", pv.dims], ["Modified", pv.view.when(pv.it.time)], ["Folder", pv.it.path.substring(0, pv.it.path.lastIndexOf("/")).replace(pv.view.home, "~") || "/"], ["Kind", pv.info.split(",")[0]]].filter(r => r[1]) : []
            delegate: Item {
                required property var modelData
                width: parent.width; height: 22
                Text { text: Tr.t(modelData[0]); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                Text { anchors.right: parent.right; width: parent.width - 90; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; text: modelData[1]; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text }
            }
        }
        Flow {
            width: parent.width
            spacing: 8
            visible: pv.it !== null
            Btn { text: pv.view.inTrash ? "Restore" : "Open"; primary: true; onClicked: pv.view.inTrash ? pv.view.restore() : pv.view.open(pv.it) }
            Btn { visible: !pv.view.inTrash; text: "Rename"; onClicked: pv.view.renaming = pv.it.path }
            Btn { text: pv.view.inTrash ? "Delete" : "Trash"; danger: pv.view.inTrash; onClicked: pv.view.trash() }
        }
    }
}
