import QtQuick
import Quickshell.Io

// Runs a command and keeps its output (settings pages, apps).
// Cmd { id: c; command: ["uname", "-r"]; Component.onCompleted: run() }  ->  c.out
Process {
    id: p
    property string out: ""
    property int code: -1
    signal done(string out, int code)
    function run() { if (!running) running = true; }
    stdout: StdioCollector { onStreamFinished: p.out = text }
    onExited: (c, s) => { p.code = c; Qt.callLater(() => p.done(p.out, c)); }
}
