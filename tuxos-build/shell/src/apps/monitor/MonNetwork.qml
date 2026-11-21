import QtQuick
import Quickshell
import qs.theme
import qs.components

// Network: live download / upload, totals since the computer started, link
// speed; a speed test that runs only when pressed.
Column {
    id: page
    spacing: 16
    Text { text: Tr.t("Network"); font.family: Theme.font; font.pixelSize: Theme.px(26); font.weight: Font.Bold; color: Theme.text }
    property string test: ""
    Cmd {
        id: speed
        command: ["sh", "-c", "curl -s -o /dev/null --max-time 15 -w '%{speed_download}' 'https://speed.cloudflare.com/__down?bytes=50000000'; echo; head -c 10000000 /dev/zero | curl -s -o /dev/null --max-time 15 -w '%{speed_upload}' -X POST --data-binary @- https://speed.cloudflare.com/__up"]
        onDone: out => { const p = out.split("\n"); page.test = `Download ${(p[0] * 8 / 1e6).toFixed(0)} Mbit/s · upload ${((+p[1] || 0) * 8 / 1e6).toFixed(0)} Mbit/s`; }
    }
    Repeater {
        model: app.info.nets || []
        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 8
            readonly property var n: stats.nets[modelData.name] || ({ rx: 0, tx: 0, rxTotal: 0, txTotal: 0 })
            Item {
                width: parent.width; height: 46
                Column {
                    Text { text: (modelData.kind === "wifi" ? "Wi-Fi" : "Ethernet") + " · " + modelData.name; font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: modelData.speed ? "Link " + (modelData.speed >= 1000 ? modelData.speed / 1000 + " Gbit/s" : modelData.speed + " Mbit/s") : "Link speed: -"; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                }
                Row {
                    anchors.right: parent.right; spacing: 28
                    StatTile { label: Tr.t("Download"); value: stats.rate(parent.parent.parent.n.rx) }
                    StatTile { label: Tr.t("Upload"); value: stats.rate(parent.parent.parent.n.tx) }
                    StatTile { label: Tr.t("Since start"); value: "↓ " + stats.bytes(parent.parent.parent.n.rxTotal) + "  ↑ " + stats.bytes(parent.parent.parent.n.txTotal) }
                }
            }
            GraphCard { title: Tr.t("Traffic (kB/s)"); values: stats.netHist[modelData.name] || []; max: Math.max(1, ...(stats.netHist[modelData.name] || [1])); height: 150 }
        }
    }
    Row {
        spacing: 12
        Btn { text: speed.running ? "Testing..." : "Run speed test"; primary: true; enabled2: !speed.running; onClicked: { page.test = ""; speed.run(); } }
        Text { anchors.verticalCenter: parent.verticalCenter; text: page.test || "Runs only when you press it"; font.family: Theme.font; font.pixelSize: Theme.px(14); color: page.test ? Theme.text : Theme.muted }
    }
}
