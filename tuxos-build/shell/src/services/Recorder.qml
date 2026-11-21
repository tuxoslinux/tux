pragma Singleton

import QtQuick
import Quickshell
import qs.theme
import Quickshell.Io

// Screen recording (Super + Shift + R) and instant replay (Super + Alt + R).
// gpu-screen-recorder (hardware encoding, almost free in games); recording
// shows as a live activity (red dot + time). Files go to ~/Videos.
Singleton {
    id: rec

    property bool recording: rProc.running
    property double startedAt: 0
    property bool replayOn: replayProc.running
    readonly property string videos: Quickshell.env("HOME") + "/Videos"
    property string lastFile: ""

    Process {
        id: rProc
        // what the recorder said last (shown when it could not record)
        stderr: SplitParser { onRead: line => { if (/error/i.test(line)) rec.lastError = line.replace(/^gsr error:\s*/, "").trim(); } }
        onExited: (code, status) => {
            if (!rec.lastFile) return;
            if (code === 0) Toasts.show(Tr.t("Recording saved"), rec.lastFile.replace(Quickshell.env("HOME"), "~"), Icons.recordRec,
                                        () => Quickshell.execDetached(["gio", "open", rec.lastFile]));
            else Toasts.show(Tr.t("Could not record the screen"), rec.lastError || Tr.t("The screen recorder stopped at once"), Icons.alertCircleOutline);
        }
    }
    property string lastError: ""
    function toggle() {
        if (rProc.running) { rProc.signal(2); return; }   // SIGINT: finish the file
        const f = `${videos}/Recording ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm.ss")}.mp4`;
        lastFile = f;
        startedAt = Date.now();
        Quickshell.execDetached(["mkdir", "-p", videos]);
        lastError = "";
        // the GPU's video encoder; without one (no VA-API driver, virtual
        // machines) the CPU encodes instead
        rProc.command = ["sh", "-c", "if command -v gpu-screen-recorder >/dev/null; then exec gpu-screen-recorder -w screen -f 60 -a default_output -fallback-cpu-encoding yes -o \"$1\"; else exec wf-recorder -f \"$1\"; fi", "sh", f];
        rProc.running = true;
    }

    // instant replay (SPEC round 4 #1): the last 30-60 s (Settings > Gaming)
    // kept in RAM by the GPU's video encoder; Super + Alt + R saves the clip
    // to ~/Videos/Replays with a toast (Open / Copy / Delete). By default it
    // runs only while a game runs; "always" keeps it on all the time.
    property bool cpuFallback: false
    property double replayStarted: 0
    Process {
        id: replayProc
        stdout: SplitParser {
            // gpu-screen-recorder prints the path of every saved clip
            onRead: line => { if (line.endsWith(".mp4")) rec.replaySaved(line.trim()); }
        }
        onExited: (code, status) => {
            // no hardware encoder (or no GPU capture): once more on the CPU
            if (code !== 0 && Date.now() - rec.replayStarted < 4000 && !rec.cpuFallback && rec.replayWanted) {
                rec.cpuFallback = true;
                rec.startReplay();
            }
        }
    }
    readonly property bool replayWanted: Prefs.replayMode === "always" || (Prefs.replayMode === "games" && Notifs.gameRunning) || manualReplay
    property bool manualReplay: false
    onReplayWantedChanged: replayWanted ? startReplay() : stopReplay()
    Component.onCompleted: if (replayWanted) startReplay()
    function startReplay() {
        if (replayProc.running) return;
        Quickshell.execDetached(["mkdir", "-p", videos + "/Replays"]);
        const secs = [30, 45, 60].indexOf(Prefs.replaySeconds) !== -1 ? Prefs.replaySeconds : 60;
        replayProc.command = ["gpu-screen-recorder", "-w", "screen", "-f", "60", "-a", "default_output", "-c", "mp4", "-r", String(secs), "-o", videos + "/Replays"]
                             .concat(cpuFallback ? ["-encoder", "cpu"] : []);
        replayStarted = Date.now();
        replayProc.running = true;
    }
    function stopReplay() { if (replayProc.running) replayProc.signal(15); }
    function toggleReplay() {
        if (replayProc.running) { manualReplay = false; stopReplay(); return; }
        manualReplay = true;
        startReplay();
    }
    function saveReplay() {
        if (!replayProc.running) {
            manualReplay = true;
            startReplay();
            Toasts.show(Tr.t("Instant replay on"), Tr.f("The last {s} s are kept from now on; Super + Alt + R saves them", { s: Prefs.replaySeconds }), Icons.recordRec);
            return;
        }
        replayProc.signal(10);   // SIGUSR1: save the buffer
    }
    function replaySaved(path) {
        const name = path.split("/").pop();

        Toasts.show(Tr.t("Replay saved"), "~/Videos/Replays/" + name, Icons.recordRec, () => Quickshell.execDetached(["gio", "open", path]), [
            { text: Tr.t("Open"), primary: true, run: () => Quickshell.execDetached(["gio", "open", path]) },
            { text: Tr.t("Copy"), run: () => Quickshell.execDetached(["sh", "-c", "printf 'file://%s\n' \"$1\" | wl-copy -t text/uri-list", "sh", path]) },
            { text: Tr.t("Delete"), run: () => { Quickshell.execDetached(["gio", "trash", path]); Toasts.show(Tr.t("Replay moved to the Trash"), name, Icons.deleteOutline); } }
        ], 8000);
    }
}
