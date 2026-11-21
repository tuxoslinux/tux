import QtQuick
import Quickshell
import Quickshell.Io

// An app's running job as a live activity in the bar (SPEC "Live
// activities": file copies, USB writes): written to
// $XDG_RUNTIME_DIR/tuxos-activities/<key>.json while `active`, removed after.
// ActivityFile { key: "files"; active: busy; title: "Copying 3 items"; progress: -1 }
Item {
    id: af
    property string key: ""
    property bool active: false
    property string title: ""
    property string sub: ""
    property real progress: -1              // 0..1, or -1: no estimate
    property string rightText: ""
    property int icon: 0
    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tuxos-activities"
    FileView { id: f; path: af.dir + "/" + af.key + ".json"; printErrors: false }
    Timer { id: later; interval: 400; onTriggered: af.write() }
    function write() {
        if (!active || !key) return;
        Quickshell.execDetached(["mkdir", "-p", dir]);
        f.setText(JSON.stringify({ title: title, sub: sub, progress: progress, right: rightText, icon: icon, at: Date.now() }));
    }
    onActiveChanged: if (active) later.restart(); else if (key) Quickshell.execDetached(["rm", "-f", dir + "/" + key + ".json"])
    onTitleChanged: if (active) later.restart()
    onProgressChanged: if (active && !later.running) later.restart()
    onRightTextChanged: if (active && !later.running) later.restart()
    Component.onDestruction: if (key) Quickshell.execDetached(["rm", "-f", dir + "/" + key + ".json"])
}
