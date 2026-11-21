import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import Quickshell.Io

// Clock droplet content (SPEC): live time with seconds, full date, a month
// calendar (mouse wheel = previous / next month).
Item {
    id: cal
    implicitWidth: 440
    implicitHeight: col.implicitHeight + 58

    SystemClock { id: clock; precision: SystemClock.Seconds }
    property int monthOffset: 0
    readonly property date shown: {
        const d = new Date(clock.date.getFullYear(), clock.date.getMonth() + monthOffset, 1);
        return d;
    }

    // world clocks (Settings > Date & time), refreshed while the droplet is open
    property var zones: []
    Process {
        id: zoneProc
        running: cal.visible && Shell.panel === "calendar"
        command: ["sh", "-c", "for z in \"$@\"; do printf '%s|%s|%s\\n' \"$z\" \"$(TZ=$z date +%H:%M)\" \"$(TZ=$z date +%z)\"; done", "sh"].concat(Prefs.worldClocks)
        stdout: StdioCollector {
            onStreamFinished: {
                const here = -new Date().getTimezoneOffset();
                cal.zones = text.split("\n").filter(l => l).map(l => {
                    const [z, t, off] = l.split("|");
                    const mins = (off[0] === "-" ? -1 : 1) * (parseInt(off.slice(1, 3)) * 60 + parseInt(off.slice(3, 5)));
                    const d = (mins - here) / 60;
                    return { city: z.split("/").pop().replace(/_/g, " "), time: t, diff: d === 0 ? "same time" : (d > 0 ? "+" : "") + d + " h" };
                });
            }
        }
    }
    Timer { interval: 60000; repeat: true; running: zoneProc.running === false && Shell.panel === "calendar"; onTriggered: zoneProc.running = true }
    Connections { target: Shell; function onPanelChanged() { if (Shell.panel === "calendar") Weather.refresh(); } }

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28; topMargin: 28 }
        spacing: 0

        Row {
            spacing: 0
            Text { text: Qt.formatDateTime(clock.date, "HH"); font.family: Theme.font; font.pixelSize: Theme.px(64); font.weight: Font.Bold; color: Theme.text }
            Text { text: ":"; font.family: Theme.font; font.pixelSize: Theme.px(64); font.weight: Font.Bold; color: Theme.accent }
            Text { text: Qt.formatDateTime(clock.date, "mm"); font.family: Theme.font; font.pixelSize: Theme.px(64); font.weight: Font.Bold; color: Theme.text }
            Text { text: ":" + Qt.formatDateTime(clock.date, "ss"); font.family: Theme.font; font.pixelSize: Theme.px(64); font.weight: Font.DemiBold; color: Theme.muted }
        }
        Text {
            topPadding: 4
            text: Tr.date(clock.date, "dddd, d MMMM yyyy")
            font.family: Theme.font; font.pixelSize: Theme.px(16); color: Theme.muted
        }

        Item { width: 1; height: 24 }

        Item {
            width: parent.width; height: 32
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.date(cal.shown, "MMMM yyyy")
                font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 4
                Repeater {
                    model: [-1, 1]
                    delegate: Rectangle {
                        required property int modelData
                        width: 30; height: 30; radius: 9
                        color: navHover.hovered ? Theme.fillHover : Theme.ink(0.05)
                        Sym { anchors.centerIn: parent; code: parent.modelData < 0 ? 0xf053 : 0xf054; font.pixelSize: Theme.px(13); color: Theme.muted }
                        HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: cal.monthOffset += parent.modelData }
                    }
                }
            }
        }

        Item { width: 1; height: 10 }

        Grid {
            id: grid
            columns: 7
            width: parent.width
            readonly property real cell: width / 7
            readonly property int lead: (new Date(cal.shown.getFullYear(), cal.shown.getMonth(), 1).getDay() + 6) % 7
            readonly property int days: new Date(cal.shown.getFullYear(), cal.shown.getMonth() + 1, 0).getDate()
            readonly property int prevDays: new Date(cal.shown.getFullYear(), cal.shown.getMonth(), 0).getDate()

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: Text {
                    required property string modelData
                    width: grid.cell; height: 28
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; color: Theme.dim
                }
            }
            Repeater {
                model: 42
                delegate: Item {
                    required property int index
                    readonly property int day: index - grid.lead + 1
                    readonly property bool inMonth: day >= 1 && day <= grid.days
                    readonly property bool today: inMonth && cal.monthOffset === 0 && day === clock.date.getDate()
                    readonly property bool weekend: index % 7 >= 5
                    visible: index < Math.ceil((grid.lead + grid.days) / 7) * 7
                    width: grid.cell; height: 44
                    Rectangle {
                        anchors.centerIn: parent
                        width: 38; height: 38; radius: 12
                        color: parent.today ? Theme.accent : "transparent"
                    }
                    // a dot under days with calendar events
                    Rectangle {
                        visible: parent.inMonth && Events.all.some(e => { const d = new Date(e.start); return d.getFullYear() === cal.shown.getFullYear() && d.getMonth() === cal.shown.getMonth() && d.getDate() === parent.day; })
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                        width: 4; height: 4; radius: 2
                        color: parent.today ? Theme.accentInk : Theme.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.inMonth ? parent.day : (parent.day < 1 ? grid.prevDays + parent.day : parent.day - grid.days)
                        font.family: Theme.font; font.pixelSize: Theme.px(14)
                        font.weight: parent.today ? Font.Bold : Font.Normal
                        color: parent.today ? Theme.accentInk : (!parent.inMonth ? Theme.dim : (parent.weekend ? Theme.muted : Theme.text))
                    }
                }
            }
        }

        Item { width: 1; height: 16 }
        Rectangle { width: parent.width; height: 1; color: Theme.glassLine }
        Item { width: 1; height: 14 }

        // world clocks
        Row {
            width: parent.width
            visible: cal.zones.length > 0
            Repeater {
                model: cal.zones.slice(0, 3)
                delegate: Column {
                    required property var modelData
                    width: parent.width / Math.min(3, cal.zones.length)
                    spacing: 4
                    Text { text: modelData.city; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                    Text { text: modelData.time; font.family: Theme.font; font.pixelSize: Theme.px(20); font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: modelData.diff; font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.dim }
                }
            }
        }
        Item { width: 1; height: 14; visible: Weather.ready }
        // today's weather
        Row {
            visible: Weather.ready
            spacing: 12
            Rectangle {
                width: 40; height: 40; radius: 12
                color: Theme.accentFill
                Sym { anchors.centerIn: parent; code: Weather.icon; color: Theme.accent; font.pixelSize: Theme.px(20) }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: `${Math.round(Weather.temp)}°  ${Weather.condition}`; font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text }
                Text { text: `${Weather.city} · ${Math.round(Weather.high)}° / ${Math.round(Weather.low)}°`; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.AllDevices
        onWheel: event => cal.monthOffset += event.angleDelta.y < 0 ? 1 : -1
    }
}
