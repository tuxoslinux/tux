import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Emoji picker (Super + ., mockup shell2/09-emoji): search by name,
// categories, recently used first; Enter / click types it into the app
// underneath (and copies it).
OverlayWindow {
    id: ov
    name: "emoji"

    property var all: []
    property var recent: []
    property string cat: "Recent"
    property int sel: 0
    readonly property var cats: [["Recent", Icons.clockOutline], ["Smileys", Icons.emoticonHappyOutline], ["People", Icons.account], ["Nature", Icons.flag],
                                 ["Food", Icons.foodApple], ["Activities", Icons.gamepadVariant], ["Travel", Icons.car], ["Objects", Icons.lightningBolt],
                                 ["Symbols", Icons.heart], ["Flags", Icons.flag]]
    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        if (q) return all.filter(e => e[1].indexOf(q) !== -1).slice(0, 80);
        if (cat === "Recent") return recent.length ? recent.map(r => all.find(e => e[0] === r)).filter(e => e) : all.filter(e => e[2] === "Smileys").slice(0, 40);
        return all.filter(e => e[2] === cat);
    }

    FileView {
        path: Qt.resolvedUrl("../assets/emoji.json").toString().replace("file://", "")
        onLoaded: ov.all = JSON.parse(text())
    }
    FileView {
        id: recentFile
        path: Quickshell.statePath("emoji-recent.json")
        printErrors: false
        onLoaded: { try { ov.recent = JSON.parse(text()); } catch (e) {} }
    }
    onOpened: { search.text = ""; sel = 0; cat = recent.length ? "Recent" : "Smileys"; search.forceActiveFocus(); }

    function insert(e) {
        if (!e) return;
        const r = [e[0]].concat(recent.filter(x => x !== e[0])).slice(0, 32);
        recent = r;
        recentFile.setText(JSON.stringify(r));
        ov.close();
        Quickshell.clipboardText = e[0];
        Quickshell.execDetached(["sh", "-c", "sleep 0.25; wtype \"$1\"", "sh", e[0]]);
    }

    Card {
        anchors.centerIn: parent
        width: 420
        height: col.implicitHeight + 32
        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 8
            Rectangle {
                width: parent.width; height: 42; radius: 13
                color: Theme.ink(0.05); border.width: 1; border.color: Theme.accentLine
                Sym { id: mg; code: Icons.magnify; color: Theme.accent; font.pixelSize: Theme.px(16); anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } }
                TextInput {
                    id: search
                    anchors { left: mg.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.text; clip: true
                    onTextChanged: ov.sel = 0
                    Keys.onPressed: event => {
                        const n = ov.shown.length;
                        if (event.key === Qt.Key_Escape) { ov.close(); event.accepted = true; }
                        else if (event.key === Qt.Key_Right) { ov.sel = Math.min(n - 1, ov.sel + 1); event.accepted = true; }
                        else if (event.key === Qt.Key_Left) { ov.sel = Math.max(0, ov.sel - 1); event.accepted = true; }
                        else if (event.key === Qt.Key_Down) { ov.sel = Math.min(n - 1, ov.sel + 9); event.accepted = true; }
                        else if (event.key === Qt.Key_Up) { ov.sel = Math.max(0, ov.sel - 9); event.accepted = true; }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { ov.insert(ov.shown[ov.sel]); event.accepted = true; }
                        else if (event.key === Qt.Key_Tab) { const i = ov.cats.findIndex(c => c[0] === ov.cat); ov.cat = ov.cats[(i + 1) % ov.cats.length][0]; ov.sel = 0; event.accepted = true; }
                    }
                    Text { visible: search.text.length === 0; text: Tr.t("Search emoji"); font: search.font; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Row {
                spacing: 4
                visible: search.text.length === 0
                Repeater {
                    model: ov.cats
                    delegate: Rectangle {
                        required property var modelData
                        width: 38; height: 32; radius: 9
                        color: ov.cat === modelData[0] ? Theme.accentFill : (ch.hovered ? Theme.fill : "transparent")
                        Sym { anchors.centerIn: parent; code: modelData[1]; font.pixelSize: Theme.px(15); color: ov.cat === modelData[0] ? Theme.accent : Theme.muted }
                        HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { ov.cat = modelData[0]; ov.sel = 0; search.forceActiveFocus(); } }
                    }
                }
            }
            GridView {
                id: grid
                width: parent.width
                height: 6 * 42
                cellWidth: Math.floor(width / 9); cellHeight: 42
                clip: true
                model: ov.shown
                currentIndex: ov.sel
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: grid.cellWidth - 2; height: 40; radius: 10
                    color: ov.sel === index ? Theme.accentFill : (eh.hovered ? Theme.fill : "transparent")
                    border.width: ov.sel === index ? 1 : 0; border.color: Theme.accentLine
                    Text { anchors.centerIn: parent; text: modelData[0]; font.family: "Noto Color Emoji"; font.pixelSize: Theme.px(24) }
                    HoverHandler { id: eh; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) ov.sel = index }
                    TapHandler { onTapped: ov.insert(modelData) }
                }
            }
            Item {
                width: parent.width; height: 18
                Text { text: ov.shown[ov.sel] ? ov.shown[ov.sel][1] : ""; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                Text { anchors.right: parent.right; text: Tr.t("Enter to insert"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim }
            }
        }
    }
}
