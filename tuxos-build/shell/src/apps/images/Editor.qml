import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// The picture editor of the Image viewer (and of screenshots, "Edit" in the
// screenshot toast): crop, pen, box and arrow in the accent / red / yellow /
// white, Undo (Ctrl + Z), "Copy text" (OCR, English + Bulgarian), then Save
// a copy next to the picture or Copy it to the clipboard. Marks are kept in
// the picture's own pixels, so the copy is saved at full resolution.
Item {
    id: ed
    property var image                       // the viewer's Image
    property var view
    property string tool: "pen"              // crop | pen | box | arrow
    property color ink: "#ff5a6e"
    property var marks: []                   // [{ tool, color, width, pts: [[x, y], ...] }]
    property rect crop: Qt.rect(0, 0, 0, 0)  // in picture pixels; empty = whole
    property var live: null
    readonly property real k: image && image.width > 0 ? image.implicitWidth / image.width : 1   // screen -> picture pixels

    function reset() { marks = []; crop = Qt.rect(0, 0, 0, 0); live = null; tool = "pen"; }
    function key(e) {
        if (e.key === Qt.Key_Escape) { view.editing = false; reset(); }
        else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Z) undo();
        else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_S) save();
        else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_C) copy();
        else return;
        e.accepted = true;
    }
    function undo() {
        if (marks.length) marks = marks.slice(0, -1);
        else crop = Qt.rect(0, 0, 0, 0);
        paint.requestPaint();
    }

    // drawing happens on the picture itself (inherits its zoom and rotation)
    Canvas {
        id: paint
        parent: ed.visible ? ed.image : ed
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const s = 1 / ed.k;
            for (const m of ed.marks.concat(ed.live ? [ed.live] : [])) ed.draw(c, m, s);
        }
    }
    function draw(c, m, s) {
        c.strokeStyle = m.color; c.fillStyle = m.color;
        c.lineWidth = m.width * s; c.lineCap = "round"; c.lineJoin = "round";
        const p = m.pts;
        if (p.length < 2) return;
        c.beginPath();
        if (m.tool === "pen") { c.moveTo(p[0][0] * s, p[0][1] * s); for (const q of p) c.lineTo(q[0] * s, q[1] * s); c.stroke(); }
        else if (m.tool === "box") { const a = p[0], b = p[p.length - 1]; c.roundedRect(Math.min(a[0], b[0]) * s, Math.min(a[1], b[1]) * s, Math.abs(b[0] - a[0]) * s, Math.abs(b[1] - a[1]) * s, 8 * s, 8 * s); c.stroke(); }
        else if (m.tool === "arrow") {
            const a = p[0], b = p[p.length - 1];
            const ang = Math.atan2(b[1] - a[1], b[0] - a[0]), h = m.width * 4;
            c.moveTo(a[0] * s, a[1] * s); c.lineTo(b[0] * s, b[1] * s); c.stroke();
            c.beginPath();
            c.moveTo(b[0] * s, b[1] * s);
            c.lineTo((b[0] - h * Math.cos(ang - 0.45)) * s, (b[1] - h * Math.sin(ang - 0.45)) * s);
            c.lineTo((b[0] - h * Math.cos(ang + 0.45)) * s, (b[1] - h * Math.sin(ang + 0.45)) * s);
            c.closePath(); c.fill();
        }
    }
    // the crop frame (dims what is cut away)
    Item {
        parent: ed.visible ? ed.image : ed
        anchors.fill: parent
        visible: ed.crop.width > 0 || (ed.live && ed.live.tool === "crop")
        readonly property var r: {
            const c = ed.live && ed.live.tool === "crop" ? ed.rectOf(ed.live.pts) : ed.crop;
            return Qt.rect(c.x / ed.k, c.y / ed.k, c.width / ed.k, c.height / ed.k);
        }
        Rectangle { x: 0; y: 0; width: parent.width; height: parent.r.y; color: Qt.rgba(0, 0, 0, 0.55) }
        Rectangle { x: 0; y: parent.r.y + parent.r.height; width: parent.width; height: parent.height - y; color: Qt.rgba(0, 0, 0, 0.55) }
        Rectangle { x: 0; y: parent.r.y; width: parent.r.x; height: parent.r.height; color: Qt.rgba(0, 0, 0, 0.55) }
        Rectangle { x: parent.r.x + parent.r.width; y: parent.r.y; width: parent.width - x; height: parent.r.height; color: Qt.rgba(0, 0, 0, 0.55) }
        Rectangle { x: parent.r.x; y: parent.r.y; width: parent.r.width; height: parent.r.height; color: "transparent"; border.width: 2; border.color: "white" }
    }
    function rectOf(p) {
        const a = p[0], b = p[p.length - 1];
        return Qt.rect(Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.abs(b[0] - a[0]), Math.abs(b[1] - a[1]));
    }
    MouseArea {
        parent: ed.visible ? ed.image : ed
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        function pt(m) { return [Math.max(0, Math.min(ed.image.implicitWidth, m.x * ed.k)), Math.max(0, Math.min(ed.image.implicitHeight, m.y * ed.k))]; }
        onPressed: m => { ed.live = { tool: ed.tool, color: ed.ink.toString(), width: Math.max(3, 4 * ed.k), pts: [pt(m)] }; }
        onPositionChanged: m => {
            if (!ed.live) return;
            const l = Object.assign({}, ed.live);
            l.pts = ed.tool === "pen" ? l.pts.concat([pt(m)]) : [l.pts[0], pt(m)];
            ed.live = l;
            paint.requestPaint();
        }
        onReleased: {
            const l = ed.live; ed.live = null;
            if (!l || l.pts.length < 2) return;
            if (l.tool === "crop") { const r = ed.rectOf(l.pts); if (r.width > 8 && r.height > 8) ed.crop = r; }
            else ed.marks = ed.marks.concat([l]);
            paint.requestPaint();
        }
    }

    // ---- the finished picture: full size, marks, crop, rotation
    Item {
        id: out
        x: -100000
        visible: ed.visible
        readonly property real fullW: ed.image ? ed.image.implicitWidth : 1
        readonly property real fullH: ed.image ? ed.image.implicitHeight : 1
        readonly property rect c: ed.crop.width > 0 ? ed.crop : Qt.rect(0, 0, fullW, fullH)
        readonly property bool side: ed.view.rotation % 180 !== 0
        width: side ? c.height : c.width
        height: side ? c.width : c.height
        Item {
            id: cropBox
            width: out.c.width; height: out.c.height
            anchors.centerIn: parent
            rotation: ed.view.rotation % 360
            clip: true
            Item {
                x: -out.c.x; y: -out.c.y
                width: out.fullW; height: out.fullH
                Image { id: fullImg; anchors.fill: parent; source: ed.visible && ed.view.path ? "file://" + ed.view.path : ""; cache: false; autoTransform: true }
                Canvas {
                    id: fullPaint
                    anchors.fill: parent
                    onPaint: { const c = getContext("2d"); c.reset(); for (const m of ed.marks) ed.draw(c, m, 1); }
                }
            }
        }
    }
    function render(cb) {
        fullPaint.requestPaint();
        Qt.callLater(() => out.grabToImage(r => cb(r), Qt.size(out.width, out.height)));
    }
    function savePath() {
        const p = view.path, dot = p.lastIndexOf(".");
        // a screenshot lives in RAM only: its edited copy goes to ~/Pictures/Screenshots
        const rt = Quickshell.env("XDG_RUNTIME_DIR") || "/run/user";
        if (p.startsWith(rt + "/")) {
            Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/Pictures/Screenshots"]);
            return Quickshell.env("HOME") + "/Pictures/Screenshots/" + Tr.t("Screenshot") + " " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm.ss") + ".png";
        }
        return (dot > p.lastIndexOf("/") ? p.slice(0, dot) : p) + " (edited).png";
    }
    function save() {
        const to = savePath();
        render(r => {
            if (r.saveToFile(to)) { view.editing = false; reset(); view.path = to; view.flash(Tr.f("Saved {n}", { n: to.substring(to.lastIndexOf("/") + 1) })); }
            else view.flash(Tr.t("Could not save"));
        });
    }
    function copy() {
        const tmp = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tuxos-edited.png";
        render(r => {
            if (!r.saveToFile(tmp)) return;
            Quickshell.execDetached(["sh", "-c", "wl-copy -t image/png < \"$1\"", "sh", tmp]);
            view.flash(Tr.t("Copied - paste it anywhere with Ctrl + V"));
        });
    }
    Cmd {
        id: ocr
        command: ["sh", "-c", "tesseract \"$1\" - -l eng+bul 2>/dev/null || tesseract \"$1\" - 2>/dev/null", "sh", ed.view.path]
        onDone: out => {
            const t = out.trim();
            if (t) { Quickshell.clipboardText = t; ed.view.flash(Tr.t("Text copied")); }
            else ed.view.flash(Tr.t("No text found"));
        }
    }

    // ---- tools
    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
        width: row.implicitWidth + 16; height: 52; radius: 16
        color: Qt.rgba(12 / 255, 14 / 255, 19 / 255, 0.9); border.width: 1; border.color: Qt.rgba(210 / 255, 225 / 255, 1, 0.12)
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: [["crop", 0xf019e, "Crop"], ["pen", 0xf03eb, "Pen"], ["box", 0xf0e5f, "Box"], ["arrow", 0xf0054, "Arrow"]]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: ed.tool === modelData[0]
                    width: 42; height: 40; radius: 11
                    color: on ? Theme.accent : (h1.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    Text { anchors.centerIn: parent; text: String.fromCodePoint(modelData[1]); font.family: Theme.symbols; font.pixelSize: Theme.px(18); color: parent.on ? Theme.accentInk : "#f4f7fb" }
                    HoverHandler { id: h1; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: ed.tool = modelData[0] }
                }
            }
            Rectangle { width: 1; height: 28; color: Qt.rgba(1, 1, 1, 0.12); anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: ["#ff5a6e", Theme.accent.toString(), "#ffd166", "#ffffff"]
                delegate: Item {
                    required property string modelData
                    width: 34; height: 40
                    Rectangle {
                        anchors.centerIn: parent
                        width: 22; height: 22; radius: 11; color: modelData
                        border.width: ed.ink.toString() === Qt.color(modelData).toString() ? 3 : 0; border.color: "white"
                    }
                    TapHandler { onTapped: ed.ink = modelData }
                }
            }
            Rectangle { width: 1; height: 28; color: Qt.rgba(1, 1, 1, 0.12); anchors.verticalCenter: parent.verticalCenter }
            Btn { text: "Undo"; anchors.verticalCenter: parent.verticalCenter; onClicked: ed.undo() }
            Btn { text: "Copy text"; anchors.verticalCenter: parent.verticalCenter; onClicked: { ed.view.flash(Tr.t("Reading the text...")); ocr.run(); } }
            Btn { text: "Copy"; anchors.verticalCenter: parent.verticalCenter; onClicked: ed.copy() }
            Btn { text: "Save a copy"; primary: true; anchors.verticalCenter: parent.verticalCenter; onClicked: ed.save() }
            Btn { text: "Cancel"; anchors.verticalCenter: parent.verticalCenter; onClicked: { ed.view.editing = false; ed.reset(); } }
        }
    }
}
