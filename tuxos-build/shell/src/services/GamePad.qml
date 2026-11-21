pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Controller navigation (SPEC "Controller support"): tuxos-pad reads every
// gamepad; the open overlay (launcher, Mission Control, power menu,
// notifications, the Game HUD panel) moves with the D-pad / stick, A opens,
// B goes back. With nothing open: Start opens the launcher, Select Mission
// Control, the home / Steam button Steam Big Picture. Off while a game runs
// (the game has the pad) and while the screen is locked.
Singleton {
    id: pad
    readonly property bool wanted: !Notifs.gameRunning && !Power.locked && !Shell.live
    Process {
        id: proc
        running: pad.wanted
        command: ["tuxos-pad"]
        stdout: SplitParser { onRead: line => pad.press(line.trim()) }
    }
    function press(w) {
        if (!w) return;
        if (Shell.overlay !== "") { Shell.pad(w); return; }
        if (Shell.fullscreenFocused) return;                // a video / a game in a window
        if (w === "start") Shell.showOverlay("launcher");
        else if (w === "select") Shell.showOverlay("mission");
        else if (w === "home") Shell.shortcut("steam");
    }
}
