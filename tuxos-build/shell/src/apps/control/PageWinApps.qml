import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components

// Apps for Windows (SPEC round 6 #18): .exe files run with Proton
// (umu-launcher), each in its own Windows folder; Proton version, a
// launcher shortcut, remove. tuxos-winapp does the work.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Apps for Windows"); description: Tr.t("Open an .exe from Files and TuxOS offers to run it with Proton, each program in its own Windows folder.") }
    property bool hasUmu: true
    property var list: []
    Cmd { id: umu; command: ["sh", "-c", "command -v umu-run >/dev/null && echo yes"]; Component.onCompleted: run(); onDone: out => page.hasUmu = out.trim() === "yes" }
    Cmd {
        id: ls
        command: ["tuxos-winapp", "list"]
        Component.onCompleted: run()
        onDone: out => page.list = out.split("\n").filter(x => x).map(l => { const p = l.split("|"); return { id: p[0], name: p[1], exe: p[2], proton: p[3] || "GE-Proton", shortcut: p[4] === "1" }; })
    }
    Timer { id: again; interval: 500; onTriggered: { ls.run(); umu.run(); } }
    function act(args) { Quickshell.execDetached(["tuxos-winapp"].concat(args)); again.restart(); }
    property bool installing: false
    property string armed: ""
    Timer { id: disarm; interval: 4000; onTriggered: page.armed = "" }
    Process {
        id: install
        command: ["pkexec", "tuxos-pkg", "install", "umu-launcher"]
        onExited: { page.installing = false; again.restart(); }
    }

    SettingCard {
        visible: !page.hasUmu
        SettingRow {
            title: Tr.t("Proton for Windows programs"); description: Tr.t("umu-launcher runs them; Proton itself comes the first time a program starts"); last: true
            Btn { text: page.installing ? Tr.t("Installing...") : Tr.t("Install"); primary: true; enabled2: !page.installing; onClicked: { page.installing = true; install.running = true; } }
        }
    }
    EmptyState {
        visible: page.list.length === 0
        width: parent.width
        title: Tr.t("No Windows programs yet")
        hint: Tr.t("Open an .exe or .msi in Files to add one")
    }
    Repeater {
        model: page.list
        delegate: SettingCard {
            required property var modelData
            width: page.width
            SettingRow {
                title: modelData.name; description: modelData.exe.replace(Quickshell.env("HOME"), "~")
                Btn { text: Tr.t("Run"); primary: true; onClicked: Quickshell.execDetached(["tuxos-winapp", "start", modelData.id]) }
            }
            SettingRow {
                title: Tr.t("Proton"); description: Tr.t("GE-Proton suits most programs and games; UMU-Proton is Valve's")
                Segmented { width: 260; options: ["GE-Proton", "UMU-Proton"]; current: modelData.proton === "UMU-Proton" ? 1 : 0; onPicked: i => page.act(["proton", modelData.id, i ? "UMU-Proton" : "GE-Proton"]) }
            }
            SettingRow {
                title: Tr.t("In the app launcher")
                Toggle { checked: modelData.shortcut; onToggled: v => page.act(["shortcut", modelData.id, v ? "on" : "off"]) }
            }
            SettingRow {
                title: Tr.t("Remove"); description: Tr.t("Deletes its Windows folder (settings and saves inside it), not the .exe"); last: true
                // a second click removes it (its saves go with it)
                Btn { text: page.armed === modelData.id ? Tr.t("Click again to remove") : Tr.t("Remove"); danger: true
                      onClicked: { if (page.armed === modelData.id) { page.armed = ""; page.act(["remove", modelData.id]); } else { page.armed = modelData.id; disarm.restart(); } } }
            }
        }
    }
}
