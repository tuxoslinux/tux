pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.theme

// Live activities in the bar (SPEC "Live activities", round 2 #11): what is
// going on right now, newest first. The bar chip shows the first one with
// "+N"; hovering lists them all with their progress.
//   media (music / video), screen recording (red dot + time), timers and
//   stopwatch (Clock app), next calendar event (10 min before), shader
//   pre-caching (Steam's fossilize), downloads (browsers' partial files).
// Item: { kind, icon, title, sub, progress (0..1 or -1), right, color, player }
Singleton {
    id: act

    property double now: Date.now()
    readonly property bool busy: list.length > 0
    // one tick a second while something is live (an activity, a Clock
    // timer or the stopwatch); otherwise only Tick's shared minute
    readonly property bool live: busy || ClockStore.timers.length > 0 || ClockStore.stopwatch.running || Games.starting !== null
    Timer {
        interval: 1000
        repeat: true
        running: act.live
        onTriggered: {
            const t = Date.now();
            act.now = t;
            act.checkClock(t);
            if (act.busy || Games.starting !== null) act.checkSystem();
        }
    }
    Connections {
        target: Tick
        function onMinute(t) {
            act.now = t;
            if (!act.live) { ClockStore.reload(); act.checkClock(t); }
            act.checkSystem();
        }
    }

    // ---- Clock app timers, stopwatch, alarms (ClockStore): the shell rings
    // finished timers and alarms even when the Clock app is closed
    property var rung: ({})
    function ring(key, title, body) {
        if (rung[key]) return;
        const r = Object.assign({}, rung); r[key] = true; rung = r;
        Toasts.show(title, body, Icons.alarm, null, [], 0);
        Quickshell.execDetached(["sh", "-c", "for i in 1 2 3; do pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || canberra-gtk-play -i alarm-clock-elapsed 2>/dev/null; sleep 0.4; done"]);
    }
    function checkClock(t) {
        for (const tm of ClockStore.timers)
            if (!tm.paused && tm.end <= t) { ring("t" + tm.id, tm.name + " is done", "Timer · " + Media.time(tm.total / 1000)); ClockStore.removeTimer(tm); }
        const d = new Date(t);
        const hm = Qt.formatTime(d, "HH:mm"), dow = d.getDay() === 0 ? 7 : d.getDay();
        for (const a of ClockStore.alarms)
            if (a.enabled && a.time === hm && (!a.days || a.days.length === 0 || a.days.indexOf(dow) !== -1)) {
                ring("a" + a.id + Qt.formatDate(d, "yyyyMMdd"), "Alarm " + a.time, a.label || ClockStore.daysText(a.days));
                if (!a.days || a.days.length === 0) ClockStore.toggleAlarm(a, false);
            }
    }

    // ---- shader pre-caching and downloads: a cheap check, only once a
    // minute while nothing else is live
    property bool shaders: false
    property bool bigDownload: false    // holds automatic sleep off (services/Idle.qml)
    property var downloads: []          // [{ name, size }]
    Process {
        id: sys
        // S: shaders; D: a browser download; B: a big download (system update /
        // Store: pacman's partial files; Steam: its downloading folder; Flatpak)
        command: ["sh", "-c", "pgrep fossilize_repl >/dev/null && echo S; for f in \"$HOME\"/Downloads/*.part \"$HOME\"/Downloads/*.crdownload; do [ -e \"$f\" ] && echo \"D $(stat -c %s \"$f\") $f\"; done; "
                   + "ls /var/cache/pacman/pkg/*.part >/dev/null 2>&1 && echo B; pgrep -x flatpak >/dev/null && echo B; "
                   + "for d in \"$HOME\"/.local/share/Steam/steamapps/downloading/*/ \"$HOME\"/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/downloading/*/; do [ -d \"$d\" ] && echo B && break; done; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                act.shaders = lines.indexOf("S") !== -1;
                act.bigDownload = lines.indexOf("B") !== -1 || lines.some(l => l.startsWith("D "));
                act.downloads = lines.filter(l => l.startsWith("D ")).map(l => {
                    const m = /^D (\d+) (.*)$/.exec(l);
                    return { size: parseInt(m[1]), name: m[2].split("/").pop().replace(/\.(part|crdownload)$/, "") };
                });
            }
        }
    }
    function checkSystem() { if (!sys.running) sys.running = true; }

    // ---- apps' running jobs (components/ActivityFile.qml: file copies,
    // USB writes): JSON files in the runtime folder, read again every
    // second while there are any
    property var appJobs: []
    FolderListModel {
        id: jobDir
        folder: "file://" + (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tuxos-activities"
        nameFilters: ["*.json"]
        showDirs: false
        onCountChanged: act.readJobs()
    }
    Process {
        id: jobRead
        command: ["sh", "-c", "for f in \"$1\"/*.json; do [ -e \"$f\" ] && cat \"$f\" && echo; done; true", "sh", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tuxos-activities"]
        stdout: StdioCollector { onStreamFinished: { act.appJobs = text.split("\n").filter(l => l.trim()).map(l => { try { return JSON.parse(l); } catch (e) { return null; } }).filter(x => x); } }
    }
    function readJobs() { if (jobDir.count === 0) { appJobs = []; return; } if (!jobRead.running) jobRead.running = true; }
    Timer { interval: 1000; repeat: true; running: jobDir.count > 0; onTriggered: act.readJobs() }
    // Steam finished pre-caching shaders: ready to play (SPEC round 4 #4)
    property bool hadShaders: false
    onShadersChanged: {
        if (shaders) hadShaders = true;
        else if (hadShaders) { hadShaders = false; Toasts.show(Tr.t("Shaders ready"), Tr.t("Steam finished pre-caching: games start smoother now"), Icons.gamepadVariant); }
    }
    Component.onCompleted: { checkSystem(); Quickshell.execDetached(["mkdir", "-p", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tuxos-activities"]); }

    function size(b) {
        if (b > 1e9) return (b / 1e9).toFixed(1) + " GB";
        if (b > 1e6) return Math.round(b / 1e6) + " MB";
        return Math.round(b / 1e3) + " kB";
    }

    readonly property var list: {
        const out = [];
        const t = now;
        for (const p of Media.active) {
            const video = Media.isVideo(p);
            out.push({ kind: video ? "video" : "music", icon: video ? Icons.play : Icons.musicNote, title: Media.title(p), sub: Media.artist(p),
                       progress: Media.progress(p), right: p.length > 0 ? `${Media.time(p.position)} / ${Media.time(p.length)}` : "", player: p, color: Theme.accent });
        }
        if (Recorder.recording)
            out.unshift({ kind: "record", icon: Icons.recordRec, title: Tr.t("Recording"), sub: "Super + Shift + R stops", progress: -1,
                          right: Media.time((t - Recorder.startedAt) / 1000), color: Theme.danger });
        for (const tm of ClockStore.timers) {
            const left = ClockStore.leftOf(tm, t);
            if (left <= 0 && !tm.paused) continue;
            out.push({ kind: "timer", icon: Icons.timerSand, title: tm.name || "Timer", sub: tm.paused ? "Paused" : "",
                       progress: tm.total ? 1 - left / tm.total : -1, right: Media.time(left / 1000) + " left", color: Theme.accent });
        }
        if (ClockStore.stopwatch.running)
            out.push({ kind: "stopwatch", icon: Icons.timerOutline, title: Tr.t("Stopwatch"), sub: "", progress: -1, right: Media.time(ClockStore.swElapsed(t) / 1000), color: Theme.accent });
        const ev = Events.next(t);
        if (ev && ev.start - t <= 10 * 60000)
            out.push({ kind: "event", icon: Icons.calendar, title: ev.title, sub: "Calendar", progress: -1,
                       right: ev.start - t > 60000 ? `in ${Math.ceil((ev.start - t) / 60000)} min` : "now", color: Theme.accent });
        if (shaders)
            out.push({ kind: "shaders", icon: Icons.gamepadVariant, title: Tr.t("Pre-caching shaders"), sub: "Steam · games start smoother after this", progress: -1, right: "", color: Theme.accent });
        for (const j of appJobs)
            out.push({ kind: "job", icon: j.icon || Icons.folder, title: j.title, sub: j.sub || "", progress: j.progress, right: j.right || "", color: Theme.accent });
        for (const d of downloads)
            out.push({ kind: "download", icon: Icons.download, title: d.name, sub: "Downloading", progress: -1, right: size(d.size), color: Theme.accent });
        return out;
    }
}
