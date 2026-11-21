import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.components

// Battery (SPEC round 8 #8, laptops): charge, health (now vs. new),
// charge cycles, draw, and energy use per app since the last charge.
Column {
    id: page
    spacing: 16
    Names { id: names }
    property var b: ({})
    Cmd {
        id: read
        command: ["sh", "-c", "d=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); [ -n \"$d\" ] || exit 0; for k in status capacity cycle_count energy_full energy_full_design charge_full charge_full_design power_now current_now voltage_now manufacturer model_name technology; do [ -r \"$d/$k\" ] && echo \"$k=$(cat \"$d/$k\" 2>/dev/null)\"; done"]
        onDone: out => { const o = {}; for (const l of out.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1); } page.b = o; }
    }
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: read.run() }
    readonly property bool has: b.capacity !== undefined
    readonly property real full: +(b.energy_full || b.charge_full || 0)
    readonly property real design: +(b.energy_full_design || b.charge_full_design || 0)
    readonly property int health: design > 0 ? Math.round(100 * full / design) : -1
    readonly property real watts: b.power_now ? +b.power_now / 1e6 : (b.current_now && b.voltage_now ? (+b.current_now) * (+b.voltage_now) / 1e12 : 0)
    readonly property var apps: {
        const a = Energy.apps, total = Object.values(a).reduce((x, y) => x + y, 0);
        return Object.keys(a).map(k => ({ name: names.of(k), value: a[k], text: total > 0 ? Math.round(100 * a[k] / total) + " %" : "-" })).sort((x, y) => y.value - x.value);
    }

    PageHeader { title: Tr.t("Battery"); description: Tr.t("Charge, battery health and which apps used the most energy since the last charge.") }
    EmptyState { visible: !page.has; width: parent.width; title: Tr.t("No battery"); hint: Tr.t("This PC runs on mains power only") }
    Row {
        visible: page.has
        spacing: 28
        StatTile { label: Tr.t("Charge"); value: (page.b.capacity || "-") + " %" }
        StatTile { label: Tr.t("State"); value: ({ Charging: Tr.t("Charging"), Discharging: Tr.t("On battery"), Full: Tr.t("Full"), "Not charging": Tr.t("Plugged in, not charging") })[page.b.status] || page.b.status || "-" }
        StatTile { label: Tr.t("Health"); value: page.health > 0 ? page.health + " %" : "-" }
        StatTile { label: Tr.t("Charge cycles"); value: +page.b.cycle_count > 0 ? page.b.cycle_count : "-" }
        StatTile { label: Tr.t("Power draw"); value: page.watts > 0 ? page.watts.toFixed(1) + " W" : "-" }
    }
    SettingCard {
        visible: page.has
        SettingRow { title: Tr.t("Battery"); description: [page.b.manufacturer, page.b.model_name, page.b.technology].filter(x => x).join(" · ") || "-" }
        SettingRow {
            title: Tr.t("Capacity"); last: true
            description: page.design > 0 ? Tr.t("Now %1 of %2 when new").arg((page.full / 1e6).toFixed(1) + (page.b.energy_full ? " Wh" : " Ah")).arg((page.design / 1e6).toFixed(1) + (page.b.energy_full ? " Wh" : " Ah")) : "-"
        }
    }
    Text { visible: page.has; text: Tr.t("Energy use by app"); font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text }
    SettingCard {
        visible: page.has
        Item {
            width: parent.width; height: Math.max(Theme.px(60), bars.height + 32)
            UsageBars { id: bars; x: 16; y: 16; width: parent.width - 32; items: page.apps }
            Text { visible: page.apps.length === 0; anchors.centerIn: parent; width: parent.width - 32; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                   text: Tr.t("Counted while on battery (an estimate from each app's CPU time)"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
        }
    }
}
