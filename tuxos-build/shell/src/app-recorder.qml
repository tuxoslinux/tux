//@ pragma UseQApplication
//@ pragma AppId tuxos-recorder
import QtQuick
import Quickshell
import qs.apps.recorder

// TuxOS Sound recorder, started by `tuxos-app recorder`.
ShellRoot {
    Recorder {}
}
