import QtQuick
import qs.theme
import qs.components
import qs.services

// Content of the game summary droplet (mockup shell2/14-gamesum).
Column {
    id: gsum
    readonly property var s: GameSessions.last || ({})
    padding: 24
    spacing: 12
    Row {
        spacing: 12
        Rectangle {
            width: 40; height: 40; radius: 12; color: Theme.accent
            Sym { anchors.centerIn: parent; code: Icons.gamepadVariant; color: Theme.accentInk; font.pixelSize: Theme.px(20) }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: gsum.s.game || ""; font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text }
            Text { text: Tr.t("Session ended · ") + GameSessions.duration(gsum.s.seconds || 0); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        }
    }
    Grid {
        columns: 3; spacing: 8
        Repeater {
            model: [["Average", (gsum.s.avg || 0) + " FPS"], ["1 % low", (gsum.s.low1 || 0) + " FPS"], ["Hottest GPU", gsum.s.gpuTemp > 0 ? gsum.s.gpuTemp + " °C" : "-"],
                    ["Hottest CPU", gsum.s.cpuTemp > 0 ? gsum.s.cpuTemp + " °C" : "-"], ["Stutters", String(gsum.s.stutters || 0)], ["Game mode", "on all session"]]
            delegate: Rectangle {
                required property var modelData
                width: (gsum.width - 48 - 20) / 3; height: 56; radius: 14
                color: Theme.fill; border.width: 1; border.color: Theme.glassLine
                Column { x: 12; anchors.verticalCenter: parent.verticalCenter
                    Text { text: modelData[0]; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                    Text { text: modelData[1]; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text } }
            }
        }
    }
    Graph { width: gsum.width - 48; height: 36; values: gsum.s.fps || []; max: Math.max(1, ...(gsum.s.fps || [1])) * 1.1; points: Math.max(2, (gsum.s.fps || []).length) }
    Text { text: Tr.t("FPS over the session · saved in System manager"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
}
