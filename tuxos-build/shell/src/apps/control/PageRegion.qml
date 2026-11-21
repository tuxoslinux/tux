import QtQuick
import qs.theme
import qs.components
import qs.services

// Language & region: English / Bulgarian for TuxOS' own text.
Column {
    spacing: 16
    PageHeader { title: Tr.t("Language & region"); description: Tr.t("The language of TuxOS' own text, and formats.") }
    SettingCard {
        SettingRow { title: Tr.t("Language"); description: Tr.t("TuxOS' shell and apps"); Segmented { width: 260; options: ["English", "Български"]; current: Prefs.language === "bg" ? 1 : 0; onPicked: i => Prefs.language = i === 1 ? "bg" : "en" } }
        SettingRow { title: Tr.t("Temperature"); last: true; Segmented { width: 200; options: ["°C", "°F"]; current: Prefs.weatherUnits === "f" ? 1 : 0; onPicked: i => Prefs.weatherUnits = i === 1 ? "f" : "c" } }
    }
}
