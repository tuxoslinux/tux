pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Timers, stopwatch and alarms of the Clock app, shared with the shell
// (~/.local/state/tuxos/clock.json). They keep running when the Clock app
// is closed: the bar shows them as live activities and the shell rings.
//   timers:    [{ id, name, total (ms), end (ms), paused, left (ms when paused) }]
//   stopwatch: { start (ms), running, elapsed (ms when stopped), laps: [ms] }
//   alarms:    [{ id, time "07:30", days [1..7, Mon = 1], enabled, label }]
Singleton {
    id: cs
    property var timers: []
    property var stopwatch: ({ start: 0, running: false, elapsed: 0, laps: [] })
    property var alarms: []
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/tuxos"

    FileView {
        id: file
        path: cs.dir + "/clock.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text());
                cs.timers = j.timers || [];
                cs.stopwatch = j.stopwatch || { start: 0, running: false, elapsed: 0, laps: [] };
                cs.alarms = j.alarms || [];
            } catch (e) {}
            cs.setWake();
        }
    }
    function save() {
        Quickshell.execDetached(["mkdir", "-p", dir]);
        file.setText(JSON.stringify({ timers: timers, stopwatch: stopwatch, alarms: alarms }, null, 1));
        // the shell may have started before the file existed: tell it
        if (Quickshell.env("QS_APP_ID") === "tuxos-clock") ipcLater.restart();
    }
    Timer { id: ipcLater; interval: 300; onTriggered: Quickshell.execDetached(["qs", "-c", "tuxos", "ipc", "call", "shell", "clockChanged"]) }
    function reload() { file.reload(); }

    // ---- timers
    function addTimer(ms, name) {
        const n = name || (ms >= 3600000 ? Math.round(ms / 3600000) + " h timer" : Math.round(ms / 60000) + " min timer");
        timers = timers.concat([{ id: Date.now(), name: n, total: ms, end: Date.now() + ms, paused: false, left: ms }]);
        save();
    }
    function leftOf(t, now) { return t.paused ? t.left : Math.max(0, t.end - now); }
    function pauseTimer(t) {
        timers = timers.map(x => x.id !== t.id ? x : (x.paused ? Object.assign({}, x, { paused: false, end: Date.now() + x.left })
                                                                : Object.assign({}, x, { paused: true, left: Math.max(0, x.end - Date.now()) })));
        save();
    }
    function addMinute(t) {
        timers = timers.map(x => x.id !== t.id ? x : Object.assign({}, x, { total: x.total + 60000, end: x.end + 60000, left: x.left + 60000 }));
        save();
    }
    function removeTimer(t) { timers = timers.filter(x => x.id !== t.id); save(); }

    // ---- stopwatch
    function swElapsed(now) { return stopwatch.running ? stopwatch.elapsed + now - stopwatch.start : stopwatch.elapsed; }
    function swToggle() {
        const s = Object.assign({}, stopwatch);
        if (s.running) { s.elapsed += Date.now() - s.start; s.running = false; }
        else { s.start = Date.now(); s.running = true; }
        stopwatch = s; save();
    }
    function swLap() { const s = Object.assign({}, stopwatch); s.laps = [swElapsed(Date.now())].concat(s.laps || []); stopwatch = s; save(); }
    function swReset() { stopwatch = { start: 0, running: false, elapsed: 0, laps: [] }; save(); }

    // ---- alarms
    // the next alarm (epoch ms), or 0
    function nextAlarm(now) {
        let best = 0;
        for (const a of alarms) {
            if (!a.enabled) continue;
            const hm = (a.time || "").split(":").map(Number);
            for (let d = 0; d < 8; d++) {
                const t = new Date(now); t.setDate(t.getDate() + d); t.setHours(hm[0] || 0, hm[1] || 0, 0, 0);
                const wd = t.getDay() === 0 ? 7 : t.getDay();
                if (t.getTime() <= now || (a.days && a.days.length && a.days.indexOf(wd) < 0)) continue;
                if (!best || t.getTime() < best) best = t.getTime();
                break;
            }
        }
        return best;
    }
    // the PC wakes from sleep a minute before the next alarm (RTC, tuxos-power;
    // only the desktop shell sets it, so it is set once)
    property double wakeAt: -1
    function setWake() {
        if ((Quickshell.env("QS_APP_ID") || "") !== "" || Quickshell.env("TUXOS_GREETER") === "1") return;
        const n = nextAlarm(Date.now());
        const at = n ? Math.floor(n / 1000) - 60 : 0;
        if (at === wakeAt) return;
        wakeAt = at;
        Quickshell.execDetached(["sh", "-c", "command -v tuxos-power >/dev/null || exit 0; if [ \"$1\" = 0 ]; then pkexec tuxos-power wake-clear; else pkexec tuxos-power wake \"$1\"; fi", "sh", String(at)]);
    }
    // after an alarm rang, the one after it
    Timer { interval: 60000; repeat: true; running: cs.wakeAt > 0; onTriggered: if (Date.now() / 1000 > cs.wakeAt + 120) cs.setWake() }
    function addAlarm(time, days, label) { alarms = alarms.concat([{ id: Date.now(), time: time, days: days, enabled: true, label: label || "" }]); save(); }
    function toggleAlarm(a, on) { alarms = alarms.map(x => x.id !== a.id ? x : Object.assign({}, x, { enabled: on })); save(); }
    function removeAlarm(a) { alarms = alarms.filter(x => x.id !== a.id); save(); }
    function daysText(d) {
        if (!d || d.length === 0) return "Once";
        if (d.length === 7) return "Every day";
        if (d.join() === "1,2,3,4,5") return "Mon-Fri";
        if (d.join() === "6,7") return "Sat, Sun";
        return d.map(x => ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][x]).join(", ");
    }
}
