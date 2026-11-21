//@ pragma UseQApplication
//@ pragma AppId tuxos-store
import QtQuick
import Quickshell
import qs.apps.store

// TuxOS Store and updates, started by `tuxos-app store [--page updates]`.
ShellRoot {
    Store {}
}
