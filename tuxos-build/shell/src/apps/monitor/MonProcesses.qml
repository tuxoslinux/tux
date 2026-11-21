import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// Processes (mockup apps/05-procs): Apps (things with a desktop entry) or
// all processes; CPU, memory; sort by a column; search in the title bar.
// Right click: details, open file location, pause / resume, end task,
// kill (force). Other users' processes ask for the admin password.
Column {
    id: page
    spacing: 16
    property bool appsOnly: true
    property string sortBy: "cpu"
    property var procs: []
    property var menuFor: null
    property real menuY: 0
    property var details: null
    readonly property string me: Quickshell.env("USER") || Quickshell.env("LOGNAME")

    Process {
        id: ps
        command: ["ps", "-eo", "pid=,ppid=,user:20=,pcpu=,rss=,stat=,comm="]
        stdout: StdioCollector {
            onStreamFinished: {
                page.procs = text.split("\n").filter(l => l.trim()).map(l => {
                    const p = l.trim().split(/\s+/);
                    return { pid: +p[0], ppid: +p[1], user: p[2], cpu: +p[3], rss: +p[4] * 1024, stopped: p[5].indexOf("T") !== -1, name: p.slice(6).join(" ") };
                }).filter(p => p.name !== "ps");
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { Hyprland.refreshToplevels(); if (!ps.running) ps.running = true; } }

    // apps: group processes by desktop entry (an app's helpers count with it)
    readonly property var rows: {
        const q = app.search.trim().toLowerCase();
        void DesktopEntries.applications.values;   // again once the app list has loaded
        let list;
        if (appsOnly) {
            const g = {};
            // windows tell which app a process is (Mousepad runs as "mousepad" but is org.xfce.mousepad)
            const byPid = {};
            for (const h of Hyprland.toplevels.values) { const o = h.lastIpcObject || {}; if (o.pid) byPid[o.pid] = o.class; }
            for (const p of procs) {
                if (p.user !== me) continue;
                const e = (byPid[p.pid] ? DesktopEntries.heuristicLookup(byPid[p.pid]) : null) || DesktopEntries.heuristicLookup(p.name);
                if (!e || e.noDisplay) continue;
                const k = e.id;
                if (!g[k]) g[k] = { pid: p.pid, name: e.name, entry: e, cpu: 0, rss: 0, user: p.user, stopped: p.stopped, pids: [] };
                g[k].cpu += p.cpu; g[k].rss += p.rss; g[k].pids.push(p.pid);
            }
            list = Object.values(g);
        } else list = procs.map(p => Object.assign({ pids: [p.pid] }, p));
        if (q) list = list.filter(r => r.name.toLowerCase().indexOf(q) !== -1 || String(r.pid) === q);
        const key = sortBy;
        list.sort((a, b) => key === "name" ? a.name.localeCompare(b.name) : (b[key] - a[key]));
        return list.slice(0, 150);
    }
    function signal(r, sig) {
        const own = r.user === me;
        const cmd = ["kill", "-" + sig].concat(r.pids.map(String));
        Quickshell.execDetached(own ? cmd : ["sh", "-c", "pkexec \"$@\" || exit 1", "sh"].concat(cmd));
        later.restart();
    }
    Timer { id: later; interval: 400; onTriggered: ps.running = true }

    Item {
        width: parent.width; height: 40
        Text { text: Tr.t("Processes"); font.family: Theme.font; font.pixelSize: Theme.px(26); font.weight: Font.Bold; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Segmented { anchors.right: parent.right; width: 240; options: ["Apps", "All processes"]; current: page.appsOnly ? 0 : 1; onPicked: i => page.appsOnly = i === 0 }
    }
    Rectangle {
        width: parent.width
        height: list.height + 50
        radius: 20
        color: Theme.ink(0.035); border.width: 1; border.color: Theme.glassLine
        Row {
            x: 20; y: 12
            Repeater {
                model: [["name", "NAME", 0.5], ["cpu", "CPU %", 0.17], ["rss", "MEMORY", 0.17], ["pid", "PID", 0.16]]
                delegate: Text {
                    required property var modelData
                    width: (page.width - 40) * modelData[2]
                    text: modelData[1] + (page.sortBy === modelData[0] ? "  ↓" : "")
                    font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; font.letterSpacing: 1.1
                    color: page.sortBy === modelData[0] ? Theme.accent : Theme.muted
                    TapHandler { onTapped: page.sortBy = modelData[0] }
                }
            }
        }
        Column {
            id: list
            x: 4; y: 40
            width: parent.width - 12
            Repeater {
                model: page.rows
                delegate: Rectangle {
                    required property var modelData
                    width: list.width; height: 46; radius: 12
                    color: page.menuFor && page.menuFor.pid === modelData.pid ? Theme.accentFill : (rh.hovered ? Theme.fill : "transparent")
                    Row {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        Row {
                            width: (page.width - 40) * 0.5; spacing: 12
                            AppTile { size: 28; entry: modelData.entry || null; appId: modelData.name; anchors.verticalCenter: parent.verticalCenter }
                            Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60; elide: Text.ElideRight; text: modelData.name + (modelData.stopped ? "  (paused)" : "") + (modelData.pids.length > 1 ? "  · " + modelData.pids.length : ""); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                        }
                        Text { width: (page.width - 40) * 0.17; text: modelData.cpu.toFixed(1); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                        Text { width: (page.width - 40) * 0.17; text: stats.bytes(modelData.rss); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                        Text { width: (page.width - 40) * 0.16; text: modelData.pid; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                    }
                    HoverHandler { id: rh }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton | Qt.LeftButton
                        onClicked: mouse => { page.menuFor = mouse.button === Qt.RightButton ? modelData : null; page.menuY = parent.y + list.y + 40; page.details = null; }
                    }
                }
            }
        }
        // right-click menu
        Rectangle {
            visible: page.menuFor !== null
            x: parent.width * 0.32; y: page.menuY
            width: 230; height: menuCol.implicitHeight + 12; radius: 14
            color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
            z: 10
            Column {
                id: menuCol
                anchors { fill: parent; margins: 4 }
                MenuRow { label: Tr.t("Details"); icon: 0xf02fc; onHit: { page.details = page.menuFor; page.menuFor = null; detailsCmd.run(); } }
                MenuRow { label: Tr.t("Open file location"); icon: 0xf024b; onHit: { Quickshell.execDetached(["sh", "-c", "gio open \"$(dirname \"$(readlink /proc/$1/exe)\")\"", "sh", String(page.menuFor.pid)]); page.menuFor = null; } }
                MenuRow { label: page.menuFor && page.menuFor.stopped ? "Resume" : "Pause"; icon: page.menuFor && page.menuFor.stopped ? 0xf040a : 0xf03e4; onHit: { page.signal(page.menuFor, page.menuFor.stopped ? "CONT" : "STOP"); page.menuFor = null; } }
                MenuRow { label: Tr.t("End task"); icon: 0xf0156; onHit: { page.signal(page.menuFor, "TERM"); page.menuFor = null; } }
                MenuRow { label: Tr.t("Kill (force)"); icon: 0xf0bc8; danger: true; onHit: { page.signal(page.menuFor, "KILL"); page.menuFor = null; } }
            }
        }
    }
    // details of one process
    Cmd {
        id: detailsCmd
        command: ["sh", "-c", "p=$1; echo \"Program: $(readlink /proc/$p/exe)\"; echo \"Command: $(tr '\\0' ' ' < /proc/$p/cmdline)\"; echo \"Started: $(ps -o lstart= -p $p)\"; echo \"Threads: $(ls /proc/$p/task | wc -l)\"; echo \"Open files: $(ls /proc/$p/fd 2>/dev/null | wc -l)\"", "sh", page.details ? String(page.details.pid) : "0"]
    }
    Rectangle {
        visible: page.details !== null
        width: parent.width; height: dt.implicitHeight + 40; radius: 18
        color: Theme.ink(0.035); border.width: 1; border.color: Theme.glassLine
        Text { id: dt; x: 20; y: 20; width: parent.width - 40; wrapMode: Text.WrapAnywhere; text: (page.details ? page.details.name + " · PID " + page.details.pid + " · " + page.details.user + "\n" : "") + detailsCmd.out; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Theme.px(12); color: Theme.text; lineHeight: 1.3 }
    }
}
