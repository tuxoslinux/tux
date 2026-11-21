import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Quick notes (Super + Shift + N): a glass note pad dropping from the top,
// saved as you type to ~/Notes/Quick notes.md (plain Markdown, opens in any
// editor). Esc closes.
OverlayWindow {
    id: ov
    name: "notes"
    dimAlpha: 0.2

    readonly property string dir: Quickshell.env("HOME") + "/Notes"
    FileView {
        id: file
        path: ov.dir + "/Quick notes.md"
        blockLoading: true
        onLoadFailed: {}
    }
    Timer { id: save; interval: 600; onTriggered: { Quickshell.execDetached(["mkdir", "-p", ov.dir]); file.setText(area.text); saved.opacity = 1; fadeSaved.restart(); } }
    onOpened: { file.reload(); area.text = file.text(); area.cursorPosition = area.text.length; area.forceActiveFocus(); }
    onClosing: if (save.running) { save.stop(); file.setText(area.text); }

    Card {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barTop + Theme.barHeight + 14
        width: Math.min(620, parent.width - 48); height: Math.min(460, parent.height - 140)
        Row {
            x: 20; y: 16; spacing: 8
            Sym { code: Icons.noteEditOutline; color: Theme.accent; font.pixelSize: Theme.px(19) }
            Text { text: Tr.t("Quick notes"); font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text }
        }
        Text {
            id: saved
            anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 20 }
            text: Tr.t("Saved to ~/Notes")
            font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted
            opacity: 0.6
            NumberAnimation on opacity { id: fadeSaved; to: 0.6; duration: 1200 }
        }
        Flickable {
            id: fl
            anchors { fill: parent; topMargin: 56; margins: 20 }
            contentHeight: area.implicitHeight
            clip: true
            TextEdit {
                id: area
                width: fl.width
                wrapMode: TextEdit.Wrap
                font.family: Theme.font; font.pixelSize: Theme.px(15)
                color: Theme.text
                selectionColor: Theme.accentDeep
                onTextChanged: if (activeFocus) save.restart()
                onCursorRectangleChanged: { if (cursorRectangle.y + 24 > fl.contentY + fl.height) fl.contentY = cursorRectangle.y + 24 - fl.height; }
                Keys.onEscapePressed: ov.close()
                Text {
                    visible: area.text.length === 0
                    text: Tr.t("Write anything. It is kept in ~/Notes/Quick notes.md")
                    font: area.font; color: Theme.dim
                }
            }
        }
    }
}
