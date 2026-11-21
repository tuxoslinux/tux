//@ pragma UseQApplication
//@ pragma AppId tuxos-monitor
import QtQuick
import Quickshell
import qs.apps.monitor

// TuxOS System manager, started by `tuxos-app monitor` (Ctrl + Shift + Esc).
ShellRoot {
    Monitor {}
}
