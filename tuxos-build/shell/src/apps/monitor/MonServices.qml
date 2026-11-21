import QtQuick
import Quickshell
import qs.theme
import qs.components

// dinit services (TuxOS uses dinit, not systemd). Yours (sound, D-Bus) can
// be started / stopped directly; the system's need the admin password.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Services"); description: Tr.t("Background services, managed by dinit.") }
    function parse(out) {
        return out.split("\n").map(l => /^\[(.*)\]\s+(\S+)(?:\s+\(pid: (\d+)\))?/.exec(l)).filter(m => m && m[2] !== "boot")
                  .map(m => ({ name: m[2], up: /[{\[]\+[}\]]/.test(m[1]), pid: m[3] || "" }));
    }
    property var mine: []
    property var system: []
    property bool systemKnown: false
    Cmd { id: user; command: ["dinitctl", "list"]; Component.onCompleted: run(); onDone: out => page.mine = page.parse(out) }
    Cmd { id: enabled; command: ["sh", "-c", "ls /etc/dinit.d/boot.d 2>/dev/null"]; Component.onCompleted: run()
          onDone: out => { if (!page.systemKnown) page.system = out.split("\n").filter(x => x).map(n => ({ name: n, up: undefined, pid: "" })); } }
    Cmd { id: sys; command: ["pkexec", "dinitctl", "--system", "list"]; onDone: (out, code) => { if (code === 0) { page.system = page.parse(out); page.systemKnown = true; } } }
    function act(s, verb, system) { Quickshell.execDetached(system ? ["sh", "-c", "pkexec \"$@\" || exit 1", "sh", "dinitctl", "--system", verb, s.name] : ["dinitctl", verb, s.name]); again.restart(); }
    Timer { id: again; interval: 2000; onTriggered: { user.run(); if (page.systemKnown) sys.run(); } }

    SettingCard {
        header: Tr.t("Yours")
        Repeater {
            model: page.mine
            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.name; description: modelData.up ? "Running" + (modelData.pid ? " · PID " + modelData.pid : "") : "Stopped"; last: index === page.mine.length - 1
                Row { spacing: 8
                    Btn { text: Tr.t("Restart"); visible: modelData.up; onClicked: page.act(modelData, "restart", false) }
                    Btn { text: modelData.up ? "Stop" : "Start"; primary: !modelData.up; onClicked: page.act(modelData, modelData.up ? "stop" : "start", false) } }
            }
        }
    }
    SettingCard {
        header: Tr.t("System")
        SettingRow {
            visible: !page.systemKnown
            title: Tr.t("Started at boot: ") + page.system.length + " services"; description: Tr.t("Reading their state needs the admin password")
            Btn { text: Tr.t("Show state"); primary: true; onClicked: sys.run() }
        }
        Repeater {
            model: page.system
            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.name; last: index === page.system.length - 1
                description: modelData.up === undefined ? "Starts at boot" : (modelData.up ? "Running" + (modelData.pid ? " · PID " + modelData.pid : "") : "Stopped")
                Row { spacing: 8; visible: modelData.up !== undefined
                    Btn { text: Tr.t("Restart"); visible: modelData.up === true; onClicked: page.act(modelData, "restart", true) }
                    Btn { text: modelData.up ? "Stop" : "Start"; primary: !modelData.up; onClicked: page.act(modelData, modelData.up ? "stop" : "start", true) } }
            }
        }
    }
}
