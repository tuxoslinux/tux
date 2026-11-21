pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Energy use per app (SPEC round 8 #8; laptops): while on battery, every
// minute the battery's power draw is shared out by each app's CPU time in
// that minute (an estimate: the GPU's share is not known per app). Summed
// since the last time the laptop was charged; System manager > Battery.
Singleton {
    id: en
    readonly property bool counter: (Quickshell.env("QS_APP_ID") || "") === ""
    readonly property bool on: counter && SmartPower.hasBattery && SmartPower.onBattery && !Shell.live
    property var apps: ({})                // app -> watt-hours
    property var last: ({})                // app -> cpu ticks at the last look
    property double lastAt: 0
    readonly property string path: Quickshell.env("HOME") + "/.local/state/tuxos/energy.json"
    FileView { id: file; path: en.path; printErrors: false; onLoaded: { try { en.apps = JSON.parse(text()) || {}; } catch (e) {} } }
    // plugged in: a fresh count from the next unplug
    onOnChanged: if (!on) { last = {}; lastAt = 0; } else if (SmartPower.pct >= 95) { apps = {}; file.setText("{}"); }
    Timer { interval: 60000; repeat: true; running: en.on; triggeredOnStart: true; onTriggered: if (!sample.running) sample.running = true }
    Process {
        id: sample
        // power now (µW) and each process' CPU ticks by name
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/power_now 2>/dev/null | head -1; for s in /proc/[0-9]*/stat; do read -r l < \"$s\" 2>/dev/null || continue; n=${l#*(}; n=${n%%)*}; r=${l##*) }; set -- $r; echo \"$n $(( ${12} + ${13} ))\"; done 2>/dev/null | awk '{t[$1]+=$2} END {for (k in t) print k, t[k]}'"]
        stdout: StdioCollector { onStreamFinished: en.add(text) }
    }
    function add(text) {
        const lines = text.trim().split("\n");
        const watts = (parseInt(lines.shift()) || 0) / 1e6;
        const now = Date.now(), ticks = {};
        for (const l of lines) { const i = l.lastIndexOf(" "); ticks[l.slice(0, i)] = parseInt(l.slice(i + 1)) || 0; }
        if (lastAt > 0 && watts > 0) {
            const hours = (now - lastAt) / 3600000;
            let total = 0; const d = {};
            for (const k in ticks) { const x = Math.max(0, ticks[k] - (last[k] || ticks[k])); if (x > 0) { d[k] = x; total += x; } }
            if (total > 0) {
                const a = Object.assign({}, apps);
                for (const k in d) a[k] = (a[k] || 0) + watts * hours * d[k] / total;
                apps = a;
                file.setText(JSON.stringify(a));
            }
        }
        last = ticks; lastAt = now;
    }
}
