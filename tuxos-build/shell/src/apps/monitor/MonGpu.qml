import QtQuick
import qs.theme
import qs.components

// GPU: model, utilisation graph, VRAM, temperature, clock, fan, power where
// the driver reports them; TOPS from TuxOS' table of published figures.
Column {
    spacing: 16
    readonly property var g: stats.gpu
    readonly property var tops: ({ "4090": 1321, "4080": 780, "4070 Ti": 641, "4070": 466, "4060 Ti": 353, "4060": 242, "5090": 3352, "5080": 1801, "5070 Ti": 1406, "5070": 988,
                                   "3090": 285, "3080": 238, "3070": 163, "3060": 102, "7900 XTX": 123, "7900 XT": 103, "7800 XT": 74, "7600": 43, "9070 XT": 389, "9070": 289 })
    readonly property string topsText: { for (const k in tops) if ((app.info.GPU || "").indexOf(k) !== -1) return tops[k] + " TOPS (AI, published)"; return "-"; }
    Column {
        Text { text: app.info.GPU || "Graphics"; font.family: Theme.font; font.pixelSize: Theme.px(24); font.weight: Font.Bold; color: Theme.text; width: parent.width; elide: Text.ElideRight }
        Text { text: Tr.t("AI performance: ") + parent.parent.topsText; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
    }
    Row {
        spacing: 28
        StatTile { label: Tr.t("Usage"); value: g ? g.util + " %" : "-" }
        StatTile { label: Tr.t("VRAM"); value: g && g.vramTotal ? (g.vramUsed / 1024).toFixed(1) + " / " + (g.vramTotal / 1024).toFixed(1) + " GB" : "-" }
        StatTile { label: Tr.t("Temperature"); value: g && +g.temp > 0 ? g.temp + " °C" : "-" }
        StatTile { label: Tr.t("Clock"); value: g && +g.clock > 0 ? g.clock + " MHz" : "-" }
        StatTile { label: Tr.t("Fan"); value: g && g.fan !== "-" && g.fan !== "[N/A]" ? g.fan + (g.kind === "nv" ? " %" : " rpm") : "-" }
        StatTile { label: Tr.t("Power"); value: g && +g.power > 0 ? Math.round(+g.power) + " W" : "-" }
        StatTile { label: Tr.t("Voltage"); value: "-" }
    }
    GraphCard { title: Tr.t("GPU usage"); values: stats.gpuHist; note: g ? "last 60 s" : "this driver reports no usage" }
}
