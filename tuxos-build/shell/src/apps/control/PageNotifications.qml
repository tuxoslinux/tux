import QtQuick
import qs.theme
import qs.components
import qs.services

// Notifications: Do not disturb length, quiet while gaming, sounds.
Column {
    spacing: 16
    PageHeader { title: Tr.t("Notifications"); description: Tr.t("Pop-ups, Do not disturb (Super + D) and focus modes.") }
    SettingCard {
        header: Tr.t("Do not disturb")
        SettingRow {
            title: Tr.t("Super + D lasts"); description: Prefs.dndHours + (Prefs.dndHours === 1 ? " hour" : " hours") + " · press it again to end early"
            Slider { width: 240; value: (Prefs.dndHours - 1) / 11; onMoved: v => Prefs.dndHours = Math.round(1 + v * 11) }
        }
        SettingRow { title: Tr.t("Quiet while a game runs"); description: Tr.t("Pop-ups wait; \"While you were away\" lists them after"); Toggle { checked: Prefs.gameSilence; onToggled: v => Prefs.gameSilence = v } }
        SettingRow { title: Tr.t("Sounds"); description: Tr.t("Unlock, notification and screenshot sounds"); last: true; Toggle { checked: Prefs.uiSounds; onToggled: v => Prefs.uiSounds = v } }
    }
    SettingCard {
        header: Tr.t("Muted apps")
        SettingRow { visible: (Prefs.mutedApps || []).length === 0; title: Tr.t("None"); description: Tr.t("Right-click a notification to mute its app"); last: true }
        Repeater {
            model: Prefs.mutedApps || []
            delegate: SettingRow {
                required property string modelData
                required property int index
                title: modelData; description: Tr.t("No pop-ups or sounds; kept in the notification centre")
                last: index === Prefs.mutedApps.length - 1
                Btn { text: Tr.t("Unmute"); onClicked: Prefs.mutedApps = Prefs.mutedApps.filter(x => x !== modelData) }
            }
        }
    }
    SettingCard {
        header: Tr.t("Focus modes")
        SettingRow { title: Tr.t("Do not disturb"); description: Tr.t("Notifications silenced") }
        SettingRow { title: Tr.t("Work"); description: Tr.t("Chat and games silenced · Balanced power profile") }
        SettingRow { title: Tr.t("Gaming"); description: Tr.t("Notifications silenced · Performance profile · until the game closes") }
        SettingRow { title: Tr.t("Sleep"); description: Tr.t("Notifications silenced · night light · Power saver"); last: true }
    }
}
