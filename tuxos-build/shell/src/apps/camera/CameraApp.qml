import QtQuick
import QtMultimedia
import Quickshell
import qs.theme
import qs.components
import qs.services

// Camera: the picture large, a shutter, Photo / Video, a 3 s timer, mirror;
// photos go to ~/Pictures/Camera, videos to ~/Videos/Camera; the last one
// shows as a thumbnail that opens it. Several cameras: the switch button.
AppWindow {
    id: app
    appName: "Camera"
    appIcon: 0xf0100
    implicitWidth: 1080; implicitHeight: 760

    readonly property string photos: Quickshell.env("HOME") + "/Pictures/Camera"
    readonly property string videos: Quickshell.env("HOME") + "/Videos/Camera"
    property string mode: "photo"
    property bool mirror: true
    property int timer: 0
    property int countdown: 0
    property string last: ""
    property int camIndex: 0

    MediaDevices { id: devices }
    readonly property var cams: devices.videoInputs
    CaptureSession {
        id: session
        camera: Camera {
            id: camera
            active: app.cams.length > 0
            cameraDevice: app.cams.length ? app.cams[Math.min(app.camIndex, app.cams.length - 1)] : devices.defaultVideoInput
        }
        imageCapture: ImageCapture {
            id: shot
            onImageSaved: (id, path) => { app.last = path; flashAnim.restart(); }
        }
        recorder: MediaRecorder {
            id: rec
            onRecorderStateChanged: if (recorderState === MediaRecorder.StoppedState && actualLocation.toString()) app.last = actualLocation.toString().replace("file://", "")
        }
        audioInput: AudioInput {}
        videoOutput: view
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", photos, videos])

    function stamp() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm.ss"); }
    function fire() {
        if (mode === "photo") shot.captureToFile(photos + "/" + Tr.t("Photo") + " " + stamp() + ".jpg");
        else if (rec.recorderState === MediaRecorder.RecordingState) rec.stop();
        else { rec.outputLocation = "file://" + videos + "/" + Tr.t("Video") + " " + stamp() + ".mp4"; rec.record(); }
    }
    function press() {
        if (mode === "video" && rec.recorderState === MediaRecorder.RecordingState) { rec.stop(); return; }
        if (timer > 0) { countdown = timer; tick.start(); } else fire();
    }
    Timer { id: tick; interval: 1000; repeat: true; onTriggered: { app.countdown--; if (app.countdown <= 0) { stop(); app.fire(); } } }

    Rectangle {
        id: stage
        anchors { fill: parent; margins: 16; bottomMargin: 104 }
        radius: 16
        color: "black"
        clip: true
        VideoOutput {
            id: view
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            transform: Scale { origin.x: view.width / 2; xScale: app.mirror ? -1 : 1 }
        }
        Column {
            anchors.centerIn: parent
            visible: app.cams.length === 0
            spacing: 8
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xf0100); font.family: Theme.symbols; font.pixelSize: Theme.px(56); color: "#4c5463" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Tr.t("No camera found"); font.family: Theme.font; font.pixelSize: Theme.px(18); color: "#c9d1dc" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Tr.t("Plug in a webcam - it shows up here at once"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: "#8b95a5" }
        }
        Text {
            anchors.centerIn: parent
            visible: app.countdown > 0
            text: app.countdown
            font.family: Theme.font; font.pixelSize: Theme.px(140); font.weight: Font.Light; color: "white"
        }
        Rectangle { id: flash; anchors.fill: parent; color: "white"; opacity: 0
            NumberAnimation on opacity { id: flashAnim; running: false; from: 0.8; to: 0; duration: 300 } }
        Rectangle {
            visible: rec.recorderState === MediaRecorder.RecordingState
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 12 }
            width: rt.implicitWidth + 28; height: 32; radius: 16; color: Qt.rgba(0, 0, 0, 0.55)
            Row { id: rt; anchors.centerIn: parent; spacing: 8
                Rectangle { width: 10; height: 10; radius: 5; color: "#ff5a6e"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: { const s = Math.floor(rec.duration / 1000); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); } font.family: Theme.font; font.pixelSize: Theme.px(14); color: "white" } }
        }
    }

    // ---- controls
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
        height: 76
        Rectangle {
            id: thumb
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            width: 58; height: 58; radius: 12; color: Theme.ink(0.08); clip: true
            Image { anchors.fill: parent; source: app.last && app.last.endsWith(".jpg") ? "file://" + app.last : ""; sourceSize: Qt.size(116, 116); fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Text { anchors.centerIn: parent; visible: app.last && !app.last.endsWith(".jpg"); text: String.fromCodePoint(0xf022b); font.family: Theme.symbols; font.pixelSize: Theme.px(22); color: Theme.text }
            HoverHandler { cursorShape: app.last ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: if (app.last) Quickshell.execDetached(["gio", "open", app.last]) }
        }
        Segmented { anchors { left: thumb.right; leftMargin: 16; verticalCenter: parent.verticalCenter } width: 200; options: ["Photo", "Video"]; current: app.mode === "video" ? 1 : 0; onPicked: i => app.mode = i ? "video" : "photo" }
        Rectangle {
            anchors.centerIn: parent
            width: 68; height: 68; radius: 34
            color: "transparent"; border.width: 4; border.color: app.cams.length ? Theme.text : Theme.dim
            Rectangle {
                anchors.centerIn: parent
                readonly property bool recording: rec.recorderState === MediaRecorder.RecordingState
                width: recording ? 26 : 54; height: width; radius: recording ? 6 : width / 2
                color: app.mode === "video" ? "#ff5a6e" : (app.cams.length ? Theme.text : Theme.dim)
                Behavior on width { enabled: !Theme.reduceMotion; Spring {} }
            }
            HoverHandler { cursorShape: app.cams.length ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: if (app.cams.length) app.press() }
        }
        Row {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 8
            Btn { text: app.timer ? Tr.f("Timer {n} s", { n: app.timer }) : "Timer off"; icon: 0xf051b; onClicked: app.timer = app.timer === 0 ? 3 : app.timer === 3 ? 10 : 0 }
            Btn { text: "Mirror"; icon: 0xf0d3a; primary: app.mirror; onClicked: app.mirror = !app.mirror }
            Btn { visible: app.cams.length > 1; text: "Switch camera"; icon: 0xf0a2b; onClicked: app.camIndex = (app.camIndex + 1) % app.cams.length }
        }
    }
    Shortcut { sequence: "Space"; onActivated: if (app.cams.length) app.press() }
}
