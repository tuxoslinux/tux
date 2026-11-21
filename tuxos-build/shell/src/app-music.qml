//@ pragma UseQApplication
//@ pragma AppId tuxos-music
import QtQuick
import Quickshell
import qs.apps.music

// TuxOS Music (local files), started by `tuxos-app music` (Super + V when no
// streaming app is installed).
ShellRoot {
    Music {}
}
