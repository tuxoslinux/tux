import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components

// Updates & drivers: pending updates, update now, drivers in use.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Updates & drivers"); description: Tr.t("Keep TuxOS, its kernel and drivers current.") }
    property var updates: []
    Cmd { id: cu; command: ["sh", "-c", "{ checkupdates 2>/dev/null || pacman -Qu 2>/dev/null; } | grep -v '\\[ignored\\]'"]; Component.onCompleted: run(); onDone: out => page.updates = out.split("\n").filter(x => x) }
    Cmd { id: dr; command: ["sh", "-c", "tuxos-drivers --list 2>&1 | head -24"]; Component.onCompleted: run() }
    SettingCard {
        SettingRow {
            title: cu.running ? "Checking..." : (page.updates.length ? page.updates.length + " updates ready" : "TuxOS is up to date")
            description: page.updates.slice(0, 4).map(l => l.split(" ")[0]).join(" · ")
            last: true
            Row { spacing: 8
                Btn { text: Tr.t("Check again"); onClicked: cu.run() }
                // the same update as the Store: versions before are recorded for Undo
                Btn { text: Tr.t("Update now"); primary: true; enabled2: page.updates.length > 0; onClicked: Quickshell.execDetached(["kitty", "--title", "TuxOS update", "sh", "-c", "pkexec tuxos-pkg update; command -v flatpak >/dev/null && flatpak update --user -y; echo; read -p 'Done. Enter closes.' x"]) } }
        }
    }
    SettingCard {
        header: Tr.t("Updates")
        visible: page.updates.length > 0
        Repeater {
            model: page.updates.slice(0, 30)
            delegate: SettingRow { required property string modelData; title: modelData.split(" ")[0]; description: modelData.split(" ").slice(1).join(" ") }
        }
    }
    // ---- what was updated lately, each with Undo (kernel and drivers too)
    property var recent: []
    Cmd { id: rc; command: ["tuxos-pkg", "recent", "60"]; Component.onCompleted: run()
          onDone: out => page.recent = out.split("\n").filter(x => x).map(l => { const f = l.split(" "); return { date: f[0], name: f[1], old: f[2], now: f[3] }; }) }
    function kind(n) { return /^linux(-cachyos)?(-lts|-zen)?(-headers)?$/.test(n) ? "Kernel" : /^(mesa|lib32-mesa|vulkan-|lib32-vulkan-|nvidia|lib32-nvidia|xf86-video)/.test(n) ? "Driver" : ""; }
    SettingCard {
        header: Tr.t("Recently updated")
        visible: page.recent.length > 0
        Repeater {
            model: page.recent.slice(0, 25)
            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.name + (page.kind(modelData.name) ? "  ·  " + Tr.t(page.kind(modelData.name)) : "")
                description: `${modelData.old.replace(/^\d+:/, "")} → ${modelData.now.replace(/^\d+:/, "")}  ·  ${Tr.date(new Date(modelData.date), "d MMM")}`
                last: index === Math.min(25, page.recent.length) - 1
                Btn { text: Tr.t("Undo"); onClicked: Quickshell.execDetached(["sh", "-c", "pkexec tuxos-pkg undo \"$1\" && notify-send 'Update undone' \"$1 is back to the version before\" || notify-send 'Could not undo' \"$1: the version before is not in the package cache any more\"", "sh", modelData.name]) }
            }
        }
    }
    // fastest mirrors (SPEC round 7 #18): ranked monthly by themselves; by hand here
    property var mirrors: ({ last: 0, first: "" })
    Cmd {
        id: ms
        command: ["sh", "-c", "command -v tuxos-mirrors >/dev/null && tuxos-mirrors status"]
        Component.onCompleted: run()
        onDone: out => { const m = { last: 0, first: "" }; for (const l of out.split("\n")) { const p = l.split(" "); if (p[0] === "last") m.last = +p[1]; else if (p[0] === "mirrorlist") m.first = (p[1] || "").replace(/^https?:\/\//, "").split("/")[0]; } page.mirrors = m; }
    }
    property bool ranking: false
    Process { id: rank; command: ["pkexec", "tuxos-mirrors"]; onExited: { page.ranking = false; ms.run(); } }
    SettingCard {
        header: Tr.t("Download speed")
        SettingRow {
            title: Tr.t("Fastest mirrors")
            description: page.ranking ? Tr.t("Measuring the mirrors... (about a minute)")
                       : page.mirrors.last > 0 ? Tr.f("Ranked {d} · fastest now: {m}", { d: Qt.formatDate(new Date(page.mirrors.last * 1000), "d MMM"), m: page.mirrors.first })
                       : Tr.t("Ranked by speed once a month, by itself")
            last: true
            Btn { text: page.ranking ? Tr.t("Measuring...") : Tr.t("Find them now"); enabled2: !page.ranking; onClicked: { page.ranking = true; rank.running = true; } }
        }
    }
    SettingCard {
        header: Tr.t("Drivers")
        Rectangle { width: parent.width; height: drv.implicitHeight + 32; color: "transparent"
            Text { id: drv; x: 24; y: 16; width: parent.width - 48; text: dr.out || "Reading..."; wrapMode: Text.Wrap; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Theme.px(12); color: Theme.muted } }
    }
}
