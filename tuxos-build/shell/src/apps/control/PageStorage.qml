import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.components

// Storage & cleanup: how full each disk is; one-click cleanup.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Storage & cleanup"); description: Tr.t("Disk space, and freeing it in one click.") }
    property var disks: []
    Cmd { id: df; command: ["sh", "-c", "df -B1 --output=target,size,used,avail -x tmpfs -x devtmpfs -x efivarfs | tail -n +2"]; Component.onCompleted: run()
          onDone: out => page.disks = out.split("\n").filter(x => x).map(l => { const p = l.trim().split(/\s+/); return { mount: p[0], size: +p[1], used: +p[2], free: +p[3] }; }) }
    function gb(b) { return (b / 1e9).toFixed(b > 1e10 ? 0 : 1) + " GB"; }
    SettingCard {
        header: Tr.t("Disks")
        Repeater {
            model: page.disks
            delegate: SettingRow {
                required property var modelData
                title: modelData.mount; description: page.gb(modelData.free) + " free of " + page.gb(modelData.size)
                Rectangle { width: 240; height: 8; radius: 4; color: Theme.ink(0.1)
                    Rectangle { width: parent.width * modelData.used / modelData.size; height: 8; radius: 4; color: modelData.used / modelData.size > 0.9 ? Theme.warn : Theme.accent } }
            }
        }
    }
    CleanupCard { width: parent.width }
    SettingCard {
        header: Tr.t("Tidy Downloads")
        SettingRow {
            title: Tr.t("Move old downloads to the Trash"); description: Tr.t("Once a day, with Undo"); last: !Prefs.tidyDownloads
            Toggle { checked: Prefs.tidyDownloads; onToggled: v => Prefs.tidyDownloads = v }
        }
        SettingRow {
            visible: Prefs.tidyDownloads; last: true
            title: Tr.t("Older than")
            Segmented { width: 300; options: ["7 " + Tr.t("days"), "30 " + Tr.t("days"), "90 " + Tr.t("days")]; current: [7, 30, 90].indexOf(Prefs.tidyDays) < 0 ? 1 : [7, 30, 90].indexOf(Prefs.tidyDays); onPicked: i => Prefs.tidyDays = [7, 30, 90][i] }
        }
    }
}
