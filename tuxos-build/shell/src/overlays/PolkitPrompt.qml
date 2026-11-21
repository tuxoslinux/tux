import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.theme
import qs.components
import qs.services
import qs.lock

// Administrator password (polkit) in the shell's style (mockup
// shell2/06-polkit): who asks and for what, the action, the password field
// with the same feedback as the lock screen, Esc cancels. The shell is the
// session's polkit agent (no separate agent process).
Scope {
    id: pk
    PolkitAgent {
        id: polkitAgent
        onAuthenticationRequestStarted: { win.used = true; Shell.showOverlay("polkit"); }
    }
    // the window exists only from the first request on
    LazyLoader {
        id: win
        property bool used: false
        active: used
        PolkitWindow { agent: polkitAgent }
    }
}
