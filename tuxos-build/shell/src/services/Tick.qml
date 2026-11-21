pragma Singleton

import QtQuick
import Quickshell

// One shared wake-up a minute, on the minute: the per-minute checks (alarms,
// downloads, headset battery, low memory / disk / heat) all run from it, so
// the idle shell wakes about once a minute instead of once per timer.
Singleton {
    id: tick
    signal minute(double now)
    Timer {
        id: t
        running: true
        interval: 60000 - Date.now() % 60000 + 30
        onTriggered: {
            const now = Date.now();
            tick.minute(now);
            interval = 60000 - now % 60000 + 30;
            restart();
        }
    }
}
