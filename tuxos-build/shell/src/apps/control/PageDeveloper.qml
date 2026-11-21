import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components

// Developer (SPEC round 6 #24 developer mode, #20 Distrobox): one switch
// installs the tools (base-devel, git, Code - OSS, podman, Distrobox), git's
// name / e-mail, an SSH key; boxes with other Linux systems whose apps join
// the launcher. tuxos-dev does the work.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Developer"); description: Tr.t("Tools for programming, and apps from other Linux systems (Ubuntu, Fedora, Debian ...) in boxes.") }

    property var st: ({ tools: false, name: "", email: "", ssh: "", podman: false, distrobox: false })
    Cmd {
        id: status
        command: ["tuxos-dev", "status"]
        Component.onCompleted: run()
        onDone: out => {
            const s = { tools: false, name: "", email: "", ssh: "", podman: false, distrobox: false };
            for (const l of out.split("\n")) {
                const i = l.indexOf(" "), k = l.slice(0, i), v = l.slice(i + 1);
                if (k === "tools") s.tools = v === "1"; else if (k === "podman") s.podman = v === "1"; else if (k === "distrobox") s.distrobox = v === "1";
                else if (k === "ssh") s.ssh = v.trim(); else if (k === "git") { const p = v.split("|"); s.name = p[0] || ""; s.email = p[1] || ""; }
            }
            page.st = s;
            if (s.distrobox) boxes.run();
        }
    }
    property bool installing: false
    Process { id: tools; command: ["tuxos-dev", "tools"]; onExited: { page.installing = false; status.run(); } }
    property string sshKey: ""
    Cmd { id: ssh; command: ["tuxos-dev", "ssh"]; onDone: out => { page.sshKey = out.trim(); Quickshell.clipboardText = page.sshKey; status.run(); } }

    SettingCard {
        header: Tr.t("Developer mode")
        SettingRow {
            title: Tr.t("Developer tools"); last: true
            description: page.st.tools ? Tr.t("Installed: base-devel, git, Code - OSS, podman, Distrobox") : Tr.t("Installs base-devel, git, Code - OSS (editor), podman (containers) and Distrobox")
            Toggle { visible: !page.installing; checked: page.st.tools; onToggled: v => { if (v && !page.st.tools) { page.installing = true; tools.running = true; } } }
            Text { visible: page.installing; text: Tr.t("Installing..."); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        }
    }
    SettingCard {
        header: Tr.t("Git and SSH")
        SettingRow {
            title: Tr.t("Name for git")
            Field { id: gname; width: 260; text: page.st.name; placeholder: Tr.t("Your name") }
        }
        SettingRow {
            title: Tr.t("E-mail for git")
            Field { id: gmail; width: 260; text: page.st.email; placeholder: "you@example.com" }
        }
        SettingRow {
            title: ""; description: page.st.name ? Tr.t("Used for your commits") : ""
            Btn { text: Tr.t("Save"); enabled2: gname.text.trim() !== "" && gmail.text.indexOf("@") > 0
                  onClicked: { Quickshell.execDetached(["tuxos-dev", "git", gname.text.trim(), gmail.text.trim()]); later.restart(); } }
        }
        SettingRow {
            title: Tr.t("SSH key"); last: true
            description: page.sshKey ? Tr.t("Copied. Paste it into GitHub / GitLab > SSH keys") : (page.st.ssh ? page.st.ssh.replace(Quickshell.env("HOME"), "~") : Tr.t("None yet"))
            Btn { text: page.st.ssh ? Tr.t("Copy the public key") : Tr.t("Make one"); onClicked: ssh.run() }
        }
    }
    Timer { id: later; interval: 600; onTriggered: status.run() }

    // ---- Distrobox
    property var boxList: []
    Cmd { id: boxes; command: ["tuxos-dev", "boxes"]; onDone: out => page.boxList = out.split("\n").filter(x => x).map(l => { const p = l.split("|"); return { name: p[0], image: p[1], status: p[2] }; }) }
    readonly property var images: [["ubuntu", "Ubuntu 24.04", "quay.io/toolbx/ubuntu-toolbox:24.04"], ["fedora", "Fedora", "quay.io/fedora/fedora-toolbox:latest"],
                                   ["debian", "Debian", "quay.io/toolbx-images/debian-toolbox:12"], ["arch", "Arch Linux", "quay.io/toolbx/arch-toolbox:latest"]]
    property int imageIdx: 0
    SettingCard {
        header: Tr.t("Other Linux systems (Distrobox)")
        SettingRow {
            visible: !page.st.distrobox; last: true
            title: Tr.t("Needs the developer tools"); description: Tr.t("Turn on developer mode above")
        }
        SettingRow {
            visible: page.st.distrobox
            title: Tr.t("New box"); description: Tr.t("Downloads the system (a few hundred MB) in a terminal")
            Row {
                spacing: 10
                Segmented { width: 400; options: page.images.map(x => x[1]); current: page.imageIdx; onPicked: i => page.imageIdx = i }
                Btn { text: Tr.t("Create"); primary: true
                      onClicked: { const im = page.images[page.imageIdx]; Quickshell.execDetached(["tuxos-dev", "create", im[0], im[2]]); boxRefresh.start(); } }
            }
        }
        Repeater {
            model: page.st.distrobox ? page.boxList : []
            delegate: SettingRow {
                required property var modelData
                title: modelData.name; description: modelData.image + " · " + modelData.status
                Row {
                    spacing: 8
                    Btn { text: Tr.t("Apps..."); onClicked: { page.appsOf = modelData.name; page.boxApps = []; appsCmd.command = ["tuxos-dev", "apps", modelData.name]; appsCmd.run(); } }
                    Btn { text: Tr.t("Terminal"); onClicked: Quickshell.execDetached(["kitty", "--title", modelData.name, "distrobox", "enter", modelData.name]) }
                    Btn { text: page.armed === modelData.name ? Tr.t("Click again") : Tr.t("Delete"); danger: true
                          onClicked: { if (page.armed === modelData.name) { page.armed = ""; Quickshell.execDetached(["tuxos-dev", "remove", modelData.name]); boxRefresh.start(); } else { page.armed = modelData.name; disarm.restart(); } } }
                }
            }
        }
    }
    property string armed: ""
    Timer { id: disarm; interval: 4000; onTriggered: page.armed = "" }
    // a new box appears after its download: look a few times
    Timer { id: boxRefresh; interval: 5000; repeat: true; property int n: 0; onTriggered: { boxes.run(); if (++n > 60) { stop(); n = 0; } } }

    // the apps inside a box: on / off in the launcher
    property string appsOf: ""
    property var boxApps: []
    property var exported: ({})
    Cmd { id: appsCmd; onDone: out => page.boxApps = out.split("\n").filter(x => x).map(l => { const p = l.split("|"); return { file: p[0], name: p[1] || p[0] }; }) }
    SettingCard {
        visible: page.appsOf !== ""
        header: Tr.f("Apps in {n}", { n: page.appsOf })
        SettingRow { visible: page.boxApps.length === 0; title: appsCmd.running ? Tr.t("Looking...") : Tr.t("No apps with a window in this box yet"); description: Tr.t("Install some in its terminal (apt / dnf / pacman)"); last: true }
        Repeater {
            model: page.boxApps
            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.name; description: Tr.t("In the app launcher"); last: index === page.boxApps.length - 1
                Toggle {
                    checked: page.exported[page.appsOf + "/" + modelData.file] === true
                    onToggled: v => { const e = Object.assign({}, page.exported); e[page.appsOf + "/" + modelData.file] = v; page.exported = e;
                                      Quickshell.execDetached(["tuxos-dev", v ? "export" : "unexport", page.appsOf, modelData.file]); }
                }
            }
        }
    }
    // which box apps are in the launcher already (distrobox-export names them <box>-<app>.desktop)
    Cmd {
        id: exp
        command: ["sh", "-c", "grep -l 'distrobox enter' \"${XDG_DATA_HOME:-$HOME/.local/share}\"/applications/*.desktop 2>/dev/null | xargs -r -n1 basename"]
        Component.onCompleted: run()
        onDone: out => {
            const e = {};
            for (const f of out.split("\n").filter(x => x)) { const i = f.indexOf("-"); if (i > 0) e[f.slice(0, i) + "/" + f.slice(i + 1).replace(/\.desktop$/, "")] = true; }
            page.exported = e;
        }
    }
}
