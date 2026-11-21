pragma Singleton

import QtQuick
import Quickshell

// Optional UI sounds (off by default; Settings > Notifications): unlock,
// notification, screenshot. Freedesktop sound theme through PipeWire.
Singleton {
    function play(name) {
        if (!Prefs.uiSounds) return;
        const file = { unlock: "service-login", notification: "message", screenshot: "camera-shutter", plug: "device-added", unplug: "device-removed" }[name] || name;
        Quickshell.execDetached(["sh", "-c", "pw-play \"/usr/share/sounds/freedesktop/stereo/$1.oga\" 2>/dev/null", "sh", file]);
    }
}
