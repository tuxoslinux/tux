import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Text editor (mockup apps/12-editor): notes and code with syntax colours,
// tabs, the folder of the open file on the left, line numbers, find and
// replace (Ctrl + F / Ctrl + H), go to line (Ctrl + G), open / save as by
// path (Ctrl + O / Ctrl + Shift + S), unsaved changes kept from being lost.
AppWindow {
    id: app
    appName: "Text editor"
    appIcon: 0xf03eb
    subtitle: cur && cur.path ? cur.path.replace(Quickshell.env("HOME"), "~") : ""
    implicitWidth: 1180; implicitHeight: 760

    readonly property string home: Quickshell.env("HOME")
    property var tabs: []                     // EditorTab items
    property int current: 0
    readonly property var cur: tabs.length ? tabs[Math.min(current, tabs.length - 1)] : null
    property string folder: home
    property string prompt: ""                // "open" | "saveas" | "find" | "goto" | "close"
    property string message: ""

    IpcHandler { target: "editor"; function page(id: string): void { app.openPath(id); } }
    Component.onCompleted: {
        const p = Quickshell.env("TUXOS_PAGE") || "";
        if (p) openPath(p); else newTab();
    }

    Component { id: tabComp; EditorTab { id: et; anchors.fill: parent; visible: app.cur === et } }
    function newTab(path) {
        const t = tabComp.createObject(editorArea, { path: path || "" });
        t.saved.connect(() => app.flash(Tr.f("Saved {n}", { n: t.name })));
        tabs = tabs.concat([t]);
        current = tabs.length - 1;
        Qt.callLater(() => t.edit.forceActiveFocus());
        return t;
    }
    function openPath(p) {
        if (!p) return;
        if (p.startsWith("file://")) p = decodeURIComponent(p.slice(7));
        if (p.startsWith("~")) p = home + p.slice(1);
        const i = tabs.findIndex(t => t.path === p);
        if (i !== -1) { current = i; return; }
        // replace an empty untitled tab
        if (cur && !cur.path && !cur.dirty && cur.edit.text === "") { cur.loaded = false; cur.path = p; }
        else newTab(p);
        folder = p.substring(0, p.lastIndexOf("/")) || "/";
    }
    function closeTab(i, force) {
        const t = tabs[i];
        if (!t) return;
        if (t.dirty && !force) { current = i; prompt = "close"; return; }
        tabs = tabs.filter((x, n) => n !== i);
        t.destroy();
        current = Math.max(0, Math.min(current, tabs.length - 1));
        if (!tabs.length) newTab();
    }
    function save(as) {
        if (!cur) return;
        if (!cur.path || as) { prompt = "saveas"; return; }
        cur.save();
    }
    canClose: function() {
        const d = tabs.findIndex(t => t.dirty);
        if (d === -1) return true;
        current = d; prompt = "close"; closingApp = true;
        return false;
    }
    property bool closingApp: false

    function flash(t) { message = t; msgTimer.restart(); }
    Timer { id: msgTimer; interval: 3500; onTriggered: app.message = "" }

    headerAction: Component {
        Btn { text: "Save"; icon: 0xf0193; onClicked: app.save(false) }
    }

    // ---- keyboard shortcuts (work wherever the focus is)
    Shortcut { sequence: "Ctrl+S"; onActivated: app.save(false) }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: app.save(true) }
    Shortcut { sequence: "Ctrl+O"; onActivated: app.prompt = "open" }
    Shortcut { sequence: "Ctrl+N"; onActivated: app.newTab() }
    Shortcut { sequence: "Ctrl+T"; onActivated: app.newTab() }
    Shortcut { sequence: "Ctrl+W"; onActivated: app.closeTab(app.current) }
    Shortcut { sequence: "Ctrl+F"; onActivated: app.prompt = "find" }
    Shortcut { sequence: "Ctrl+H"; onActivated: app.prompt = "find" }
    Shortcut { sequence: "Ctrl+G"; onActivated: app.prompt = "goto" }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: app.current = (app.current + 1) % app.tabs.length }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: app.current = (app.current - 1 + app.tabs.length) % app.tabs.length }
    Shortcut { sequence: "Ctrl++"; onActivated: if (app.cur) app.cur.zoom = Math.min(3, app.cur.zoom + 0.1) }
    Shortcut { sequence: "Ctrl+="; onActivated: if (app.cur) app.cur.zoom = Math.min(3, app.cur.zoom + 0.1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: if (app.cur) app.cur.zoom = Math.max(0.6, app.cur.zoom - 0.1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: if (app.cur) app.cur.zoom = 1 }
    Shortcut { sequence: "Escape"; enabled: app.prompt !== ""; onActivated: { app.prompt = ""; app.closingApp = false; if (app.cur) app.cur.edit.forceActiveFocus(); } }

    // ---- folder tree (the open file's folder)
    FolderListModel {
        id: fm
        folder: "file://" + app.folder
        showDirsFirst: true
        showHidden: false
        caseSensitive: false
    }
    Column {
        id: side
        x: 12; y: 12; width: 226
        spacing: 4
        Text { leftPadding: 8; topPadding: 4; bottomPadding: 4; text: (app.folder === app.home ? Tr.t("Home") : app.folder.substring(app.folder.lastIndexOf("/") + 1)).toUpperCase(); width: parent.width; elide: Text.ElideRight
               font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
        Rectangle {
            visible: app.folder !== "/"
            width: side.width; height: 34; radius: 10
            color: uh.hovered ? Theme.fill : "transparent"
            Row { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 12
                Text { text: String.fromCodePoint(Icons.arrowUp); font.family: Theme.symbols; font.pixelSize: Theme.px(14); color: Theme.muted }
                Text { text: ".."; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted } }
            HoverHandler { id: uh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: app.folder = app.folder.substring(0, app.folder.lastIndexOf("/")) || "/" }
        }
    }
    ListView {
        anchors { left: side.left; right: side.right; top: side.bottom; bottom: parent.bottom; bottomMargin: 12 }
        clip: true
        model: fm
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            readonly property bool open: app.cur && app.cur.path === filePath
            width: side.width; height: 34; radius: 10
            color: open ? Theme.accentFill : (rh.hovered ? Theme.fill : "transparent")
            border.width: open ? 1 : 0; border.color: Theme.accentLine
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 12
                Text { text: String.fromCodePoint(fileIsDir ? 0xf024b : 0xf0214); font.family: Theme.symbols; font.pixelSize: Theme.px(14); color: fileIsDir ? Theme.accent : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                Text { text: fileName; width: side.width - 56; elide: Text.ElideMiddle; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            }
            HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: fileIsDir ? (app.folder = filePath) : app.openPath(filePath) }
        }
    }
    Rectangle { x: side.x + side.width + 11; y: 0; width: 1; height: parent.height; color: Theme.glassLine }

    // ---- tabs
    Row {
        id: tabRow
        x: side.x + side.width + 28; y: 12
        spacing: 4
        Repeater {
            model: app.tabs
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool active: index === app.current
                width: tl.implicitWidth + 46; height: 34; radius: 10
                color: active ? Theme.accentFill : (th.hovered ? Theme.fill : "transparent")
                border.width: active ? 1 : 0; border.color: Theme.accentLine
                Text { id: tl; x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; font.family: Theme.font; font.pixelSize: Theme.px(14); color: parent.active ? Theme.text : Theme.muted }
                // the dot of unsaved changes turns into the close button on hover
                Text {
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: String.fromCodePoint(modelData.dirty && !xh.hovered ? 0xf0765 : 0xf0156)
                    font.family: Theme.symbols; font.pixelSize: Theme.px(modelData.dirty && !xh.hovered ? 10 : 13)
                    color: modelData.dirty && !xh.hovered ? Theme.accent : (xh.hovered ? Theme.text : Theme.dim)
                    HoverHandler { id: xh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: app.closeTab(index) }
                }
                HoverHandler { id: th }
                TapHandler { onTapped: { app.current = index; app.cur.edit.forceActiveFocus(); } }
                TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: app.closeTab(index) }
            }
        }
        Rectangle {
            width: 34; height: 34; radius: 10
            color: nh.hovered ? Theme.fill : "transparent"
            Text { anchors.centerIn: parent; text: "+"; font.family: Theme.font; font.pixelSize: Theme.px(18); color: Theme.muted }
            HoverHandler { id: nh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: app.newTab() }
        }
    }

    // ---- the editors
    Item {
        id: editorArea
        anchors { left: tabRow.left; right: parent.right; top: tabRow.bottom; topMargin: 8; bottom: status.top; rightMargin: 12 }
    }

    // ---- prompts: open / save as / find / go to line / unsaved changes
    Rectangle {
        id: bar
        visible: app.prompt !== ""
        anchors { right: parent.right; rightMargin: 24; top: editorArea.top; topMargin: 8 }
        width: 520; height: col.implicitHeight + 24; radius: 14
        color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
        z: 5
        onVisibleChanged: if (visible) {
            field.text = app.prompt === "open" ? (app.folder === "/" ? "/" : app.folder + "/").replace(app.home, "~")
                       : app.prompt === "saveas" ? (app.cur && app.cur.path ? app.cur.path : app.folder + "/" + "untitled.txt").replace(app.home, "~")
                       : app.prompt === "find" ? (app.cur ? app.cur.edit.selectedText : "") : "";
            if (app.prompt !== "close") { field.forceActiveFocus(); field.selectAll(); }
            else closeKeys.forceActiveFocus();
        }
        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8
            Text {
                text: Tr.t(app.prompt === "open" ? "Open a file (Enter)" : app.prompt === "saveas" ? "Save as (Enter)" : app.prompt === "find" ? "Find (Enter: next, Shift + Enter: previous)"
                          : app.prompt === "goto" ? "Go to line" : "This file has unsaved changes")
                font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted
            }
            Rectangle {
                visible: app.prompt !== "close"
                width: parent.width; height: 36; radius: 10
                color: Theme.ink(0.05); border.width: 1; border.color: Theme.accentLine
                TextInput {
                    id: field
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; clip: true
                    selectByMouse: true
                    Keys.onPressed: event => {
                        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return;
                        event.accepted = true;
                        const v = text.trim().replace(/^~/, app.home);
                        if (app.prompt === "open") { app.prompt = ""; app.openPath(v); }
                        else if (app.prompt === "saveas") { app.prompt = ""; if (v && app.cur) { app.cur.save(v); app.folder = v.substring(0, v.lastIndexOf("/")) || "/"; } }
                        else if (app.prompt === "goto") { app.prompt = ""; if (app.cur) app.cur.gotoLine(parseInt(v) || 1); }
                        else if (app.prompt === "find" && app.cur) { if (!app.cur.find(text, event.modifiers & Qt.ShiftModifier)) app.flash(Tr.t("Not found")); }
                    }
                    Keys.onTabPressed: event => {
                        // complete a path from the folder's names
                        event.accepted = true;
                        if (app.prompt !== "open" && app.prompt !== "saveas") return;
                        completer.run();
                    }
                }
            }
            Row {
                visible: app.prompt === "find"
                spacing: 8
                Rectangle {
                    width: 300; height: 36; radius: 10
                    color: Theme.ink(0.05); border.width: 1; border.color: Theme.glassLine
                    TextInput { id: repl; anchors { fill: parent; leftMargin: 8; rightMargin: 8 } verticalAlignment: TextInput.AlignVCenter; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; clip: true
                        Text { visible: repl.text === ""; text: Tr.t("Replace with"); font: repl.font; color: Theme.dim; anchors.verticalCenter: parent.verticalCenter } }
                }
                Btn { text: "Replace"; onClicked: if (app.cur) app.cur.replace(field.text, repl.text) }
                Btn { text: "All"; onClicked: if (app.cur) app.flash(Tr.f("{n} replaced", { n: app.cur.replaceAll(field.text, repl.text) })) }
            }
            Row {
                id: closeKeys
                visible: app.prompt === "close"
                spacing: 8
                Btn { text: "Save"; primary: true; onClicked: { const t = app.cur; if (!t.path) { app.prompt = "saveas"; return; } t.save(); app.prompt = ""; app.afterDecision(); } }
                Btn { text: "Don't save"; danger: true; onClicked: { app.prompt = ""; app.cur.dirty = false; app.afterDecision(); } }
                Btn { text: "Cancel"; onClicked: { app.prompt = ""; app.closingApp = false; } }
            }
        }
    }
    function afterDecision() {
        if (closingApp) { closingApp = false; closeWindow(); return; }
        closeTab(current, true);
    }
    Cmd {
        id: completer
        command: ["sh", "-c", "p=\"$1\"; d=\"${p%/*}\"; b=\"${p##*/}\"; [ -z \"$d\" ] && d=/; ls -1Ap -- \"$d\" 2>/dev/null | grep -i -- \"^$b\" | head -n 20; echo \"//$d\"", "sh", field.text.replace(/^~/, app.home)]
        onDone: out => {
            const l = out.split("\n").filter(x => x);
            const dir = (l.pop() || "//").slice(2);
            if (l.length === 1) field.text = ((dir === "/" ? "" : dir) + "/" + l[0]).replace(app.home, "~");
            else if (l.length > 1) {
                let pre = l[0];
                for (const x of l) while (!x.toLowerCase().startsWith(pre.toLowerCase())) pre = pre.slice(0, -1);
                field.text = ((dir === "/" ? "" : dir) + "/" + pre).replace(app.home, "~");
                app.flash(l.slice(0, 6).join("   "));
            }
        }
    }

    // ---- status bar
    Rectangle {
        id: status
        anchors { left: editorArea.left; right: parent.right; bottom: parent.bottom; rightMargin: 12 }
        height: 36; color: "transparent"
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.glassLine }
        Row {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 20
            Repeater {
                model: app.cur ? [app.cur.language, "UTF-8", Tr.f("Ln {l}, Col {c}", { l: app.cur.line, c: app.cur.column })].concat(app.message ? [app.message] : []) : []
                delegate: Text { required property var modelData; required property int index; text: modelData; font.family: Theme.font; font.pixelSize: Theme.px(12); color: index === 3 ? Theme.accent : Theme.muted }
            }
        }
        Text { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } text: Tr.t("Spaces: 4"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
    }
}
