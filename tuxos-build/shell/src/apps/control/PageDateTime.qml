import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// Date & time: 24-hour clock, time zone, world clocks, weather place.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Date & time"); description: Tr.t("Clock, time zone and the world clocks under the calendar.") }
    property string zone: ""
    property var zones: []
    Cmd { id: z; command: ["sh", "-c", "readlink /etc/localtime | sed 's|.*/zoneinfo/||'; cd /usr/share/zoneinfo && find . -type f -path './[A-Z]*/*' | sed 's|^./||' | grep -v -E '^(posix|right|Etc)/' | sort"]
          Component.onCompleted: run(); onDone: out => { const l = out.split("\n").filter(x => x); page.zone = l[0]; page.zones = l.slice(1).map(x => ({ value: x, label: x.replace(/_/g, " ") })); } }
    SettingCard {
        SettingRow { title: Tr.t("24-hour clock"); Toggle { checked: Prefs.use24h; onToggled: v => Prefs.use24h = v } }
        SettingRow { title: Tr.t("Time zone"); description: page.zone.replace(/_/g, " "); last: true
            ChoiceList { width: 300; options: page.zones; current: page.zone
                onPicked: v => { Quickshell.execDetached(["sh", "-c", "pkexec \"$@\" || exit 1", "sh", "ln", "-sf", "/usr/share/zoneinfo/" + v, "/etc/localtime"]); page.zone = v; } } }
    }
    SettingCard {
        header: Tr.t("World clocks")
        Repeater {
            model: Prefs.worldClocks
            delegate: SettingRow {
                required property string modelData
                title: modelData.split("/").pop().replace(/_/g, " "); description: modelData
                Btn { text: Tr.t("Remove"); onClicked: Prefs.worldClocks = Prefs.worldClocks.filter(x => x !== modelData) }
            }
        }
        SettingRow { title: Tr.t("Add a city"); last: true; ChoiceList { width: 300; options: page.zones; onPicked: v => Prefs.worldClocks = Prefs.worldClocks.concat([v]).slice(-4) } }
    }
    SettingCard {
        header: Tr.t("Weather")
        SettingRow { title: Tr.t("Place"); description: Prefs.weatherCity || "From the time zone"; last: true
            Rectangle { width: 220; height: 34; radius: 10; color: Theme.ink(0.05); border.width: 1; border.color: Theme.glassLine
                TextInput { id: city; anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: TextInput.AlignVCenter; text: Prefs.weatherCity
                    font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; clip: true; onEditingFinished: Prefs.weatherCity = text
                    Text { visible: city.text === ""; text: Tr.t("City"); font: city.font; color: Theme.dim } } } }
    }
}
