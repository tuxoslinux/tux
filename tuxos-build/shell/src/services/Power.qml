pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Session actions (power menu, launcher commands, login / lock buttons).
// elogind's loginctl works for the user's own seat through polkit.
Singleton {
    id: power

    // set by the lock screen; the power menu and Super + L use it
    property bool locked: false
    signal lockRequested()

    function lock() { lockRequested(); }
    function logout() { Session.save(); Gpu.markClean(); Shell.dispatch("hl.dsp.exit()", "exit"); }
    function suspend() { lockRequested(); Quickshell.execDetached(["sh", "-c", "sleep 0.6; loginctl suspend"]); }
    function reboot() { Session.save(); Gpu.markClean(); Quickshell.execDetached(["loginctl", "reboot"]); }
    function poweroff() { Session.save(); Gpu.markClean(); Quickshell.execDetached(["loginctl", "poweroff"]); }
    // greetd runs one session at a time: switching user locks this session
    // (its apps keep running); the other user logs in after this one logs out
    function switchUser() { lockRequested(); }
    // GRUB shows its menu once on the next start (tuxos-tune needs root)
    function rebootToMenu() { Quickshell.execDetached(["sh", "-c", "pkexec tuxos-tune bootmenu && loginctl reboot"]); }
}
