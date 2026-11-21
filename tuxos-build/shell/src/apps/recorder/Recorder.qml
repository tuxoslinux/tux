import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.theme
import qs.components
import qs.services

// Sound recorder: one big button, a live level, the time; recordings go to
// ~/Music/Recordings as Ogg Vorbis (small, good quality). The list plays,
// renames and moves them to Trash (with Undo). The microphone is the one
// chosen in Settings > Sound (with its noise filter when that is on).
AppWindow {
    id: app
    appName: "Sound recorder"
    appIcon: 0xf036c
    implicitWidth: 900; implicitHeight: 680

    readonly property string dir: Quickshell.env("HOME") + "/Music/Recordings"
    readonly property var mic: Pipewire.defaultAudioSource
    PwObjectTracker { objects: app.mic ? [app.mic] : [] }
    PwNodePeakMonitor { id: peak; node: app.mic; enabled: app.mic !== null }

    property bool recording: rec.running
    property double started: 0
    property double now: Date.now()
    Timer { interval: 250; repeat: true; running: app.recording; onTriggered: app.now = Date.now() }
    function time(ms) { const s = Math.floor(ms / 1000); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    Process {
        id: rec
        onExited: list.run()
    }
    function toggle() {
        if (rec.running) { rec.signal(2); return; }        // SIGINT: pw-record closes the file cleanly
        if (!mic) return;
        const name = Tr.t("Recording") + " " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm.ss") + ".ogg";
        rec.command = ["sh", "-c", "mkdir -p \"$1\" && exec pw-record --channels 1 --rate 48000 \"$1/$2\"", "sh", dir, name];
        started = Date.now(); now = started;
        rec.running = true;
    }

    // recordings
    property var files: []
    Cmd {
        id: list
        command: ["sh", "-c", "cd \"$1\" 2>/dev/null || exit 0; for f in *; do [ -f \"$f\" ] || continue; d=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 -- \"$f\" 2>/dev/null); printf '%s\\t%s\\t%s\\n' \"$f\" \"$(stat -c %Y -- \"$f\")\" \"${d:-0}\"; done", "sh", app.dir]
        Component.onCompleted: run()
        onDone: out => app.files = out.split("\n").filter(l => l).map(l => { const t = l.split("\t"); return { name: t[0], time: +t[1] * 1000, dur: +t[2] }; }).sort((a, b) => b.time - a.time)
    }
    property string playing: ""
    Process { id: player; onExited: app.playing = "" }
    function play(f) {
        if (player.running) { player.signal(15); if (playing === f.name) return; }
        playing = f.name;
        player.command = ["mpv", "--no-video", "--no-terminal", dir + "/" + f.name];
        player.running = true;
    }
    property string banner: ""
    property var undo: null
    Timer { id: bt; interval: 6000; onTriggered: { app.banner = ""; app.undo = null; } }
    function trash(f) {
        const p = dir + "/" + f.name;
        Quickshell.execDetached(["gio", "trash", "--", p]);
        files = files.filter(x => x.name !== f.name);
        banner = Tr.f("{n} moved to Trash", { n: f.name }); bt.restart();
        undo = () => Quickshell.execDetached(["sh", "-c", "T=\"$HOME/.local/share/Trash\"; mv -- \"$T/files/$1\" \"$2\" && rm -f -- \"$T/info/$1.trashinfo\"; true", "sh", f.name, p]);
        Qt.callLater(() => {});
    }
    property string renaming: ""

    // ---- the big button
    Column {
        id: top
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 32 }
        spacing: 16
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 150; height: 150
            // the level ring
            Rectangle {
                anchors.centerIn: parent
                readonly property real lvl: app.recording && peak.peak !== undefined ? Math.min(1, peak.peak * 2.2) : 0
                width: 116 + lvl * 34; height: width; radius: width / 2
                color: "transparent"; border.width: 3; border.color: Qt.rgba(1, 0.42, 0.48, app.recording ? 0.6 : 0)
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 104; height: 104; radius: 52
                color: app.recording ? "#ff5a6e" : (app.mic ? Theme.accent : Theme.ink(0.1))
                Rectangle { anchors.centerIn: parent; width: app.recording ? 30 : 34; height: width; radius: app.recording ? 6 : width / 2; color: app.recording ? "white" : Theme.accentInk; opacity: app.mic ? 1 : 0.3
                    Behavior on radius { enabled: !Theme.reduceMotion; Spring {} } }
                HoverHandler { cursorShape: app.mic ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { onTapped: app.toggle() }
            }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.recording ? app.time(app.now - app.started) : (app.mic ? Tr.t("Press to record") : Tr.t("No microphone found")); font.family: Theme.font; font.pixelSize: Theme.px(app.recording ? 30 : 17); font.weight: app.recording ? Font.Light : Font.Normal; color: app.mic ? Theme.text : Theme.muted }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.mic ? (app.mic.description || app.mic.nickname || app.mic.name) : Tr.t("Plug in a microphone or headset"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
    }

    // ---- recordings
    Text { id: hdr; anchors { left: parent.left; leftMargin: 28; top: top.bottom; topMargin: 24 } text: Tr.t("RECORDINGS"); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
    Text { anchors { right: parent.right; rightMargin: 28; verticalCenter: hdr.verticalCenter } text: "~/Music/Recordings"; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.accent
        HoverHandler { cursorShape: Qt.PointingHandCursor } TapHandler { onTapped: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && gio open \"$1\"", "sh", app.dir]) } }
    ListView {
        anchors { left: parent.left; right: parent.right; top: hdr.bottom; topMargin: 8; bottom: parent.bottom; margins: 20 }
        clip: true
        spacing: 4
        model: app.files
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width; height: 52; radius: 12
            color: app.playing === modelData.name ? Theme.accentFill : (rh.hovered ? Theme.fill : "transparent")
            Rectangle {
                x: 8; anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34; radius: 17; color: Theme.ink(0.08)
                Text { anchors.centerIn: parent; text: String.fromCodePoint(app.playing === modelData.name ? 0xf04db : 0xf040a); font.family: Theme.symbols; font.pixelSize: Theme.px(16); color: Theme.text }
                TapHandler { onTapped: app.play(modelData) }
            }
            Column {
                x: 58; anchors.verticalCenter: parent.verticalCenter
                visible: app.renaming !== modelData.name
                Text { text: modelData.name.replace(/\.ogg$/, ""); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                Text { text: Tr.date(new Date(modelData.time), "d MMM, HH:mm") + " · " + app.time(modelData.dur * 1000); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
            }
            Rectangle {
                visible: app.renaming === modelData.name
                x: 56; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 260; height: 34; radius: 9
                color: Theme.ink(0.06); border.width: 1; border.color: Theme.accentLine
                TextInput {
                    id: rn
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text
                    onVisibleChanged: if (visible) { text = modelData.name.replace(/\.ogg$/, ""); forceActiveFocus(); selectAll(); }
                    Keys.onReturnPressed: { const n = text.trim(); app.renaming = ""; if (n) Quickshell.execDetached(["mv", "-n", "--", app.dir + "/" + modelData.name, app.dir + "/" + n + ".ogg"]); renameLater.restart(); }
                    Keys.onEscapePressed: app.renaming = ""
                }
            }
            Row {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 4
                visible: rh.hovered
                Btn { text: "Rename"; onClicked: app.renaming = modelData.name }
                Btn { text: "Trash"; onClicked: app.trash(modelData) }
            }
            HoverHandler { id: rh }
        }
    }
    Timer { id: renameLater; interval: 300; onTriggered: list.run() }
    EmptyState {
        anchors { horizontalCenter: parent.horizontalCenter; top: hdr.bottom; topMargin: 32 }
        visible: app.files.length === 0
        size: 56
        title: "No recordings yet"; hint: "Your recordings show up here"
    }
    Rectangle {
        visible: app.banner !== ""
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
        width: br.implicitWidth + 32; height: 44; radius: 14
        color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
        Row { id: br; anchors.centerIn: parent; spacing: 12
            Text { anchors.verticalCenter: parent.verticalCenter; text: app.banner; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
            Btn { text: "Undo"; primary: true; onClicked: { const u = app.undo; app.banner = ""; app.undo = null; if (u) u(); Qt.callLater(() => list.run()); } } }
    }
    canClose: function() { if (rec.running) rec.signal(2); return true; }
}
