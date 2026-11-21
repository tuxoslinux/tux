import QtQuick
import qs.theme
import qs.components
import qs.services

// Desktop & dock: dock and bar behaviour, desktop names, extras.
Column {
    spacing: 16
    PageHeader { title: Tr.t("Desktop & dock"); description: Tr.t("How the bar, the dock and the nine desktops behave.") }
    SettingCard {
        header: Tr.t("Dock")
        SettingRow { title: Tr.t("Hide the dock under windows"); description: Tr.t("It comes back when the pointer touches the bottom edge"); Toggle { checked: Prefs.dockAutoHide; onToggled: v => Prefs.dockAutoHide = v } }
        SettingRow { title: Tr.t("Pinned apps"); description: Tr.f("{n} pinned · right-click a dock tile to pin or unpin", { n: Prefs.pins.length }); last: true; Btn { text: Tr.t("Reset to TuxOS' set"); onClicked: Prefs.pins = ["tuxos-files", "helium", "kitty", "steam", "spotify", "tuxos-editor"] } }
    }
    SettingCard {
        header: Tr.t("Bar")
        SettingRow { title: Tr.t("Hide the bar"); description: Tr.t("Always hidden in full screen; this hides it all the time (top edge or Super shows it)"); Toggle { checked: Prefs.barAutoHide; onToggled: v => Prefs.barAutoHide = v } }
        SettingRow { title: Tr.t("Boot time"); description: Tr.t("\"Booted in 2.7 s\" after each start"); Toggle { checked: Prefs.bootCard; onToggled: v => Prefs.bootCard = v } }
        SettingRow { title: Tr.t("Seasonal Tux"); description: Tr.t("A hat in December, a pumpkin at Halloween"); Toggle { checked: Prefs.seasonalTux; onToggled: v => Prefs.seasonalTux = v } }
        SettingRow { title: Tr.t("Rounded screen corners"); last: true; Toggle { checked: Prefs.screenCorners; onToggled: v => Prefs.screenCorners = v } }
    }
    SettingCard {
        header: Tr.t("Apps at login")
        SettingRow {
            title: Tr.t("Open the apps of the last session"); description: Tr.t("On the same desktops, after a restart, shutdown or logout")
            Segmented { width: 300; options: ["Ask", "Always", "Never"]; current: ["ask", "always", "never"].indexOf(Prefs.restoreApps); onPicked: i => Prefs.restoreApps = ["ask", "always", "never"][i] }
        }
        SettingRow {
            title: Tr.t("Saved setups"); last: true
            description: Object.keys(Session.setups).length ? Tr.f("{list} · open one from the launcher: \"setup NAME\"", { list: Object.keys(Session.setups).join(", ") }) : Tr.t("Open some apps, then type \"save setup Streaming\" in the launcher")
        }
    }
    SettingCard {
        header: Tr.t("Desktop names")
        Repeater {
            model: 9
            delegate: SettingRow {
                required property int index
                title: Tr.t("Desktop ") + (index + 1)
                description: index < 5 ? "Always in the bar" : "In the bar while in use"
                last: index === 8
                Rectangle {
                    width: 220; height: 34; radius: 10
                    color: Theme.ink(0.05); border.width: 1; border.color: nameField.activeFocus ? Theme.accentLine : Theme.glassLine
                    TextInput {
                        id: nameField
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        text: Prefs.desktopNames[String(index + 1)] || ""
                        font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; clip: true
                        onEditingFinished: { const n = Object.assign({}, Prefs.desktopNames); if (text) n[String(index + 1)] = text; else delete n[String(index + 1)]; Prefs.desktopNames = n; }
                        Text { visible: nameField.text === ""; text: Tr.t("Desktop ") + (index + 1); font: nameField.font; color: Theme.dim }
                    }
                }
            }
        }
    }
}
