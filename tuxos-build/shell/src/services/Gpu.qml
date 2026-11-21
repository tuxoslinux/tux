pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// GPU tuning with LACT (SPEC round 7 #2): AMD, NVIDIA and Intel; presets
// Quiet (a lower power limit), Stock and Performance (the highest limit
// the card allows), for every game or per game (its profile). Talks to
// LACT's daemon over /run/lactd.sock (members of wheel); LACT itself
// takes a change back unless it is confirmed, and TuxOS confirms it only
// once it was applied. Safety: when the last session did not end cleanly
// (a crash or a hang after a change), the next login puts Stock back.
Singleton {
    id: gpu

    property bool available: false        // LACT answers
    property var devices: []              // [{ id, name }]
    property var stats: null              // power: { cap_current, cap_min, cap_max, cap_default }
    readonly property string device: devices.length ? devices[0].id : ""
    readonly property bool canLimit: stats !== null && stats.power !== undefined && stats.power.cap_max > 0
    readonly property string preset: Prefs.gpuPreset

    // ---- LACT's socket: one JSON request per line, answers in order
    property var waiting: []
    Socket {
        id: sock
        path: "/run/lactd.sock"
        connected: false
        onConnectedChanged: {
            if (connected) { gpu.available = true; gpu.request({ command: "list_devices" }, d => { gpu.devices = (d || []).map(x => ({ id: x.id, name: x.name || x.id })); gpu.readStats(); }); }
            else { gpu.waiting = []; }
        }
        parser: SplitParser {
            onRead: line => {
                const cb = gpu.waiting.shift();
                let r = null;
                try { r = JSON.parse(line); } catch (e) {}
                if (cb) cb(r && r.status === "ok" ? r.data : null, r);
            }
        }
    }
    function request(obj, cb) {
        if (!sock.connected) { if (cb) cb(null, null); return; }
        waiting = waiting.concat([cb || null]);
        sock.write(JSON.stringify(obj) + "\n");
        sock.flush();
    }
    // only when LACT's daemon runs (no socket errors without it)
    Process { id: lookLact; command: ["test", "-S", "/run/lactd.sock"]; onExited: code => { if (code === 0) { sock.connected = false; sock.connected = true; } } }
    function connect() { if (!lookLact.running) lookLact.running = true; }
    function readStats() { if (device) request({ command: "device_stats", args: { id: device } }, d => gpu.stats = d); }

    // ---- presets: a power limit, confirmed once applied
    function capFor(name) {
        if (!canLimit) return -1;
        const p = stats.power, def = p.cap_default || p.cap_max;
        if (name === "quiet") return Math.max(p.cap_min || 0, Math.round(def * 0.75));
        if (name === "performance") return p.cap_max;
        return def;
    }
    function apply(name) {
        if (!device || !canLimit) return false;
        const cap = capFor(name);
        request({ command: "set_power_cap", args: { id: device, cap: cap } }, (d, r) => {
            if (r && r.status === "ok") request({ command: "confirm_pending_config", args: "confirm" }, () => gpu.readStats());
        });
        return true;
    }
    function choose(name) {
        Prefs.gpuPreset = name;
        apply(name);
    }

    // ---- per game: the game's profile wins while it runs
    property string gameApplied: ""
    Connections {
        target: Notifs
        function onGameRunningChanged() {
            if (!Notifs.gameRunning && gpu.gameApplied) { gpu.apply(Prefs.gpuPreset); gpu.gameApplied = ""; }
        }
    }
    function forGame(name) {
        if (!name || name === "default") return;
        if (!sock.connected) connect();
        Qt.callLater(() => { if (gpu.apply(name)) gpu.gameApplied = name; });
    }

    // ---- safety net: a session that did not end cleanly after a change
    readonly property string cleanFile: Quickshell.env("HOME") + "/.local/state/tuxos/session-clean"
    Process {
        id: cleanCheck
        // once per login (a shell restart is not a new session)
        command: ["sh", "-c", "r=\"${XDG_RUNTIME_DIR:-/tmp}/tuxos-gpu-checked\"; if [ -e \"$r\" ]; then echo clean; exit 0; fi; : > \"$r\"; [ -e \"$1\" ] && echo clean; rm -f \"$1\"", "sh", gpu.cleanFile]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "clean" && Prefs.gpuPreset !== "stock" && Prefs.gpuPreset !== "") {
                    Prefs.gpuPreset = "stock";
                    gpu.connect();
                    Qt.callLater(() => gpu.apply("stock"));
                    Toasts.show(Tr.t("GPU back to Stock"), Tr.t("The last session did not end cleanly after a GPU tuning change, so TuxOS put the stock settings back"), Icons.expansionCard);
                }
            }
        }
    }
    // Power writes the marker on a normal log out / restart / shut down
    function markClean() { Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && : > \"$1\"", "sh", cleanFile]); }
    Component.onCompleted: { cleanCheck.running = true; connect(); }
}
