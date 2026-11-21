import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// Touching up the depth-effect mask (Settings > Appearance): the wallpaper
// with the subject tinted in the accent; paint to add to the subject, Shift
// or "Erase" to take away; Save writes the mask the lock screen uses.
Rectangle {
    id: ed
    property string maskFile: ""
    signal done()
    color: Theme.glassPanel
    radius: 18
    border.width: 1; border.color: Theme.glassLine
    property bool erase: false
    property real brush: 14

    Column {
        anchors { fill: parent; margins: 20 }
        spacing: 12
        Row {
            spacing: 12
            Text { text: Tr.t("Touch up the depth effect"); font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Segmented { width: 220; options: ["Add", "Erase"]; current: ed.erase ? 1 : 0; onPicked: i => ed.erase = i === 1 }
            Slider { width: 160; value: (ed.brush - 4) / 36; onMoved: v => ed.brush = 4 + v * 36; anchors.verticalCenter: parent.verticalCenter }
        }
        Item {
            id: area
            width: parent.width
            height: parent.height - 120
            Image {
                id: wall
                anchors.centerIn: parent
                width: Math.min(area.width, area.height * implicitWidth / Math.max(1, implicitHeight))
                height: width * implicitHeight / Math.max(1, implicitWidth)
                source: "file://" + Wallpapers.defaultFile
                sourceSize.width: 1280
                fillMode: Image.Stretch
                cache: false
            }
            Canvas {
                id: paint
                x: wall.x; y: wall.y; width: wall.width; height: wall.height
                renderTarget: Canvas.Image
                renderStrategy: Canvas.Immediate
                opacity: 0.55
                property var strokes: []
                property bool loaded: false
                Component.onCompleted: if (base) loadImage(base)
                onImageLoaded: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.clearRect(0, 0, width, height);
                    // the saved mask, then the strokes on top
                    if (paint.base && isImageLoaded(paint.base)) c.drawImage(paint.base, 0, 0, width, height);
                    for (const s of strokes) {
                        c.globalCompositeOperation = s.erase ? "destination-out" : "source-over";
                        c.fillStyle = "white";
                        c.beginPath(); c.arc(s.x * width, s.y * height, s.r * width, 0, Math.PI * 2); c.fill();
                    }
                    c.globalCompositeOperation = "source-over";
                }
                property string base: ed.maskFile ? "file://" + ed.maskFile : ""
            }
            // the subject in the accent colour over the picture
            Rectangle { x: wall.x; y: wall.y; width: wall.width; height: wall.height; color: "transparent"; border.width: 1; border.color: Theme.glassLine }
            MouseArea {
                x: wall.x; y: wall.y; width: wall.width; height: wall.height
                cursorShape: Qt.CrossCursor
                function dab(m) { paint.strokes = paint.strokes.concat([{ x: m.x / width, y: m.y / height, r: ed.brush / 1280, erase: ed.erase || (m.modifiers & Qt.ShiftModifier) }]); paint.requestPaint(); }
                onPressed: m => dab(m)
                onPositionChanged: m => { if (pressed) dab(m); }
            }
        }
        Row {
            spacing: 8
            Btn { text: "Undo"; onClicked: { paint.strokes = paint.strokes.slice(0, -1); paint.requestPaint(); } }
            Btn { text: "Make it again"; onClicked: { Quickshell.execDetached(["rm", "-f", ed.maskFile, ed.maskFile.replace(/\.png$/, ".none")]); Quickshell.execDetached(["qs", "-c", "tuxos", "ipc", "call", "wallpaper", "depthChanged"]); ed.done(); } }
            Item { width: 20; height: 1 }
            Btn { text: "Cancel"; onClicked: ed.done() }
            Btn {
                text: "Save"; primary: true
                onClicked: {
                    // save at the mask's own size (384 px wide)
                    saver.width = 384; saver.height = Math.round(384 * wall.implicitHeight / Math.max(1, wall.implicitWidth));
                    saver.requestPaint();
                }
            }
        }
    }
    // draws the result at mask size, white on transparent, then saves
    Canvas {
        id: saver
        visible: true; opacity: 0.01
        width: 1; height: 1
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        property bool go: false
        Component.onCompleted: if (ed.maskFile) loadImage("file://" + ed.maskFile)
        onPaint: {
            if (width < 2) return;
            const c = getContext("2d");
            c.clearRect(0, 0, width, height);
            if (isImageLoaded("file://" + ed.maskFile)) c.drawImage("file://" + ed.maskFile, 0, 0, width, height);
            for (const s of paint.strokes) {
                c.globalCompositeOperation = s.erase ? "destination-out" : "source-over";
                c.fillStyle = "white";
                c.beginPath(); c.arc(s.x * width, s.y * height, s.r * width, 0, Math.PI * 2); c.fill();
            }
            c.globalCompositeOperation = "source-over";
            go = true;
        }
        onPainted: if (go) {
            go = false;
            if (save(ed.maskFile)) Quickshell.execDetached(["qs", "-c", "tuxos", "ipc", "call", "wallpaper", "depthChanged"]);
            ed.done();
        }
    }
}
