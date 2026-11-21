import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.theme
import qs.components
import qs.services

// Power & battery: power profile, screen lock time, battery charge limit
// (where the laptop supports it), smart power.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Power & battery"); description: Tr.t("Speed, battery life and when the screen locks.") }
    readonly property bool laptop: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent
    property int limit: -1
    Cmd {
        id: lim
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -1"]
        Component.onCompleted: run()
        onDone: out => page.limit = out.trim() === "" ? -1 : parseInt(out)
    }
    SettingCard {
        header: Tr.t("Power")
        SettingRow {
            title: Tr.t("Power profile"); description: Tr.t("Game mode switches to Performance by itself while a game runs")
            Segmented {
                width: PowerProfiles.hasPerformanceProfile ? 360 : 240
                options: PowerProfiles.hasPerformanceProfile ? ["Power saver", "Balanced", "Performance"] : ["Power saver", "Balanced"]
                current: PowerProfiles.profile === PowerProfile.PowerSaver ? 0 : (PowerProfiles.profile === PowerProfile.Performance ? 2 : 1)
                onPicked: i => PowerProfiles.profile = [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance][i]
            }
        }
        SettingRow {
            title: Tr.t("Lock the screen after"); description: Tr.t("Without input; the wallpaper drifts and darkens for the last 30 s"); last: true
            Segmented { width: 440; options: ["2 min", "5 min", "10 min", "30 min", "Never"]; current: [2, 5, 10, 30, 0].indexOf(Prefs.lockMinutes); onPicked: i => Prefs.lockMinutes = [2, 5, 10, 30, 0][i] }
        }
    }
    SettingCard {
        header: Tr.t("Screen and sleep")
        SettingRow {
            title: Tr.t("Turn the screen off after"); description: Tr.t("Videos and games keep it on")
            Segmented { width: 440; options: ["5 min", "10 min", "15 min", "30 min", "Never"]; current: [5, 10, 15, 30, 0].indexOf(Prefs.screenOffMinutes); onPicked: i => Prefs.screenOffMinutes = [5, 10, 15, 30, 0][i] }
        }
        SettingRow {
            visible: page.laptop
            title: Tr.t("Sleep on battery after"); description: Tr.t("Not while Steam, an update or the Store downloads")
            Segmented { width: 440; options: ["10 min", "20 min", "30 min", "1 h", "Never"]; current: [10, 20, 30, 60, 0].indexOf(Prefs.sleepBattery); onPicked: i => Prefs.sleepBattery = [10, 20, 30, 60, 0][i] }
        }
        SettingRow {
            title: page.laptop ? Tr.t("Sleep when plugged in after") : Tr.t("Sleep after"); description: Tr.t("Not while Steam, an update or the Store downloads"); last: true
            Segmented { width: 440; options: ["30 min", "1 h", "2 h", "Never"]; current: [30, 60, 120, 0].indexOf(Prefs.sleepAc); onPicked: i => Prefs.sleepAc = [30, 60, 120, 0][i] }
        }
    }
    SettingCard {
        header: Tr.t("Battery")
        visible: page.laptop
        SettingRow {
            title: Tr.t("Charge limit"); description: page.limit < 0 ? "This laptop does not let TuxOS limit charging" : "Stops at " + page.limit + " % so the battery lasts longer"
            Segmented {
                visible: page.limit >= 0
                width: 240; options: ["80 %", "90 %", "100 %"]; current: [80, 90, 100].indexOf(page.limit)
                onPicked: i => { const v = [80, 90, 100][i]; Quickshell.execDetached(["sh", "-c", "pkexec \"$@\" || exit 1", "sh", "tuxos-power", "charge-limit", String(v)]); page.limit = v; }
            }
        }
        SettingRow { title: Tr.t("Smart power"); description: Tr.t("Power saver below 20 %, Balanced on battery, the profile below when plugged in (a game always wins)"); Toggle { checked: Prefs.smartPower; onToggled: v => Prefs.smartPower = v } }
        SettingRow { title: Tr.t("60 Hz on battery"); description: Tr.t("Fast screens drop to 60 Hz on battery and go back when plugged in"); last: true; Toggle { checked: Prefs.battery60; onToggled: v => Prefs.battery60 = v } }
    }
    SettingCard {
        header: Tr.t("Plugged in")
        SettingRow {
            title: Tr.t("Power profile when plugged in"); description: page.laptop ? Tr.t("For gaming laptops and desktops: Performance") : Tr.t("This PC has no battery: always plugged in"); last: true
            Segmented { width: 260; options: ["Balanced", "Performance"]; current: Prefs.acProfile === "performance" ? 1 : 0; onPicked: i => Prefs.acProfile = i ? "performance" : "balanced" }
        }
    }
}
