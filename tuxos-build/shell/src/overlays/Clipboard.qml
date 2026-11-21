import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Clipboard history (Super + C, mockup shell2/08-clip): everything copied
// since the computer started, kept in RAM only ($XDG_RUNTIME_DIR, gone at
// shutdown); password managers' copies are skipped (cliphist honours their
// "secret" hint). Search, filters (All / Text / Images / Links / Pinned),
// Enter pastes into the app, Ctrl + P pins, Delete removes.
OverlayWindow {
    id: ov
    name: "clipboard"

    readonly property string db: Quickshell.env("XDG_RUNTIME_DIR") + "/tuxos-clipboard.db"
    readonly property string pinFile: Quickshell.env("XDG_RUNTIME_DIR") + "/tuxos-clipboard-pins.json"
    property var entries: []          // { id, text, image, link }
    property var pins: []             // ids
    property string filter: "All"
    property int sel: 0

    readonly property var shown: {
        const q = search.text.toLowerCase();
        const hits = entries.filter(e => {
            if (filter === "Text" && (e.image || e.link)) return false;
            if (filter === "Images" && !e.image) return false;
            if (filter === "Links" && !e.link) return false;
            if (filter === "Pinned" && pins.indexOf(e.id) === -1) return false;
            return !q || e.text.toLowerCase().indexOf(q) !== -1;
        });
        // pinned first, otherwise newest first (no sort: it is not stable here)
        return hits.filter(e => pins.indexOf(e.id) !== -1).concat(hits.filter(e => pins.indexOf(e.id) === -1));
    }

    onOpened: { search.text = ""; sel = 0; filter = "All"; lister.running = true; pinsFile.reload(); search.forceActiveFocus(); }

    Process {
        id: lister
        command: ["cliphist", "-db-path", ov.db, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                ov.entries = text.split("\n").filter(l => l.length).slice(0, 200).map(l => {
                    const tab = l.indexOf("\t");
                    const id = l.slice(0, tab), t = l.slice(tab + 1);
                    const img = /^\[\[ binary data .* (png|jpe?g|webp|bmp|gif)/i.exec(t);
                    return { id: id, text: t, image: img !== null, link: /^(https?|ftp):\/\/\S+$/.test(t.trim()) };
                });
            }
        }
    }
    FileView {
        id: pinsFile
        path: ov.pinFile
        printErrors: false      // no pins yet
        onLoaded: { try { ov.pins = JSON.parse(text()); } catch (e) { ov.pins = []; } }
    }
    function togglePin(id) {
        const p = pins.slice();
        const i = p.indexOf(id);
        if (i === -1) p.push(id); else p.splice(i, 1);
        pins = p;
        pinsFile.setText(JSON.stringify(p));
    }
    function remove(id) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$2\" | cliphist -db-path \"$1\" delete", "sh", db, id]);
        entries = entries.filter(e => e.id !== id);
    }
    // paste: copy it back, close, then type Ctrl + V into the app underneath
    function paste(e) {
        if (!e) return;
        ov.close();
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$2\" | cliphist -db-path \"$1\" decode | wl-copy && sleep 0.25 && wtype -M ctrl -k v -m ctrl", "sh", db, e.id]);
    }
    function ago(e) { return ""; }

    Card {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.18)
        width: Math.min(560, parent.width - 48)
        height: col.implicitHeight + 36
        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 12
            Rectangle {
                width: parent.width; height: 46; radius: 14
                color: Theme.ink(0.05); border.width: 1; border.color: Theme.accentLine
                Sym { id: mg; code: Icons.magnify; color: Theme.accent; font.pixelSize: Theme.px(17); anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } }
                TextInput {
                    id: search
                    anchors { left: mg.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font.family: Theme.font; font.pixelSize: Theme.px(16); color: Theme.text; clip: true
                    onTextChanged: ov.sel = 0
                    Keys.onPressed: event => {
                        const n = ov.shown.length;
                        if (event.key === Qt.Key_Escape) { ov.close(); event.accepted = true; }
                        else if (event.key === Qt.Key_Down) { ov.sel = Math.min(n - 1, ov.sel + 1); event.accepted = true; }
                        else if (event.key === Qt.Key_Up) { ov.sel = Math.max(0, ov.sel - 1); event.accepted = true; }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { ov.paste(ov.shown[ov.sel]); event.accepted = true; }
                        else if (event.key === Qt.Key_Delete && n) { ov.remove(ov.shown[ov.sel].id); event.accepted = true; }
                        else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier) && n) { ov.togglePin(ov.shown[ov.sel].id); event.accepted = true; }
                        else if (event.key === Qt.Key_Tab) {
                            const f = ["All", "Text", "Images", "Links", "Pinned"];
                            ov.filter = f[(f.indexOf(ov.filter) + 1) % f.length]; event.accepted = true;
                        }
                    }
                    Text { visible: search.text.length === 0; text: Tr.t("Search clipboard history"); font: search.font; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Item {
                width: parent.width; height: 30
                Row {
                    spacing: 4
                    Repeater {
                        model: ["All", "Text", "Images", "Links", "Pinned"]
                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool on: ov.filter === modelData
                            width: fl.implicitWidth + 22; height: 30; radius: 10
                            color: on ? Theme.accent : (fh.hovered ? Theme.fillHover : Theme.fill)
                            Text { id: fl; anchors.centerIn: parent; text: modelData; font.family: Theme.font; font.pixelSize: Theme.px(13); font.weight: parent.on ? Font.DemiBold : Font.Normal; color: parent.on ? Theme.accentInk : Theme.text }
                            HoverHandler { id: fh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: { ov.filter = modelData; search.forceActiveFocus(); } }
                        }
                    }
                }
                Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: `Since start · ${ov.entries.length} items · RAM only`; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim }
            }
            ListView {
                id: lv
                width: parent.width
                height: Math.min(6, Math.max(1, count)) * 58
                clip: true
                model: ov.shown
                currentIndex: ov.sel
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool pinned: ov.pins.indexOf(modelData.id) !== -1
                    width: lv.width; height: 54; radius: 13
                    color: ov.sel === index ? Theme.accentFill : (rh.hovered ? Theme.fill : "transparent")
                    border.width: ov.sel === index ? 1 : 0; border.color: Theme.accentLine
                    Rectangle {
                        id: ic
                        width: 36; height: 36; radius: 10
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        color: Theme.ink(0.08)
                        Sym { anchors.centerIn: parent; code: modelData.image ? Icons.imageOutline : modelData.link ? Icons.linkVariant : Icons.textIcon; font.pixelSize: Theme.px(17) }
                    }
                    Text {
                        anchors { left: ic.right; leftMargin: 12; right: tail.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: modelData.image ? modelData.text.replace(/^\[\[ binary data /, "Image · ").replace(/ \]\]$/, "") : modelData.text.replace(/\s+/g, " ")
                        elide: Text.ElideRight
                        font.family: modelData.link || /[{};$]/.test(modelData.text) ? "JetBrainsMono Nerd Font" : Theme.font
                        font.pixelSize: Theme.px(14); color: Theme.text
                    }
                    Row {
                        id: tail
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { visible: ov.sel === index; text: Tr.t("Enter to paste"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Sym {
                            code: parent.parent.pinned ? Icons.pin : Icons.pinOff
                            visible: parent.parent.pinned || rh.hovered
                            font.pixelSize: Theme.px(15); color: parent.parent.pinned ? Theme.accent : Theme.muted
                            TapHandler { onTapped: ov.togglePin(modelData.id) }
                        }
                    }
                    HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: ov.paste(modelData) }
                }
            }
            EmptyState {
                visible: ov.shown.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                size: 48
                title: ov.entries.length === 0 ? "Nothing copied yet" : "No matches"
                hint: ov.entries.length === 0 ? "What you copy is kept here until the PC turns off" : ""
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Tr.t("↑↓ move   Enter paste   Ctrl + P pin   Del remove   Tab filter")
                font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim
            }
        }
    }
}
