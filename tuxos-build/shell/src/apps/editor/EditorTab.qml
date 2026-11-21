import QtQuick
import Quickshell.Io
import org.kde.syntaxhighlighting
import qs.theme

// One open file in the Text editor: line numbers, the text with syntax
// colours (KDE syntax-highlighting, theme follows light / dark), its own
// undo history. Tab inserts 4 spaces, Enter keeps the indentation.
Item {
    id: tab
    property string path: ""                // "" = not saved yet
    property bool dirty: false
    property bool loaded: path === ""
    property real zoom: 1.0
    readonly property alias edit: edit
    readonly property string name: path ? path.substring(path.lastIndexOf("/") + 1) : Tr.t("Untitled")
    readonly property string language: hl.definition && hl.definition.name ? hl.definition.name : "Plain text"
    readonly property int line: lineOf(edit.cursorPosition)
    readonly property int column: edit.cursorPosition - edit.text.lastIndexOf("\n", edit.cursorPosition - 1)
    signal saved()

    function lineOf(pos) { return edit.text.slice(0, pos).split("\n").length; }

    FileView {
        id: file
        path: tab.path
        printErrors: false
        blockLoading: true
        onLoaded: { edit.text = text(); tab.dirty = false; tab.loaded = true; edit.cursorPosition = 0; }
        onSaved: { tab.dirty = false; tab.saved(); }
    }
    function save(to) {
        if (to) path = to;
        if (!path) return false;
        file.setText(edit.text);
        return true;
    }

    FontMetrics { id: fmx; font: edit.font }
    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: Math.max(width, gutter.width + edit.contentWidth + 40)
        contentHeight: edit.contentHeight + 80
        boundsBehavior: Flickable.StopAtBounds
        function ensureVisible(r) {
            if (contentX >= r.x + gutter.width - 20) contentX = Math.max(0, r.x + gutter.width - 40);
            else if (contentX + width <= r.x + gutter.width + r.width + 20) contentX = r.x + gutter.width + r.width + 40 - width;
            if (contentY >= r.y) contentY = r.y;
            else if (contentY + height <= r.y + r.height + 24) contentY = r.y + r.height + 24 - height;
        }
        // line numbers
        Column {
            id: gutter
            width: Math.max(3, String(edit.lineCount).length) * fmx.averageCharacterWidth + 28
            y: edit.y + edit.topPadding
            Repeater {
                model: edit.lineCount
                delegate: Text {
                    required property int index
                    width: gutter.width - 16; height: edit.lineCount ? edit.contentHeight / edit.lineCount : fmx.lineSpacing   // the editor's exact line height
                    horizontalAlignment: Text.AlignRight
                    text: index + 1
                    font: edit.font
                    color: index + 1 === tab.line ? Theme.muted : Theme.dim
                }
            }
        }
        TextEdit {
            id: edit
            x: gutter.width; y: 4
            width: Math.max(flick.width - gutter.width, implicitWidth)
            topPadding: 4; leftPadding: 4; rightPadding: 24
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(Theme.px(14) * tab.zoom)
            color: Theme.text
            selectionColor: Theme.accentLine
            selectedTextColor: Theme.text
            selectByMouse: true
            persistentSelection: true
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.NoWrap
            tabStopDistance: fmx.averageCharacterWidth * 4
            onTextChanged: if (tab.loaded) tab.dirty = true
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ControlModifier)) {
                    edit.remove(edit.selectionStart, edit.selectionEnd);
                    edit.insert(edit.cursorPosition, "    ");
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    const t = edit.text, p = edit.cursorPosition;
                    const start = t.lastIndexOf("\n", p - 1) + 1;
                    const indent = /^[ \t]*/.exec(t.slice(start, p))[0];
                    const extra = /[:{\[(]\s*$/.test(t.slice(start, p)) ? "    " : "";
                    edit.remove(edit.selectionStart, edit.selectionEnd);
                    edit.insert(edit.cursorPosition, "\n" + indent + extra);
                    event.accepted = true;
                }
            }
        }
    }
    SyntaxHighlighter {
        id: hl
        textEdit: edit
        definition: Repository.definitionForFileName(tab.path || "untitled.txt")
        theme: Repository.theme(Theme.light ? "Atom One Light" : "Atom One Dark")
    }

    // find / replace / go to line
    function find(q, back) {
        if (!q) return false;
        const t = edit.text.toLowerCase(), s = q.toLowerCase();
        let i = back ? t.lastIndexOf(s, edit.selectionStart - 1) : t.indexOf(s, edit.selectionEnd);
        if (i === -1) i = back ? t.lastIndexOf(s) : t.indexOf(s);         // wrap around
        if (i === -1) return false;
        edit.select(i, i + q.length);
        return true;
    }
    function replace(q, r) {
        if (edit.selectedText.toLowerCase() === q.toLowerCase() && q) {
            const a = edit.selectionStart;
            edit.remove(a, edit.selectionEnd); edit.insert(a, r);
            edit.select(a, a + r.length);
        }
        return find(q, false);
    }
    function replaceAll(q, r) {
        if (!q) return 0;
        const re = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "gi");
        const n = (edit.text.match(re) || []).length;
        if (n) { const p = edit.cursorPosition; edit.text = edit.text.replace(re, r); edit.cursorPosition = Math.min(p, edit.text.length); }
        return n;
    }
    function gotoLine(n) {
        const lines = edit.text.split("\n");
        n = Math.max(1, Math.min(lines.length, n));
        let p = 0; for (let i = 0; i < n - 1; i++) p += lines[i].length + 1;
        edit.cursorPosition = p;
        edit.forceActiveFocus();
    }
}
