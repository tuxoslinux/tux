import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// System manager (Ctrl + Shift + Esc; mockups apps/03-05): overview,
// processes (right click: details, open location, pause, end, kill), CPU
// (graph per thread), memory, disks, network (speed test), GPU, dinit
// services, startup apps. Values the hardware does not report show "-".
AppWindow {
    id: app
    appName: "System manager"
    appIcon: 0xf04c5
    searchable: page === "processes"
    searchHint: "Search processes"
    property string page: Quickshell.env("TUXOS_PAGE") || "overview"
    IpcHandler { target: "monitor"; function page(id: string): void { app.page = id; } }

    Stats { id: stats }
    // static facts, read once
    property var info: ({})
    Cmd {
        command: ["sh", "-c", "echo \"CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //; s/(R)//g; s/(TM)//g; s/ CPU//')\"; echo \"THREADS=$(nproc)\"; echo \"CORES=$(lscpu -p=CORE 2>/dev/null | grep -v '^#' | sort -u | wc -l)\"; echo \"LEVEL=$(tuxos-tune cpu 2>/dev/null | head -1)\"; echo \"GPU=$(lspci 2>/dev/null | grep -i -m1 -E 'vga|3d|display' | sed 's/.*: //; s/ (rev.*//')\"; echo \"RAMTYPE=$(cat /var/cache/tuxos/ram-type 2>/dev/null)\"; for d in /sys/block/*; do n=${d##*/}; case $n in loop*|ram*|zram*|dm-*|sr*) continue;; esac; echo \"DISK=$n|$(cat $d/device/model 2>/dev/null | sed 's/ *$//')|$(cat $d/queue/rotational)|$(readlink -f $d | grep -o -E 'nvme|usb|mmc|virtio|ata' | head -1)|$(( $(cat $d/size) * 512 ))\"; done; for i in /sys/class/net/*; do n=${i##*/}; [ $n = lo ] && continue; echo \"NET=$n|$(cat $i/speed 2>/dev/null)|$([ -d $i/wireless ] && echo wifi || echo wired)\"; done"]
        Component.onCompleted: run()
        onDone: out => {
            const i = { disks: [], nets: [] };
            for (const l of out.split("\n")) {
                const k = l.indexOf("="); if (k < 0) continue;
                const key = l.slice(0, k), v = l.slice(k + 1);
                if (key === "DISK") { const p = v.split("|"); i.disks.push({ name: p[0], model: p[1] || p[0], rota: p[2] === "1", bus: p[3], size: +p[4] }); }
                else if (key === "NET") { const p = v.split("|"); i.nets.push({ name: p[0], speed: +p[1] > 0 ? +p[1] : 0, kind: p[2] }); }
                else i[key] = v;
            }
            app.info = i;
        }
    }
    function diskKind(d) {
        if (d.bus === "nvme") return "NVMe SSD";
        if (d.bus === "usb") return "USB drive";
        if (d.bus === "mmc") return d.name.startsWith("mmcblk0") ? "eMMC" : "microSD";
        if (d.bus === "virtio") return "Virtual disk";
        return d.rota ? "Hard disk (HDD)" : "SATA SSD";
    }
    function diskMax(d) { return d.bus === "virtio" ? "-" : d.bus === "nvme" ? "PCIe link up to ~7.9 GB/s (4.0 x4)" : d.bus === "usb" ? "USB: up to 10 Gbit/s (USB 3.2)" : d.rota ? "SATA III: 600 MB/s link · ~200 MB/s disk" : d.bus === "virtio" ? "-" : "SATA III: 600 MB/s"; }

    // ---- sidebar
    // the list scrolls on short screens
    Flickable {
        width: 250; height: parent.height
        contentHeight: side.height + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
    Column {
        id: side
        x: 12; y: 12; width: 226
        spacing: 4
        Repeater {
            model: [["overview", "Overview", 0xf056e], ["processes", "Processes", 0xf0279], ["cpu", "CPU", 0xf0ee0], ["memory", "Memory", 0xf035b],
                    ["disks", "Disks", 0xf02ca], ["network", "Network", 0xf05a9], ["gpu", "GPU", 0xf0379], ["", "TuxOS", 0], ["services", "Services", 0xf0493], ["startup", "Startup apps", 0xf0463],
                    ["screentime", "Screen time", 0xf051b], ["games", "Games", 0xf0297], ["battery", "Battery", 0xf0079], ["cleanup", "Cleanup", 0xf00e2]]
            delegate: Item {
                required property var modelData
                width: side.width; height: modelData[0] === "" ? 34 : 38
                Text { visible: modelData[0] === ""; x: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: Tr.t("TUXOS"); font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
                Rectangle {
                    visible: modelData[0] !== ""
                    anchors.fill: parent; radius: 11
                    color: app.page === modelData[0] ? Theme.accentFill : (sh.hovered ? Theme.fill : "transparent")
                    border.width: app.page === modelData[0] ? 1 : 0; border.color: Theme.accentLine
                    Row { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 12
                        Text { width: 18; text: String.fromCodePoint(modelData[2] || 32); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: app.page === modelData[0] ? Theme.accent : Theme.muted }
                        Text { text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text } }
                    HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: app.page = modelData[0] }
                }
            }
        }
    }
    }
    Rectangle { x: 250; width: 1; height: parent.height; color: Theme.glassLine }

    Flickable {
        anchors { left: parent.left; leftMargin: 252; right: parent.right; top: parent.top; bottom: parent.bottom }
        contentHeight: pages.implicitHeight + 56
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Loader {
            id: pages
            x: 28; y: 24
            width: parent.width - 56
            source: ({ overview: "MonOverview.qml", processes: "MonProcesses.qml", cpu: "MonCpu.qml", memory: "MonMemory.qml", disks: "MonDisks.qml",
                       network: "MonNetwork.qml", gpu: "MonGpu.qml", services: "MonServices.qml", startup: "MonStartup.qml",
                       screentime: "MonScreenTime.qml", games: "MonGames.qml", battery: "MonBattery.qml", cleanup: "MonCleanup.qml" })[app.page] || "MonOverview.qml"
        }
    }
}
