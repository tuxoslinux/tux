//@ pragma UseQApplication
//@ pragma AppId tuxos-welcome
import QtQuick
import Quickshell
import qs.apps.welcome

// TuxOS Welcome: opens once at the first login (the shell starts it).
ShellRoot {
    Welcome {}
}
