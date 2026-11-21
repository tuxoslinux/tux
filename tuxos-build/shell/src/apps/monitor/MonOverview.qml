import QtQuick
import qs.theme
import qs.components

// Overview: CPU, memory, GPU, disk and network at a glance.
Column {
    spacing: 16
    Text { text: Tr.t("Overview"); font.family: Theme.font; font.pixelSize: Theme.px(26); font.weight: Font.Bold; color: Theme.text }
    Grid {
        columns: 2; spacing: 12
        width: parent.width
        GraphCard { width: (parent.width - 14) / 2; height: 170; title: Tr.t("CPU · ") + Math.round(stats.cpu) + " %"; note: stats.temp >= 0 ? stats.temp + " °C" : ""; values: stats.cpuHist }
        GraphCard { width: (parent.width - 14) / 2; height: 170; title: Tr.t("Memory · ") + stats.bytes(stats.memUsed * 1024); note: "of " + stats.bytes(stats.memTotal * 1024); values: stats.memHist }
        GraphCard { width: (parent.width - 14) / 2; height: 170; title: Tr.t("GPU · ") + (stats.gpu ? stats.gpu.util + " %" : "-"); note: ""; values: stats.gpuHist }
        GraphCard {
            width: (parent.width - 14) / 2; height: 170
            readonly property string disk: Object.keys(stats.diskHist).filter(k => !k.startsWith("zram"))[0] || ""
            title: Tr.t("Disk · ") + (disk && stats.disks[disk] ? stats.rate(stats.disks[disk].r + stats.disks[disk].w) : "-"); note: disk
            values: stats.diskHist[disk] || []; max: Math.max(1, ...(stats.diskHist[disk] || [1]))
        }
    }
}
