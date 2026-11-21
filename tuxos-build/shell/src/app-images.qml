//@ pragma UseQApplication
//@ pragma AppId tuxos-images
import QtQuick
import Quickshell
import qs.apps.images

// TuxOS Image viewer, started by `tuxos-app images --page FILE` (or
// --page edit:FILE to open the editor at once, as screenshots do).
ShellRoot {
    Viewer {}
}
