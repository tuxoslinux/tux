import QtQuick
import qs.theme
import qs.components

// CPU (mockup apps/03-sysmon): name, threads, ISA level; usage, speed,
// temperature, power, voltage; one graph for all, one per thread.
Column {
    spacing: 16
    Item {
        width: parent.width; height: 60
        Column {
            Text { text: app.info.CPU || "Processor"; font.family: Theme.font; font.pixelSize: Theme.px(26); font.weight: Font.Bold; color: Theme.text }
            Text { text: `${app.info.CORES || "-"} cores, ${app.info.THREADS || "-"} threads` + (app.info.LEVEL ? " · " + app.info.LEVEL + " packages" : ""); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
        }
        Row {
            anchors.right: parent.right
            spacing: 32
            StatTile { label: Tr.t("Usage"); value: Math.round(stats.cpu) + " %" }
            StatTile { label: Tr.t("Speed"); value: stats.mhz ? (stats.mhz / 1000).toFixed(2) + " GHz" : "-" }
            StatTile { label: Tr.t("Temperature"); value: stats.temp >= 0 ? stats.temp + " °C" : "-" }
            StatTile { label: Tr.t("Power"); value: "-" }
            StatTile { label: Tr.t("Voltage"); value: "-" }
        }
    }
    GraphCard { title: Tr.t("All cores"); values: stats.cpuHist }
    Text { text: Tr.t("PER CORE"); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
    Flow {
        width: parent.width
        spacing: 8
        Repeater {
            model: stats.cores.length
            delegate: Rectangle {
                required property int index
                width: (parent.width - 60) / 7; height: 64; radius: 12
                color: Theme.ink(0.035); border.width: 1; border.color: Theme.glassLine
                Text { x: 8; y: 8; text: Tr.t("CPU ") + index; font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.muted }
                Text { anchors { right: parent.right; rightMargin: 8; top: parent.top; topMargin: 8 } text: Math.round(stats.cores[index] || 0) + "%"; font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; color: Theme.text }
                Graph { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 } height: 30; values: stats.coreHist[index] || [] }
            }
        }
    }
}
