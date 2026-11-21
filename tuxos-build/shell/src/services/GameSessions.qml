pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Game session summary (SPEC round 2 #14, mockup shell2/14-gamesum): when a
// game closes (tuxos-gamed's game mode ends), the newest MangoHud log
// (~/.local/share/tuxos/gamelogs) becomes a card under the bar: time played,
// average FPS, 1 % low, hottest CPU / GPU, stutters, FPS over the session.
// Kept in ~/.local/share/tuxos/game-history.json (System manager > Gaming).
Singleton {
    id: gs
    property var last: null
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/tuxos/gamelogs"

    property bool wasRunning: false
    Connections {
        target: Notifs
        function onGameRunningChanged() {
            if (gs.wasRunning && !Notifs.gameRunning) later.restart();   // MangoHud closes its log a moment after
            gs.wasRunning = Notifs.gameRunning;
        }
    }
    Timer { id: later; interval: 2500; onTriggered: gs.summarise() }

    Process {
        id: newest
        command: ["sh", "-c", "f=$(ls -t \"$1\"/*.csv 2>/dev/null | head -1); [ -n \"$f\" ] && echo \"$f\" && cat \"$f\"", "sh", gs.dir]
        stdout: StdioCollector { onStreamFinished: gs.parse(text) }
    }
    function summarise() { if (!newest.running) newest.running = true; }

    function parse(text) {
        const lines = text.split("\n");
        const file = lines.shift() || "";
        const head = lines.findIndex(l => l.startsWith("fps,"));
        if (head < 0) return;
        const cols = lines[head].split(",");
        const ix = n => cols.indexOf(n);
        const rows = lines.slice(head + 1).filter(l => l).map(l => l.split(",").map(Number));
        if (rows.length < 3) return;
        const fps = rows.map(r => r[ix("fps")]);
        const avg = fps.reduce((a, b) => a + b, 0) / fps.length;
        const sorted = fps.slice().sort((a, b) => a - b);
        const low1 = sorted.slice(0, Math.max(1, Math.round(sorted.length * 0.01))).reduce((a, b) => a + b, 0) / Math.max(1, Math.round(sorted.length * 0.01));
        const maxOf = n => ix(n) < 0 ? 0 : Math.max(...rows.map(r => r[ix(n)] || 0));
        const secs = (rows[rows.length - 1][ix("elapsed")] || 0) / 1e9;
        const stutters = fps.filter(f => f < avg * 0.6).length;
        const step = Math.max(1, Math.floor(fps.length / 60));
        const name = file.split("/").pop().replace(/_\d{4}-\d\d-\d\d_.*$/, "");
        const entry = DesktopEntries.heuristicLookup(name);
        last = { game: entry ? entry.name : name.charAt(0).toUpperCase() + name.slice(1), seconds: Math.round(secs), avg: Math.round(avg), low1: Math.round(low1),
                 cpuTemp: maxOf("cpu_temp"), gpuTemp: maxOf("gpu_temp"), stutters: stutters, fps: fps.filter((_, i) => i % step === 0), at: Date.now() };
        history.add(last);
        Shell.open("gamesum", Shell.focusedScreen, Shell.clockX || 640, 160);
    }
    function duration(s) {
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h > 0 ? `${h} h ${m} min` : (m > 0 ? `${m} min` : `${s} s`);
    }

    // history for System manager
    QtObject {
        id: history
        function add(e) {
            const copy = Object.assign({}, e); delete copy.fps;
            Quickshell.execDetached(["sh", "-c", "f=\"$HOME/.local/share/tuxos/game-history.json\"; [ -s \"$f\" ] || echo '[]' > \"$f\"; jq --argjson e \"$1\" '. + [$e] | .[-200:]' \"$f\" > \"$f.new\" && mv \"$f.new\" \"$f\"", "sh", JSON.stringify(copy)]);
        }
    }
}
