import QtQuick
import qs.theme
import qs.components

// Memory: used / cached / free, swap and zram; type and speed when known.
Column {
    spacing: 16
    Column {
        Text { text: Tr.t("Memory"); font.family: Theme.font; font.pixelSize: Theme.px(26); font.weight: Font.Bold; color: Theme.text }
        Text { text: stats.bytes(stats.memTotal * 1024) + (app.info.RAMTYPE ? " · " + app.info.RAMTYPE : " · type and speed: -"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
    }
    Row {
        spacing: 32
        StatTile { label: Tr.t("In use"); value: stats.bytes(stats.memUsed * 1024) }
        StatTile { label: Tr.t("Cached"); value: stats.bytes(stats.memCached * 1024) }
        StatTile { label: Tr.t("Free"); value: stats.bytes((stats.memTotal - stats.memUsed) * 1024) }
        StatTile { label: Tr.t("Swap / zram"); value: stats.swapTotal ? stats.bytes(stats.swapUsed * 1024) + " of " + stats.bytes(stats.swapTotal * 1024) : "-" }
    }
    GraphCard { title: Tr.t("Memory in use"); values: stats.memHist }
}
