//@ pragma UseQApplication
//@ pragma AppId tuxos-control
import QtQuick
import Quickshell
import qs.apps.control

// TuxOS Control (Settings), started by `tuxos-control` as its own small
// process with its own app id (dock symbol, window rules).
ShellRoot {
    Control {}
}
