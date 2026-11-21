import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Clock (mockup apps/07-clock): world clock, alarms, stopwatch, timers.
// Timers and the stopwatch are live activities in the bar and keep running
// after the app closes (ClockStore); the shell rings alarms and timers.
AppWindow {
    id: app
    appName: "Clock"
    appIcon: 0xf0150
    property string tab: Quickshell.env("TUXOS_PAGE") || "timers"
    property double now: Date.now()
    Timer { interval: 100; repeat: true; running: true; onTriggered: app.now = Date.now() }
    IpcHandler { target: "clock"; function page(id: string): void { app.tab = id; } }

    // sidebar
    Column {
        id: side
        x: 12; y: 12; width: 226
        spacing: 4
        Repeater {
            model: [["world", "World clock", 0xf01e7, 0], ["alarms", "Alarms", 0xf0020, ClockStore.alarms.filter(a => a.enabled).length],
                    ["stopwatch", "Stopwatch", 0xf051b, ClockStore.stopwatch.running ? 1 : 0], ["timers", "Timers", 0xf051f, ClockStore.timers.length]]
            delegate: Rectangle {
                required property var modelData
                width: side.width; height: 38; radius: 11
                color: app.tab === modelData[0] ? Theme.accentFill : (sh.hovered ? Theme.fill : "transparent")
                border.width: app.tab === modelData[0] ? 1 : 0; border.color: Theme.accentLine
                Row { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 12
                    Text { width: 18; text: String.fromCodePoint(modelData[2]); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: app.tab === modelData[0] ? Theme.accent : Theme.muted }
                    Text { text: modelData[1]; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text } }
                Text { visible: modelData[3] > 0; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: modelData[3]; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: app.tab = modelData[0] }
            }
        }
    }
    Rectangle { x: 250; width: 1; height: parent.height; color: Theme.glassLine }

    Item {
        id: main
        anchors { left: parent.left; leftMargin: 276; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 24 }

        // ================= timers
        Item {
            anchors.fill: parent
            visible: app.tab === "timers"
            readonly property var first: ClockStore.timers.length ? ClockStore.timers[0] : null
            Rectangle {
                id: ringCard
                width: parent.width * 0.55; height: parent.height; radius: 22
                color: Theme.ink(0.035); border.width: 1; border.color: Theme.glassLine
                readonly property var t: parent.first
                readonly property real remaining: t ? ClockStore.leftOf(t, app.now) : 0
                readonly property real frac: t && t.total ? remaining / t.total : 0
                Item {
                    id: dial
                    width: Math.min(parent.width - 60, parent.height - 160, 320); height: width
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 48 }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath { strokeColor: Theme.ink(0.08); strokeWidth: 10; fillColor: "transparent"
                            PathAngleArc { centerX: dial.width / 2; centerY: dial.height / 2; radiusX: dial.width / 2 - 6; radiusY: radiusX; startAngle: 0; sweepAngle: 360 } }
                        ShapePath { strokeColor: Theme.accent; strokeWidth: 10; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            PathAngleArc { centerX: dial.width / 2; centerY: dial.height / 2; radiusX: dial.width / 2 - 6; radiusY: radiusX; startAngle: -90; sweepAngle: 360 * ringCard.frac } }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: ringCard.t ? ringCard.t.name : "No timer"; font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.muted }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Media.time(ringCard.remaining / 1000); font.family: Theme.font; font.pixelSize: Theme.px(64); font.weight: Font.Light; color: Theme.text }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; visible: ringCard.t !== null
                            text: ringCard.t ? "of " + Media.time(ringCard.t.total / 1000) + (ringCard.t.paused ? " · paused" : " · ends " + Qt.formatTime(new Date(ringCard.t.end), "HH:mm")) : ""
                            font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                    }
                }
                Row {
                    visible: ringCard.t !== null
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 }
                    spacing: 12
                    Btn { text: Tr.t("Remove"); icon: 0xf0156; onClicked: ClockStore.removeTimer(ringCard.t) }
                    Btn { text: ringCard.t && ringCard.t.paused ? "Resume" : "Pause"; icon: ringCard.t && ringCard.t.paused ? 0xf040a : 0xf03e4; primary: true; onClicked: ClockStore.pauseTimer(ringCard.t) }
                    Btn { text: Tr.t("+1 min"); onClicked: ClockStore.addMinute(ringCard.t) }
                }
            }
            Column {
                anchors { left: ringCard.right; leftMargin: 24; right: parent.right; top: parent.top }
                spacing: 12
                SettingCard {
                    header: Tr.t("Running")
                    visible: ClockStore.timers.length > 0
                    Repeater {
                        model: ClockStore.timers
                        delegate: SettingRow {
                            required property var modelData
                            required property int index
                            title: modelData.name; description: Media.time(modelData.total / 1000) + (index === 0 ? " · in the bar as a live activity" : "")
                            last: index === ClockStore.timers.length - 1
                            Text { text: Media.time(ClockStore.leftOf(modelData, app.now) / 1000); font.family: Theme.font; font.pixelSize: Theme.px(22); font.weight: Font.DemiBold; color: index === 0 ? Theme.accent : Theme.text }
                        }
                    }
                }
                Text { text: Tr.t("QUICK START"); topPadding: 4; font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
                Grid {
                    columns: 3; spacing: 8
                    Repeater {
                        model: [[1, "1 min"], [5, "5 min"], [10, "10 min"], [15, "15 min"], [25, "25 min"], [60, "1 h"]]
                        delegate: Rectangle {
                            required property var modelData
                            width: (main.width * 0.45 - 26 - 20) / 3; height: 50; radius: 14
                            color: qh.hovered ? Theme.fillHover : Theme.fill; border.width: 1; border.color: Theme.glassLine
                            Text { anchors.centerIn: parent; text: modelData[1]; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
                            HoverHandler { id: qh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: ClockStore.addTimer(modelData[0] * 60000) }
                        }
                    }
                }
            }
        }

        // ================= stopwatch
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: app.tab === "stopwatch"
            spacing: 24
            topPadding: 60
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property real ms: ClockStore.swElapsed(app.now)
                text: Media.time(ms / 1000) + "." + String(Math.floor(ms % 1000 / 10)).padStart(2, "0")
                font.family: Theme.font; font.pixelSize: Theme.px(86); font.weight: Font.Light; font.features: { "tnum": 1 }; color: Theme.text
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                Btn { text: Tr.t("Reset"); onClicked: ClockStore.swReset() }
                Btn { text: ClockStore.stopwatch.running ? "Stop" : "Start"; primary: true; onClicked: ClockStore.swToggle() }
                Btn { text: Tr.t("Lap"); enabled2: ClockStore.stopwatch.running; onClicked: ClockStore.swLap() }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 420
                Repeater {
                    model: (ClockStore.stopwatch.laps || []).slice(0, 8)
                    delegate: Item {
                        required property real modelData
                        required property int index
                        width: 420; height: 34
                        Text { text: Tr.t("Lap ") + ((ClockStore.stopwatch.laps || []).length - index); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
                        Text { anchors.right: parent.right; text: Media.time(modelData / 1000) + "." + String(Math.floor(modelData % 1000 / 10)).padStart(2, "0"); font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.text }
                    }
                }
            }
        }

        // ================= alarms
        Column {
            anchors { left: parent.left; right: parent.right }
            visible: app.tab === "alarms"
            spacing: 16
            PageHeader { title: Tr.t("Alarms"); description: Tr.t("They ring while TuxOS is on (a toast and a sound).") }
            SettingCard {
                Repeater {
                    model: ClockStore.alarms
                    delegate: SettingRow {
                        required property var modelData
                        title: modelData.time + (modelData.label ? "  ·  " + modelData.label : ""); description: ClockStore.daysText(modelData.days)
                        Row { spacing: 8
                            Btn { text: Tr.t("Remove"); onClicked: ClockStore.removeAlarm(modelData) }
                            Toggle { anchors.verticalCenter: parent.verticalCenter; checked: modelData.enabled; onToggled: v => ClockStore.toggleAlarm(modelData, v) } }
                    }
                }
                SettingRow {
                    id: newAlarm
                    title: Tr.t("New alarm"); last: true
                    property int h: 7
                    property int m: 30
                    property var days: [1, 2, 3, 4, 5]
                    Row {
                        spacing: 8
                        Spin { value: newAlarm.h; max: 23; onChanged: v => newAlarm.h = v }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; font.pixelSize: Theme.px(18); color: Theme.text }
                        Spin { value: newAlarm.m; max: 59; onChanged: v => newAlarm.m = v }
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            delegate: Rectangle {
                                required property string modelData
                                required property int index
                                readonly property bool on: newAlarm.days.indexOf(index + 1) !== -1
                                width: 30; height: 30; radius: 15; anchors.verticalCenter: parent.verticalCenter
                                color: on ? Theme.accent : Theme.fill
                                Text { anchors.centerIn: parent; text: modelData; font.family: Theme.font; font.pixelSize: Theme.px(12); color: parent.on ? Theme.accentInk : Theme.text }
                                TapHandler { onTapped: newAlarm.days = parent.on ? newAlarm.days.filter(d => d !== index + 1) : newAlarm.days.concat([index + 1]).sort() }
                            }
                        }
                        Btn { text: Tr.t("Add"); primary: true; onClicked: ClockStore.addAlarm(String(newAlarm.h).padStart(2, "0") + ":" + String(newAlarm.m).padStart(2, "0"), newAlarm.days) }
                    }
                }
            }
        }

        // ================= world clock
        Column {
            anchors { left: parent.left; right: parent.right }
            visible: app.tab === "world"
            spacing: 16
            PageHeader { title: Tr.t("World clock"); description: Tr.t("The same cities show under the calendar in the bar.") }
            property var zones: []
            Process {
                running: app.tab === "world"
                command: ["sh", "-c", "for z in \"$@\"; do printf '%s|%s|%s|%s\\n' \"$z\" \"$(TZ=$z date +%H:%M)\" \"$(TZ=$z date +%z)\" \"$(TZ=$z date '+%a %-d %b')\"; done", "sh"].concat(Prefs.worldClocks)
                stdout: StdioCollector { onStreamFinished: parent.zones = text.split("\n").filter(l => l).map(l => l.split("|")) }
            }
            Flow {
                width: parent.width; spacing: 12
                Repeater {
                    model: parent.parent.zones
                    delegate: Rectangle {
                        required property var modelData
                        width: 260; height: 140; radius: 20
                        color: Theme.ink(0.04); border.width: 1; border.color: Theme.glassLine
                        Column { x: 20; y: 16; spacing: 4
                            Text { text: modelData[0].split("/").pop().replace(/_/g, " "); font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.muted }
                            Text { text: modelData[1]; font.family: Theme.font; font.pixelSize: Theme.px(44); font.weight: Font.Light; color: Theme.text }
                            Text { text: modelData[3] + " · UTC" + modelData[2].slice(0, 3); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim } }
                    }
                }
            }
            Text { text: Tr.t("Add or remove cities in Settings > Date & time"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        }
    }
}
