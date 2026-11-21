import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.components

// Screen time (SPEC round 5 #18): time per app and game, per day, kept
// only on this PC; Settings > Privacy turns it off.
Column {
    id: page
    spacing: 16
    Names { id: names }
    property int range: 0                       // 0 today, 1 last 7 days
    function dayKey(back) { const d = new Date(); d.setDate(d.getDate() - back); return Qt.formatDate(d, "yyyy-MM-dd"); }
    readonly property var week: {
        const out = [];
        for (let i = 6; i >= 0; i--) {
            const k = dayKey(i), m = ScreenTime.days[k] || {};
            out.push({ key: k, label: i === 0 ? Tr.t("Today") : Qt.formatDate(new Date(k + "T12:00:00"), "ddd"), total: Object.values(m).reduce((a, b) => a + b, 0) });
        }
        return out;
    }
    readonly property var apps: {
        const sum = {};
        for (let i = 0; i < (range === 0 ? 1 : 7); i++) { const m = ScreenTime.days[dayKey(i)] || {}; for (const k in m) sum[k] = (sum[k] || 0) + m[k]; }
        return Object.keys(sum).map(k => ({ name: names.of(k), value: sum[k], text: names.duration(sum[k]) })).sort((a, b) => b.value - a.value);
    }
    readonly property real total: apps.reduce((a, b) => a + b.value, 0)

    PageHeader { title: Tr.t("Screen time"); description: Tr.t("How long each app and game was in front. Stored only on this PC; not counted while idle or locked.") }
    EmptyState {
        visible: !Prefs.screenTime
        width: parent.width
        title: Tr.t("Screen time is off")
        hint: Tr.t("Turn it on in Settings > Privacy")
    }
    Row {
        visible: Prefs.screenTime
        spacing: 28
        StatTile { label: page.range === 0 ? Tr.t("Today") : Tr.t("Last 7 days"); value: names.duration(page.total) }
        StatTile { label: Tr.t("Daily average (7 days)"); value: names.duration(page.week.reduce((a, b) => a + b.total, 0) / 7) }
        StatTile { label: Tr.t("Most used"); value: page.apps.length ? page.apps[0].name : "-" }
    }
    SettingCard {
        visible: Prefs.screenTime
        Item {
            width: parent.width; height: Theme.px(150)
            Row {
                id: chart
                anchors.fill: parent; anchors.margins: 16
                spacing: 12
                readonly property real peak: Math.max(3600, ...page.week.map(d => d.total))
                Repeater {
                    model: page.week
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: (chart.width - chart.spacing * 6) / 7; height: chart.height
                        Rectangle {
                            anchors.bottom: lbl.top; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, Theme.px(34)); radius: Theme.px(6)
                            height: Math.max(Theme.px(4), (parent.height - lbl.height - 26) * modelData.total / chart.peak)
                            color: index === 6 ? Theme.accent : Theme.accentFill
                            HoverHandler { id: bh }
                            Tip { text: names.duration(modelData.total); shown: bh.hovered; above: true }
                        }
                        Text { id: lbl; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label
                               font.family: Theme.font; font.pixelSize: Theme.px(12); color: index === 6 ? Theme.text : Theme.muted }
                    }
                }
            }
        }
    }
    Segmented { visible: Prefs.screenTime; width: Theme.px(300); options: [Tr.t("Today"), Tr.t("Last 7 days")]; current: page.range; onPicked: i => page.range = i }
    SettingCard {
        visible: Prefs.screenTime
        Item {
            width: parent.width; height: list.height + 32
            UsageBars { id: list; x: 16; y: 16; width: parent.width - 32; items: page.apps }
            Text { visible: page.apps.length === 0; anchors.centerIn: parent; text: Tr.t("Nothing counted yet"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
        }
    }
    Btn { visible: Prefs.screenTime && page.total > 0; text: Tr.t("Clear screen time"); onClicked: ScreenTime.clear() }
}
