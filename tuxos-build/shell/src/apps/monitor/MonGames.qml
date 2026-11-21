import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// Game history (SPEC round 4 #9): every game session TuxOS summarised
// (~/.local/share/tuxos/game-history.json): time played, average FPS,
// 1 % low, hottest CPU / GPU; and the total per game.
Column {
    id: page
    spacing: 16
    Names { id: names }
    property var list: []
    FileView {
        path: Quickshell.env("HOME") + "/.local/share/tuxos/game-history.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { page.list = (JSON.parse(text()) || []).slice().reverse(); } catch (e) { page.list = []; } }
    }
    readonly property var perGame: {
        const sum = {};
        for (const e of list) sum[e.game] = (sum[e.game] || 0) + (e.seconds || 0);
        return Object.keys(sum).map(k => ({ name: k, value: sum[k], text: names.duration(sum[k]) })).sort((a, b) => b.value - a.value);
    }
    readonly property real total: perGame.reduce((a, b) => a + b.value, 0)

    PageHeader { title: Tr.t("Games"); description: Tr.t("Every game session: time played, frame rate and temperatures. Kept only on this PC.") }
    EmptyState {
        visible: page.list.length === 0
        width: parent.width
        title: Tr.t("No games played yet")
        hint: Tr.t("After a game closes, its session shows up here")
    }
    Row {
        visible: page.list.length > 0
        spacing: 28
        StatTile { label: Tr.t("Time played"); value: names.duration(page.total) }
        StatTile { label: Tr.t("Sessions"); value: String(page.list.length) }
        StatTile { label: Tr.t("Most played"); value: page.perGame.length ? page.perGame[0].name : "-" }
    }
    SettingCard {
        visible: page.list.length > 0
        Item {
            width: parent.width; height: bars.height + 32
            UsageBars { id: bars; x: 16; y: 16; width: parent.width - 32; items: page.perGame; max: 8 }
        }
    }
    Text { visible: page.list.length > 0; text: Tr.t("Sessions"); font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text }
    SettingCard {
        visible: page.list.length > 0
        Repeater {
            model: page.list.slice(0, 50)
            delegate: SettingRow {
                required property var modelData
                required property int index
                last: index === Math.min(50, page.list.length) - 1
                title: modelData.game
                description: Qt.formatDateTime(new Date(modelData.at), "d MMM yyyy, hh:mm") + "  ·  " + names.duration(modelData.seconds || 0)
                Text {
                    text: (modelData.avg ? modelData.avg + " FPS" : "-") + (modelData.low1 ? "  ·  1 % low " + modelData.low1 : "")
                          + (modelData.cpuTemp > 0 ? "  ·  CPU " + Math.round(modelData.cpuTemp) + " °C" : "") + (modelData.gpuTemp > 0 ? "  ·  GPU " + Math.round(modelData.gpuTemp) + " °C" : "")
                    font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted
                }
            }
        }
    }
}
