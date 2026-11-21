import QtQuick
import qs.theme
import qs.components
import qs.services

// Accessibility: reduce motion, high contrast, text size, zoom.
Column {
    spacing: 16
    PageHeader { title: Tr.t("Accessibility"); description: Tr.t("Make TuxOS easier to see and use.") }
    SettingCard {
        SettingRow { title: Tr.t("Reduce motion"); description: Tr.t("Movement becomes simple fades"); Toggle { checked: Prefs.reduceMotion; onToggled: v => Prefs.reduceMotion = v } }
        SettingRow { title: Tr.t("High contrast"); description: Tr.t("Solid panels, stronger borders"); Toggle { checked: Prefs.highContrast; onToggled: v => Prefs.highContrast = v } }
        SettingRow { title: Tr.t("Text size"); Segmented { width: 360; options: ["Small", "Default", "Large", "Larger"]; current: [0.9, 1.0, 1.15, 1.3].indexOf(Prefs.textScale); onPicked: i => Prefs.textScale = [0.9, 1.0, 1.15, 1.3][i] } }
        SettingRow { title: Tr.t("Screen zoom"); description: Tr.t("Super + scroll zooms in, Super + Esc resets"); last: true }
    }
}
