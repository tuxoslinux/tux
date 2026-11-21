import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// Default apps: what Super + W / B / V / M / F open.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Default apps"); description: Tr.t("The apps TuxOS' shortcuts open.") }
    // the app a shortcut really opens (the chosen one, or the next installed
    // one of its kind when that is gone)
    function shown(kind, pref) { void DesktopEntries.applications.values; const e = Apps.find(kind, pref); return e ? e.id : pref; }   // (again once the app list is read)
    function list(cat, words) {
        return DesktopEntries.applications.values.filter(e => !e.noDisplay && (Array.from(e.categories || []).indexOf(cat) !== -1 || words.test((e.id + " " + e.name).toLowerCase())))
                .map(e => ({ value: e.id, label: e.name }));
    }
    SettingCard {
        SettingRow { title: Tr.t("Terminal"); description: Tr.t("Super + W"); ChoiceList { options: page.list("TerminalEmulator", /kitty|foot|alacritty|wezterm|ghostty|konsole/); current: page.shown("terminal", Prefs.terminal); onPicked: v => Prefs.terminal = v } }
        SettingRow { title: Tr.t("Browser"); description: Tr.t("Super + B · links open here too")
            ChoiceList { options: page.list("WebBrowser", /helium|firefox|chrom|brave|librewolf|zen/); current: page.shown("browser", Prefs.browser)
                onPicked: v => { Prefs.browser = v; Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", v + ".desktop"]); } } }
        SettingRow { title: Tr.t("Music"); description: Tr.t("Super + V"); ChoiceList { options: page.list("Audio", /spotify|music|strawberry|rhythmbox|elisa|amberol|audacious|tidal|deezer|soundcloud/); current: page.shown("music", Prefs.music); onPicked: v => Prefs.music = v } }
        SettingRow { title: Tr.t("Messaging"); description: Tr.t("Super + M"); ChoiceList { options: page.list("InstantMessaging", /discord|vesktop|telegram|signal|viber|element/); current: page.shown("messaging", Prefs.messaging); onPicked: v => Prefs.messaging = v } }
        SettingRow { title: Tr.t("Files"); description: Tr.t("Super + F"); last: true; ChoiceList { options: page.list("FileManager", /thunar|nautilus|dolphin|nemo|pcmanfm|tuxos-files/); current: page.shown("files", Prefs.files); onPicked: v => Prefs.files = v } }
    }
}
