//@ pragma UseQApplication
//@ pragma AppId tuxos-sharepicker
import QtQuick
import Quickshell
import qs.apps.sharepicker

// TuxOS screen-share picker, started by xdg-desktop-portal-hyprland through
// tuxos-sharepicker when an app wants to share the screen or a window.
ShellRoot {
    SharePicker {}
}
