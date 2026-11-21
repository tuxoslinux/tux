pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Search inside files (tuxos-index): the index is brought up to date when
// the PC has been idle for 3 minutes (at most every 30 minutes), at the
// lowest CPU and disk priority, never while a game runs or on a low
// battery; a game starting stops it. Settings > Privacy turns it off.
Singleton {
    id: ix
    readonly property bool on: Prefs.fileIndex && !Shell.live
    property double lastBuild: 0
    IdleMonitor {
        id: idle
        enabled: ix.on
        timeout: 180
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) ix.maybeBuild()
    }
    function maybeBuild() {
        if (!on || build.running || Notifs.gameRunning) return;
        if (SmartPower.onBattery && SmartPower.pct < 30) return;
        if (Date.now() - lastBuild < 1800000) return;
        lastBuild = Date.now();
        build.running = true;
    }
    function now() { lastBuild = 0; maybeBuild(); }
    Process {
        id: build
        command: ["nice", "-n", "19", "ionice", "-c", "3", "tuxos-index", "build"]
    }
    Connections { target: Notifs; function onGameRunningChanged() { if (Notifs.gameRunning && build.running) build.signal(15); } }
}
