import QtQuick
import qs.theme
import qs.components

// Disks: kind (NVMe / SATA SSD / HDD / USB / microSD / eMMC), model, size,
// live read / write, the connection's maximum (drives do not report a
// rated speed).
Column {
    spacing: 16
    Text { text: Tr.t("Disks"); font.family: Theme.font; font.pixelSize: Theme.px(26); font.weight: Font.Bold; color: Theme.text }
    Repeater {
        model: app.info.disks || []
        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 8
            readonly property var io: stats.disks[modelData.name] || ({ r: 0, w: 0 })
            Item {
                width: parent.width; height: 46
                Column {
                    Text { text: modelData.model; font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: app.diskKind(modelData) + " · " + stats.bytes(modelData.size) + " · " + modelData.name; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                }
                Row {
                    anchors.right: parent.right; spacing: 28
                    StatTile { label: Tr.t("Read"); value: stats.rate(parent.parent.parent.io.r) }
                    StatTile { label: Tr.t("Write"); value: stats.rate(parent.parent.parent.io.w) }
                    StatTile { label: Tr.t("Link maximum"); value: app.diskMax(modelData) === "-" ? "-" : app.diskMax(modelData).split(":")[1] || app.diskMax(modelData) }
                }
            }
            GraphCard { title: Tr.t("Read + write (MB/s)"); values: stats.diskHist[modelData.name] || []; max: Math.max(1, ...(stats.diskHist[modelData.name] || [1])); height: 150 }
        }
    }
}
