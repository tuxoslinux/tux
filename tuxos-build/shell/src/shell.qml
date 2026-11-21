//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.desktop
import qs.greeter

// TuxOS shell entry point. The same config is the desktop shell (started by
// tuxos-shell in the Hyprland session) and the login screen (greetd starts
// it in cage with TUXOS_GREETER=1).
ShellRoot {
    readonly property bool greeter: Quickshell.env("TUXOS_GREETER") === "1"
    LazyLoader { active: greeter; Greeter {} }
    LazyLoader { active: !greeter; Desktop {} }
}
