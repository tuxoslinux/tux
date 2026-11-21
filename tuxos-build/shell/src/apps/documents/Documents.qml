import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Documents (PDF; mockup apps/15-pdf): the pages one under another, drawn
// by poppler (pdftoppm) only when they come into view, page thumbnails on
// the left, zoom / fit width, search through the text (pdftotext), copy a
// page's text, print (CUPS). Nothing heavy stays loaded.
AppWindow {
    id: app
    appName: "Documents"
    appIcon: 0xf0226
    subtitle: path ? path.replace(Quickshell.env("HOME"), "~") : ""
    searchable: true
    searchHint: "Search in the document"

    property string path: {
        const p = Quickshell.env("TUXOS_PAGE") || "";
        return p.startsWith("file://") ? decodeURIComponent(p.slice(7)) : p;
    }
    IpcHandler { target: "documents"; function page(id: string): void { app.path = id.startsWith("file://") ? decodeURIComponent(id.slice(7)) : id; } }
    readonly property string cache: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tuxos-pdf-" + Qt.md5(path)
    property int pages: 0
    property var sizes: []                    // [[w, h] in points]
    property string title_: ""
    property real zoom: 1                     // 1 = fit width
    property var texts: []                    // page texts, for search / copy
    property var hits: []                     // pages with the search words
    property int hit: -1

    onPathChanged: load()
    Component.onCompleted: load()
    function load() {
        pages = 0; sizes = []; texts = []; hits = []; rendered = ({}); queue = [];
        if (path) { infoProc.run(); }
    }
    Cmd {
        id: infoProc
        command: ["sh", "-c", "rm -rf \"${2%-*}\"-*; mkdir -p \"$2\"; pdfinfo -f 1 -l 2000 -- \"$1\" 2>/dev/null", "sh", app.path, app.cache]
        onDone: out => {
            let n = 0; const s = [];
            for (const l of out.split("\n")) {
                let m;
                if ((m = /^Pages:\s+(\d+)/.exec(l))) n = +m[1];
                else if ((m = /^Title:\s+(.+)$/.exec(l))) app.title_ = m[1].trim();
                else if ((m = /^Page\s+(\d+) size:\s+([\d.]+) x ([\d.]+)/.exec(l))) s[+m[1] - 1] = [+m[2], +m[3]];
            }
            for (let i = 0; i < n; i++) if (!s[i]) s[i] = s[i - 1] || [595, 842];
            app.sizes = s; app.pages = n;
            textProc.run();
        }
    }
    Cmd {
        id: textProc
        command: ["pdftotext", "-layout", "--", app.path, "-"]
        onDone: out => app.texts = out.split("\f")
    }

    // ---- rendering queue: one page at a time, the ones in view first
    property var rendered: ({})               // "page-width" -> file
    property var queue: []
    function want(page, w) {
        const key = page + "-" + w;
        if (rendered[key] || queue.indexOf(key) !== -1) return;
        queue = [key].concat(queue);          // newest first: what is on screen now
        if (!renderer.running) next();
    }
    function next() {
        if (!queue.length) return;
        const key = queue[0]; queue = queue.slice(1);
        const [p, w] = key.split("-").map(Number);
        renderer.key = key;
        renderer.command = ["pdftoppm", "-f", String(p + 1), "-l", String(p + 1), "-scale-to-x", String(w), "-scale-to-y", "-1", "-png", "-singlefile", app.path, app.cache + "/" + key];
        renderer.running = true;
    }
    Process {
        id: renderer
        property string key: ""
        onExited: code => {
            if (code === 0) { const r = Object.assign({}, app.rendered); r[key] = app.cache + "/" + key + ".png"; app.rendered = r; }
            app.next();
        }
    }
    // the cache lives in RAM; drop it when the window closes
    Component.onDestruction: Quickshell.execDetached(["rm", "-rf", app.cache])

    // ---- search
    onSearchAccepted: findNext()
    onSearchChanged: { hits = []; hit = -1; }
    function findNext() {
        const q = app.search.trim().toLowerCase();
        if (!q) return;
        if (!hits.length) hits = texts.map((t, i) => t.toLowerCase().indexOf(q) !== -1 ? i : -1).filter(i => i >= 0);
        if (!hits.length) { flash(Tr.t("Not found")); return; }
        hit = (hit + 1) % hits.length;
        list.positionViewAtIndex(hits[hit], ListView.Beginning);
    }
    property string message: ""
    function flash(t) { message = t; msgT.restart(); }
    Timer { id: msgT; interval: 3000; onTriggered: app.message = "" }

    readonly property int current: list.indexAt(10, list.contentY + list.height / 3)

    // ---- thumbnails
    ListView {
        id: thumbs
        x: 12; y: 12; width: 170; height: parent.height - 24
        clip: true
        spacing: 12
        model: app.pages
        boundsBehavior: Flickable.StopAtBounds
        delegate: Column {
            required property int index
            width: thumbs.width
            spacing: 4
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property var sz: app.sizes[index] || [595, 842]
                width: 120; height: Math.round(120 * sz[1] / sz[0])
                color: "white"
                border.width: index === app.current ? 3 : 1
                border.color: index === app.current ? Theme.accent : Theme.glassLine
                Image {
                    anchors { fill: parent; margins: parent.border.width }
                    source: app.rendered[index + "-240"] ? "file://" + app.rendered[index + "-240"] : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    Component.onCompleted: app.want(index, 240)
                }
                TapHandler { onTapped: list.positionViewAtIndex(index, ListView.Beginning) }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: index + 1; font.family: Theme.font; font.pixelSize: Theme.px(12); color: index === app.current ? Theme.accent : Theme.muted }
        }
    }
    Rectangle { x: thumbs.x + thumbs.width + 11; y: 0; width: 1; height: parent.height; color: Theme.glassLine }

    // ---- pages
    ListView {
        id: list
        anchors { left: thumbs.right; leftMargin: 24; right: parent.right; rightMargin: 12; top: parent.top; topMargin: 12; bottom: tools.top; bottomMargin: 8 }
        clip: true
        spacing: 16
        model: app.pages
        cacheBuffer: 1200
        boundsBehavior: Flickable.StopAtBounds
        readonly property int pageW: Math.round(Math.min(width - 24, 1100) * app.zoom)
        contentWidth: Math.max(width, pageW + 24)
        flickableDirection: Flickable.AutoFlickDirection
        delegate: Item {
            required property int index
            readonly property var sz: app.sizes[index] || [595, 842]
            width: list.contentWidth
            height: Math.round(list.pageW * sz[1] / sz[0])
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: list.pageW; height: parent.height
                color: "white"
                // drawn at the shown width (x1.5 for sharp text), redrawn when zooming settles
                readonly property int px: Math.round(list.pageW * 1.5 / 100) * 100
                Image {
                    anchors.fill: parent
                    source: app.rendered[index + "-" + parent.px] ? "file://" + app.rendered[index + "-" + parent.px] : (app.rendered[index + "-240"] ? "file://" + app.rendered[index + "-240"] : "")
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }
                Timer { interval: 150; running: true; onTriggered: app.want(index, parent.px) }
                Connections { target: list; function onPageWChanged() { zoomT.restart(); } }
                Timer { id: zoomT; interval: 300; onTriggered: app.want(index, parent.px) }
                TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: { Quickshell.clipboardText = (app.texts[index] || "").trim(); app.flash(Tr.f("Text of page {n} copied", { n: index + 1 })); } }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: { Quickshell.clipboardText = (app.texts[index] || "").trim(); app.flash(Tr.f("Text of page {n} copied", { n: index + 1 })); }
                }
            }
        }
        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            onWheel: e => app.zoom = Math.max(0.4, Math.min(3, app.zoom * (e.angleDelta.y > 0 ? 1.1 : 1 / 1.1)))
        }
    }
    Text {
        anchors.centerIn: list
        visible: app.pages === 0
        text: app.path ? (infoProc.running ? Tr.t("Opening...") : Tr.t("This file cannot be opened")) : Tr.t("Open a PDF from Files")
        font.family: Theme.font; font.pixelSize: Theme.px(16); color: Theme.muted
    }

    // ---- toolbar
    Row {
        id: tools
        anchors { horizontalCenter: list.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
        spacing: 8
        Btn { text: "−"; onClicked: app.zoom = Math.max(0.4, app.zoom / 1.15) }
        Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(app.zoom * 100) + " %"; width: 54; horizontalAlignment: Text.AlignHCenter; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        Btn { text: "+"; onClicked: app.zoom = Math.min(3, app.zoom * 1.15) }
        Btn { text: "Fit width"; onClicked: app.zoom = 1 }
        Item { width: 12; height: 1 }
        Text { anchors.verticalCenter: parent.verticalCenter; text: app.pages ? Tr.f("Page {i} of {n}", { i: app.current + 1, n: app.pages }) : ""; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text }
        Text { anchors.verticalCenter: parent.verticalCenter; visible: app.hits.length > 0; text: Tr.f("found on {n} pages", { n: app.hits.length }); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.accent }
        Item { width: 12; height: 1 }
        Btn { text: "Print"; icon: 0xf042a; onClicked: { Quickshell.execDetached(["lp", "--", app.path]); app.flash(Tr.t("Sent to the printer")); } }
        Text { anchors.verticalCenter: parent.verticalCenter; text: app.message; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.accent }
    }

    // keys: PageUp / PageDown, Home / End, Ctrl + +/-/0
    Item {
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: e => {
            if (e.key === Qt.Key_PageDown || e.key === Qt.Key_Space) list.contentY = Math.min(list.contentHeight - list.height, list.contentY + list.height * 0.9);
            else if (e.key === Qt.Key_PageUp) list.contentY = Math.max(0, list.contentY - list.height * 0.9);
            else if (e.key === Qt.Key_Down) list.contentY = Math.min(list.contentHeight - list.height, list.contentY + 60);
            else if (e.key === Qt.Key_Up) list.contentY = Math.max(0, list.contentY - 60);
            else if (e.key === Qt.Key_Home) list.positionViewAtBeginning();
            else if (e.key === Qt.Key_End) list.positionViewAtEnd();
            else if ((e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal)) app.zoom = Math.min(3, app.zoom * 1.15);
            else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Minus) app.zoom = Math.max(0.4, app.zoom / 1.15);
            else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_0) app.zoom = 1;
            else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_P) Quickshell.execDetached(["lp", "--", app.path]);
            else return;
            e.accepted = true;
        }
    }
}
