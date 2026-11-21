pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// RGB lighting follows the accent (SPEC round 5 #3): keyboard, mouse,
// headset and case lighting take the accent colour through OpenRGB (its
// server is started when this is on, so each change is quick); dark while
// the screen is locked or the PC sleeps. Off by default (Settings >
// Appearance).
Singleton {
    id: rgb
    readonly property bool on: Prefs.rgbAccent && !Shell.live
    readonly property string colour: Power.locked ? "000000" : Theme.accent.toString().replace("#", "").slice(-6)
    Process { id: server; running: rgb.on; command: ["openrgb", "--server", "--noautoconnect"] }
    Timer { id: later; interval: 1200; onTriggered: rgb.send() }
    onColourChanged: if (on) later.restart()
    onOnChanged: if (on) later.restart(); else Quickshell.execDetached(["openrgb", "-c", "000000"])
    function send() { if (on) Quickshell.execDetached(["openrgb", "-c", colour]); }
}
