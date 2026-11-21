pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Game save backups (tuxos-saves, Ludusavi): once a day (never while a game
// runs) and before a Steam game updates (its download starts: the game's
// saves are backed up first). Only when Ludusavi is installed and Settings >
// Gaming has it on.
Singleton {
    id: sv
    property bool have: false
    property double last: 0
    readonly property bool on: Prefs.saveBackups && have && !Shell.live
    Process { id: haveProc; command: ["sh", "-c", "tuxos-saves have && echo yes; cat \"${XDG_STATE_HOME:-$HOME/.local/state}/tuxos/saves-last\" 2>/dev/null"]; running: true
              stdout: StdioCollector { onStreamFinished: { const l = text.split("\n"); sv.have = l[0] === "yes"; sv.last = (parseInt(l[l[0] === "yes" ? 1 : 0]) || 0) * 1000; } } }
    function check() { haveProc.running = false; haveProc.running = true; }

    Process { id: run; onExited: code => { if (code === 0) sv.last = Date.now(); } }
    function backup(game) {
        if (run.running) return;
        run.command = ["tuxos-saves", "backup"].concat(game ? [game] : []);
        run.running = true;
    }
    // once a day
    Connections {
        target: Tick
        function onMinute(t) { if (sv.on && !Notifs.gameRunning && t - sv.last > 86400000) sv.backup(""); }
    }
    // before an update: Steam's downloading folder has an installed game's id
    property var backedUp: ({})            // app id -> the download already covered
    Timer { interval: 60000; repeat: true; running: sv.on; onTriggered: if (!dl.running) dl.running = true }
    Process {
        id: dl
        command: ["sh", "-c", "for r in \"$HOME/.local/share/Steam\" \"$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam\"; do ls \"$r/steamapps/downloading\" 2>/dev/null; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = text.split("\n").filter(x => /^\d+$/.test(x));
                const b = Object.assign({}, sv.backedUp);
                for (const id of ids) {
                    if (b[id]) continue;
                    const g = Games.byId("steam:" + id);
                    if (!g) continue;                      // a new install, nothing to keep yet
                    b[id] = true;
                    sv.backup(g.name);
                    Toasts.show(Tr.f("{name} is updating", { name: g.name }), Tr.t("Its saves were backed up first"), Icons.contentSaveOutline);
                }
                for (const id in b) if (ids.indexOf(id) === -1) delete b[id];   // done: the next update counts again
                sv.backedUp = b;
            }
        }
    }
}
