pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Screen time (SPEC round 5 #18): how long each app was in front, per day,
// only on this PC (~/.local/share/tuxos/screentime.json, 35 days kept),
// not while idle or locked. Settings > Privacy turns it off and clears it.
// Games are counted the same way (their window), plus the game history.
Singleton {
    id: st
    readonly property bool counter: (Quickshell.env("QS_APP_ID") || "") === ""
    readonly property bool on: Prefs.screenTime && !Shell.live && counter
    readonly property string path: Quickshell.env("HOME") + "/.local/share/tuxos/screentime.json"
    property var days: ({})                // "2026-11-09" -> { app: seconds }
    FileView {
        id: file
        path: st.path
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { st.days = JSON.parse(text()) || {}; } catch (e) { st.days = {}; } }
    }
    IdleMonitor { id: idle; enabled: st.on; timeout: 120; respectInhibitors: true }

    // the app in front now (its class), counted every 15 s
    readonly property string current: {
        const t = ToplevelManager.activeToplevel;
        return t ? (t.appId || "") : "";
    }
    property double lastAt: Date.now()
    Timer {
        interval: 15000; repeat: true; running: st.on
        onTriggered: st.count()
    }
    function count() {
        const now = Date.now(), dt = Math.min(60, (now - lastAt) / 1000);
        lastAt = now;
        if (!on || idle.isIdle || Power.locked || current === "") return;
        const day = Qt.formatDate(new Date(), "yyyy-MM-dd");
        const d = Object.assign({}, days);
        const m = Object.assign({}, d[day] || {});
        m[current] = (m[current] || 0) + dt;
        d[day] = m;
        // keep 35 days
        const keys = Object.keys(d).sort();
        while (keys.length > 35) delete d[keys.shift()];
        days = d;
        if (!saveLater.running) saveLater.start();
    }
    Timer { id: saveLater; interval: 60000; onTriggered: file.setText(JSON.stringify(st.days)) }
    onOnChanged: if (!Prefs.screenTime) { saveLater.stop(); days = {}; }
    function clear() { days = {}; file.setText("{}"); }
    Component.onDestruction: if (saveLater.running) file.setText(JSON.stringify(st.days))
}
