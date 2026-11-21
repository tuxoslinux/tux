import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// Image viewer (mockup apps/13-images): the picture large on a dark sheet,
// name / size / position over it, a floating toolbar (zoom, rotate, crop,
// draw, info, wallpaper, delete) and a filmstrip of the folder. Wheel or
// + / - zooms, drag pans, double click fits / shows 100 %, arrows move,
// Delete moves to Trash with Undo. The editor (crop, pen, box, arrow,
// text from the picture) saves a copy "<name> (edited).png" or copies it.
FloatingWindow {
    id: app
    implicitWidth: 1280; implicitHeight: 820
    color: "transparent"
    title: name || Tr.t("Image viewer")
    // closed from outside (Super + Q, the compositor): the viewer ends too
    onVisibleChanged: if (!visible) Qt.quit()

    readonly property string home: Quickshell.env("HOME")
    property string path: {
        let p = Quickshell.env("TUXOS_PAGE") || "";
        if (p.startsWith("edit:")) { editing = true; p = p.slice(5); }
        return p.startsWith("file://") ? decodeURIComponent(p.slice(7)) : p;
    }
    property bool editing: false
    IpcHandler { target: "images"; function page(id: string): void { app.editing = id.startsWith("edit:"); const p = id.replace(/^edit:/, ""); app.path = p.startsWith("file://") ? decodeURIComponent(p.slice(7)) : p; } }
    readonly property string dir: path.substring(0, path.lastIndexOf("/")) || "/"
    readonly property string name: path.substring(path.lastIndexOf("/") + 1)

    FolderListModel {
        id: fm
        folder: app.dir ? "file://" + app.dir : ""
        showDirs: false
        caseSensitive: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.svg", "*.avif", "*.tif", "*.tiff"]
        sortField: FolderListModel.Name
    }
    readonly property int index: { void fm.count; for (let i = 0; i < fm.count; i++) if (fm.get(i, "filePath") === path) return i; return -1; }
    function step(d) { if (fm.count) { const i = ((index < 0 ? 0 : index) + d + fm.count) % fm.count; path = fm.get(i, "filePath"); } }

    // view state
    property real zoom: 1            // 1 = fit
    property int rotation: 0
    property bool info: false
    onPathChanged: { zoom = 1; rotation = 0; pan.x = 0; pan.y = 0; ed.reset(); Qt.callLater(() => details.run()); }
    property string details_: ""
    Cmd { id: details; command: ["sh", "-c", "stat -c '%s %Y' -- \"$1\"; file -b -- \"$1\" | grep -o -E '[0-9]+ ?x ?[0-9]+' | head -n1", "sh", app.path]; Component.onCompleted: run(); onDone: out => app.details_ = out.trim() }
    // the picture's real size (pictures over 4096 px wide are shown scaled down)
    readonly property var dims: { const m = /(\d+) ?x ?(\d+)/.exec(details_.split("\n")[1] || ""); return m ? [+m[1], +m[2]] : [0, 0]; }
    readonly property real fileSize: +(details_.split("\n")[0].split(" ")[0] || 0)
    readonly property date modified: new Date(+(details_.split("\n")[0].split(" ")[1] || 0) * 1000)
    function sizeText(b) { return b < 1048576 ? Math.round(b / 1024) + " KB" : (b / 1048576).toFixed(1) + " MB"; }

    property string banner: ""
    property var undo: null
    function flash(t, u) { banner = t; undo = u || null; bannerT.restart(); }
    Timer { id: bannerT; interval: 6000; onTriggered: { app.banner = ""; app.undo = null; } }

    function trash() {
        const p = path, n = name;
        const next = fm.count > 1 ? fm.get((index + 1) % fm.count, "filePath") : "";
        Quickshell.execDetached(["gio", "trash", "--", p]);
        if (next && next !== p) path = next;
        flash(Tr.f("{n} moved to Trash", { n: n }), () => {
            Quickshell.execDetached(["sh", "-c", "T=\"$HOME/.local/share/Trash\"; i=\"$T/info/$1.trashinfo\"; mv -- \"$T/files/$1\" \"$2\" && rm -f -- \"$i\"", "sh", n, p]);
            app.path = p;
        });
    }
    function setWallpaper() {
        Quickshell.execDetached(["qs", "-c", "tuxos", "ipc", "call", "wallpaper", "set", path, "default"]);
        flash(Tr.t("Set as wallpaper"));
    }

    Rectangle {
        id: sheet
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(6 / 255, 7 / 255, 10 / 255, Theme.lite ? 1 : 0.94)
        border.width: 1; border.color: Theme.glassLine
        clip: true
        focus: true
        Keys.onPressed: e => app.key(e)
        Component.onCompleted: forceActiveFocus()

        // ---- the picture
        Item {
            id: stage
            anchors { fill: parent; topMargin: 64; bottomMargin: strip.visible ? 104 : 24; leftMargin: 24; rightMargin: app.info ? 324 : 24 }
            clip: true
            Item {
                id: pan
                width: stage.width; height: stage.height
                Image {
                    id: img
                    anchors.centerIn: parent
                    source: app.path ? "file://" + app.path : ""
                    asynchronous: true
                    autoTransform: true
                    cache: false
                    smooth: true; mipmap: true
                    fillMode: Image.PreserveAspectFit
                    // fit, then zoom (1 = fit); 90 / 270 swap the box
                    readonly property bool side: app.rotation % 180 !== 0
                    readonly property real fit: implicitWidth > 0 ? Math.min((side ? stage.height : stage.width) / implicitWidth, (side ? stage.width : stage.height) / implicitHeight, 1) : 1
                    width: implicitWidth * fit * app.zoom
                    height: implicitHeight * fit * app.zoom
                    sourceSize: app.dims[0] > 4096 ? Qt.size(4096, Math.round(4096 * app.dims[1] / app.dims[0])) : Qt.size(-1, -1)
                    rotation: app.rotation
                    Behavior on rotation { enabled: !Theme.reduceMotion; Spring {} }
                }
                DragHandler { target: pan; enabled: !app.editing; cursorShape: Qt.ClosedHandCursor }
            }
            WheelHandler { enabled: !app.editing; onWheel: e => app.zoom = Math.max(0.2, Math.min(16, app.zoom * (e.angleDelta.y > 0 ? 1.15 : 1 / 1.15))) }
            TapHandler { enabled: !app.editing; onDoubleTapped: { if (app.zoom === 1) app.zoom = 1 / Math.max(0.0001, img.fit); else { app.zoom = 1; pan.x = 0; pan.y = 0; } } }
            Editor { id: ed; anchors.fill: parent; visible: app.editing; image: img; view: app }
        }

        // ---- header: name and facts
        Row {
            x: 20; y: 16
            spacing: 12
            Rectangle {
                width: 36; height: 36; radius: 11; color: Theme.ink(0.08)
                Text { anchors.centerIn: parent; text: String.fromCodePoint(Icons.fileImage); font.family: Theme.symbols; font.pixelSize: Theme.px(17); color: Theme.text }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: app.name; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: "#f4f7fb" }
                Text {
                    text: [app.dims[0] ? app.dims[0] + " × " + app.dims[1] : (img.implicitWidth ? img.implicitWidth + " × " + img.implicitHeight : ""), app.fileSize ? app.sizeText(app.fileSize) : "",
                           app.index >= 0 ? Tr.f("{i} of {n}", { i: app.index + 1, n: fm.count }) : "", app.zoom !== 1 ? Math.round(img.fit * app.zoom * 100) + " %" : ""].filter(x => x).join(" · ")
                    font.family: Theme.font; font.pixelSize: Theme.px(12); color: "#8b95a5"
                }
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 16 }
            spacing: 8
            Repeater {
                model: [[0xf0374, "min"], [0xf05af, "max"], [0xf0156, "close"]]
                delegate: Rectangle {
                    required property var modelData
                    width: 30; height: 30; radius: 15
                    color: wh.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                    Text { anchors.centerIn: parent; text: String.fromCodePoint(modelData[0]); font.family: Theme.symbols; font.pixelSize: Theme.px(14); color: "#f4f7fb" }
                    HoverHandler { id: wh; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: modelData[1] === "close" ? Qt.quit() : modelData[1] === "min" ? Hyprland.dispatch('hl.dsp.global("tuxos:minimize")')
                                                                                               : Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized" })')
                    }
                }
            }
        }

        // ---- floating toolbar
        Rectangle {
            visible: !app.editing
            anchors { horizontalCenter: stage.horizontalCenter; bottom: stage.bottom; bottomMargin: 12 }
            width: tools.implicitWidth + 16; height: 52; radius: 16
            color: Qt.rgba(12 / 255, 14 / 255, 19 / 255, 0.86); border.width: 1; border.color: Qt.rgba(210 / 255, 225 / 255, 1, 0.12)
            Row {
                id: tools
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: [[0xf034a, "Zoom out (-)", () => app.zoom = Math.max(0.2, app.zoom / 1.25)], [0xf034b, "Zoom in (+)", () => app.zoom = Math.min(16, app.zoom * 1.25)],
                            [0xf0467, "Rotate (R)", () => app.rotation = app.rotation + 90], [0xf019e, "Crop and draw (E)", () => app.editing = true],
                            [0xf02fc, "Details (I)", () => app.info = !app.info], [0xf0e09, "Set as wallpaper", () => app.setWallpaper()],
                            [0xf0a7a, "Move to Trash (Delete)", () => app.trash()]]
                    delegate: Rectangle {
                        required property var modelData
                        width: 42; height: 40; radius: 11
                        color: th.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                        Text { anchors.centerIn: parent; text: String.fromCodePoint(modelData[0]); font.family: Theme.symbols; font.pixelSize: Theme.px(18); color: "#f4f7fb" }
                        HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: modelData[2]() }
                        Rectangle {
                            visible: th.hovered
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 8 }
                            width: tip.implicitWidth + 16; height: 26; radius: 8
                            color: Qt.rgba(12 / 255, 14 / 255, 19 / 255, 0.95); border.width: 1; border.color: Qt.rgba(210 / 255, 225 / 255, 1, 0.12)
                            Text { id: tip; anchors.centerIn: parent; text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(12); color: "#f4f7fb" }
                        }
                    }
                }
            }
        }

        // ---- filmstrip
        ListView {
            id: strip
            visible: fm.count > 1 && !app.editing
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
            width: Math.min(parent.width - 48, fm.count * 84); height: 64
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: fm
            currentIndex: app.index
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width / 2 - 38; preferredHighlightEnd: width / 2 + 38
            delegate: Rectangle {
                required property string filePath
                required property int index
                readonly property bool cur: filePath === app.path
                width: cur ? 92 : 76; height: cur ? 64 : 56; radius: 10
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: cur ? 2 : 0; border.color: Theme.accent
                clip: true
                Image { anchors { fill: parent; margins: parent.cur ? 2 : 0 } source: "file://" + filePath; sourceSize: Qt.size(184, 128); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                TapHandler { onTapped: app.path = filePath }
            }
        }

        // ---- details panel (I)
        Rectangle {
            visible: app.info
            anchors { right: parent.right; rightMargin: 16; top: stage.top; bottom: stage.bottom }
            width: 292; radius: 16
            color: Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: Qt.rgba(210 / 255, 225 / 255, 1, 0.10)
            Column {
                anchors { fill: parent; margins: 16 }
                spacing: 12
                Text { text: Tr.t("Details"); font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: "#f4f7fb" }
                Repeater {
                    model: [["Size", (app.dims[0] || img.implicitWidth) + " × " + (app.dims[1] || img.implicitHeight)], ["File", app.sizeText(app.fileSize)], ["Modified", Tr.date(app.modified, "d MMM yyyy, HH:mm")], ["Folder", app.dir.replace(app.home, "~")]]
                    delegate: Item {
                        required property var modelData
                        width: parent.width; height: 20
                        Text { text: Tr.t(modelData[0]); font.family: Theme.font; font.pixelSize: Theme.px(13); color: "#8b95a5" }
                        Text { anchors.right: parent.right; width: parent.width - 80; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; text: modelData[1]; font.family: Theme.font; font.pixelSize: Theme.px(13); color: "#f4f7fb" }
                    }
                }
            }
        }

        // ---- banner with Undo
        Rectangle {
            visible: app.banner !== ""
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 68 }
            width: br.implicitWidth + 32; height: 44; radius: 14
            color: Qt.rgba(12 / 255, 14 / 255, 19 / 255, 0.95); border.width: 1; border.color: Qt.rgba(210 / 255, 225 / 255, 1, 0.12)
            Row {
                id: br; anchors.centerIn: parent; spacing: 12
                Text { anchors.verticalCenter: parent.verticalCenter; text: app.banner; font.family: Theme.font; font.pixelSize: Theme.px(14); color: "#f4f7fb" }
                Btn { visible: app.undo !== null; text: "Undo"; primary: true; onClicked: { const u = app.undo; app.banner = ""; app.undo = null; u(); } }
            }
        }
        Text {
            anchors.centerIn: stage
            visible: img.status === Image.Error || !app.path
            text: app.path ? Tr.t("This picture cannot be shown") : Tr.t("Open a picture from Files")
            font.family: Theme.font; font.pixelSize: Theme.px(16); color: "#8b95a5"
        }
    }

    function key(e) {
        if (editing) { ed.key(e); return; }
        if (e.key === Qt.Key_Right || e.key === Qt.Key_Space || e.key === Qt.Key_PageDown) step(1);
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backspace || e.key === Qt.Key_PageUp) step(-1);
        else if (e.key === Qt.Key_Home) { if (fm.count) path = fm.get(0, "filePath"); }
        else if (e.key === Qt.Key_End) { if (fm.count) path = fm.get(fm.count - 1, "filePath"); }
        else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) zoom = Math.min(16, zoom * 1.25);
        else if (e.key === Qt.Key_Minus) zoom = Math.max(0.2, zoom / 1.25);
        else if (e.key === Qt.Key_0) { zoom = 1; pan.x = 0; pan.y = 0; }
        else if (e.key === Qt.Key_R) rotation = rotation + ((e.modifiers & Qt.ShiftModifier) ? -90 : 90);
        else if (e.key === Qt.Key_I) info = !info;
        else if (e.key === Qt.Key_E) editing = true;
        else if (e.key === Qt.Key_Delete) trash();
        else if (e.key === Qt.Key_F11 || e.key === Qt.Key_F) Hyprland.dispatch('hl.dsp.window.fullscreen()');
        else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Q) Qt.quit();
        else return;
        e.accepted = true;
    }
}
