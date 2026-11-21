import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Calendar (mockup apps/08-calendar): month / week / day, calendars
// (Personal, Work, Birthdays, Holidays in Bulgaria), today's weather, a New
// event box that understands plain text ("lunch with Alex tomorrow 13:00",
// English or Bulgarian). Events are shared with the bar (clock droplet dots,
// next-event live activity) through ~/.local/share/tuxos/events.json.
AppWindow {
    id: app
    appName: "Calendar"
    appIcon: 0xf00ed
    property string view: "month"
    property date cursor: new Date()
    property var hidden: []                        // calendars switched off
    property var selected: null                    // event shown in the side panel
    property bool adding: false
    property bool subscribing: false
    readonly property var cals: [["Personal", Theme.accent], ["Work", "#8fe3c0"], ["Birthdays", "#ffa8c0"], ["Holidays (BG)", "#ffd08f"]]
                                .concat(CalendarSubs.list.map(c => [c.name, c.color, c]))
    function calColor(c) { const x = cals.find(k => k[0] === c); return x ? x[1] : Theme.accent; }
    Holidays { id: hol }
    readonly property var all: {
        const y = cursor.getFullYear();
        return Events.all.concat(hol.forYear(y - 1), hol.forYear(y), hol.forYear(y + 1)).filter(e => hidden.indexOf(e.cal || "Personal") === -1);
    }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function eventsOn(d) { return all.filter(e => sameDay(new Date(e.start), d)).sort((a, b) => a.start - b.start); }
    function shift(n) {
        const d = new Date(cursor);
        if (view === "month") d.setMonth(d.getMonth() + n); else d.setDate(d.getDate() + n * (view === "week" ? 7 : 1));
        cursor = d;
    }
    Component.onCompleted: Weather.refresh()

    // ---- title bar extras: view switch + New event
    Row {
        parent: app.contentItem
        anchors { right: parent.right; rightMargin: 128; top: parent.top; topMargin: 8 }
        spacing: 12
        z: 10
        Segmented { width: 210; options: ["Day", "Week", "Month"]; current: ["day", "week", "month"].indexOf(app.view); onPicked: i => app.view = ["day", "week", "month"][i] }
        Btn { text: Tr.t("+ New event"); primary: true; onClicked: { app.adding = true; app.selected = null; quick.forceActiveFocus(); } }
    }

    // ---- sidebar
    Column {
        id: side
        x: 12; y: 16; width: 226
        spacing: 4
        Text { leftPadding: 8; text: Tr.date(app.cursor, "MMMM yyyy"); font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
        Text { leftPadding: 8; topPadding: 8; text: Tr.t("CALENDARS"); font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
        Repeater {
            model: app.cals
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: app.hidden.indexOf(modelData[0]) === -1
                width: side.width; height: 36; radius: 11
                color: ch.hovered ? Theme.fill : "transparent"
                Row { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 12
                    Rectangle { width: 12; height: 12; radius: 6; anchors.verticalCenter: parent.verticalCenter; color: parent.parent.on ? modelData[1] : "transparent"; border.width: 2; border.color: modelData[1] }
                    Text { text: modelData[0]; width: side.width - 70; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); color: parent.parent.on ? Theme.text : Theme.muted } }
                HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                // a subscription: × removes it (shown on hover)
                Text {
                    visible: modelData.length > 2 && ch.hovered
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "×"; font.family: Theme.font; font.pixelSize: Theme.px(18); color: xh.hovered ? Theme.danger : Theme.muted
                    HoverHandler { id: xh }
                    TapHandler { onTapped: CalendarSubs.removeSub(modelData[2]) }
                }
                TapHandler { onTapped: app.hidden = parent.on ? app.hidden.concat([modelData[0]]) : app.hidden.filter(x => x !== modelData[0]) }
            }
        }
        // subscribed calendars (Google, Outlook, Nextcloud, iCloud ... by their .ics address)
        Rectangle {
            width: side.width; height: 36; radius: 11
            color: addH.hovered ? Theme.fill : "transparent"
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: "+ " + Tr.t("Add by address"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.accent }
            HoverHandler { id: addH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { app.subscribing = !app.subscribing; if (app.subscribing) subUrl.input.forceActiveFocus(); } }
        }
        Column {
            visible: app.subscribing
            width: side.width; spacing: 6; leftPadding: 4
            Field { id: subUrl; width: side.width - 8; placeholder: Tr.t("Address (.ics / webcal://)"); onAccepted: subName.input.forceActiveFocus() }
            Field { id: subName; width: side.width - 8; placeholder: Tr.t("Name (optional)"); onAccepted: subAdd.clicked() }
            Text { width: side.width - 8; wrapMode: Text.Wrap; text: Tr.t("Google: Settings of the calendar > Secret address in iCal format. Outlook, Nextcloud and iCloud have a similar link."); font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.dim }
            Row {
                spacing: 8
                Btn { id: subAdd; text: Tr.t("Add"); primary: true; enabled2: /^(https?|webcal):\/\//i.test(subUrl.text.trim())
                      onClicked: if (enabled2 && CalendarSubs.addSub(subName.text, subUrl.text)) { subUrl.text = ""; subName.text = ""; app.subscribing = false; } }
                Btn { text: Tr.t("Cancel"); onClicked: app.subscribing = false }
            }
        }
        Item { width: 1; height: 10 }
        Rectangle {
            visible: Weather.ready
            width: side.width; height: 80; radius: 16
            color: Theme.ink(0.04); border.width: 1; border.color: Theme.glassLine
            Column { x: 16; anchors.verticalCenter: parent.verticalCenter
                Text { text: Tr.t("Today · ") + Weather.city; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                Row { spacing: 8
                    Text { text: Math.round(Weather.temp) + "°"; font.family: Theme.font; font.pixelSize: Theme.px(28); font.weight: Font.Bold; color: Theme.text }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: Weather.condition; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted } } }
        }
        Item { width: 1; height: 10 }
        // new event (plain text) / event details
        Rectangle {
            visible: app.adding || app.selected !== null
            width: side.width; height: panel.implicitHeight + 28; radius: 16
            color: Theme.ink(0.05); border.width: 1; border.color: Theme.accentLine
            Column {
                id: panel
                x: 12; y: 12; width: parent.width - 28
                spacing: 8
                // adding
                Text { visible: app.adding; text: Tr.t("New event"); font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.text }
                Rectangle {
                    visible: app.adding
                    width: parent.width; height: 34; radius: 10; color: Theme.ink(0.05); border.width: 1; border.color: quick.activeFocus ? Theme.accentLine : Theme.glassLine
                    TextInput {
                        id: quick
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 } verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text; clip: true
                        onAccepted: addBtn.go()
                        Keys.onEscapePressed: app.adding = false
                        Text { visible: quick.text === ""; text: Tr.t("Lunch with Alex tomorrow 13:00"); font: quick.font; color: Theme.dim }
                    }
                }
                readonly property var parsed: Events.parse(quick.text)
                Text {
                    visible: app.adding; width: parent.width; wrapMode: Text.Wrap
                    text: parent.parsed ? parent.parsed.title + " · " + Tr.date(new Date(parent.parsed.start), parent.parsed.allDay ? "ddd d MMM" : "ddd d MMM, HH:mm") : (quick.text ? Tr.t("Add a day or a time (tomorrow, friday, 15.11, 13:00)") : Tr.t("Type it the way you would say it"))
                    font.family: Theme.font; font.pixelSize: Theme.px(12); color: parent.parsed ? Theme.accent : Theme.muted
                }
                Row {
                    visible: app.adding; spacing: 4
                    property string cal: "Personal"
                    id: calPick
                    Repeater { model: app.cals.slice(0, 3)
                        delegate: Rectangle { required property var modelData; width: 20; height: 20; radius: 10; color: modelData[1]; opacity: calPick.cal === modelData[0] ? 1 : 0.35
                            TapHandler { onTapped: calPick.cal = modelData[0] } } }
                }
                Row {
                    visible: app.adding; spacing: 8
                    Btn { text: Tr.t("Cancel"); onClicked: { app.adding = false; quick.text = ""; } }
                    Btn {
                        id: addBtn; text: Tr.t("Add"); primary: true; enabled2: panel.parsed !== null
                        function go() { if (!panel.parsed) return; Events.add(panel.parsed.title, panel.parsed.start, 0, calPick.cal); app.cursor = new Date(panel.parsed.start); quick.text = ""; app.adding = false; }
                        onClicked: go()
                    }
                }
                // details
                Text { visible: app.selected !== null; width: parent.width; wrapMode: Text.Wrap; text: app.selected ? app.selected.title : ""; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
                Text { visible: app.selected !== null; text: app.selected ? Tr.date(new Date(app.selected.start), app.selected.allDay ? "dddd d MMMM" : "dddd d MMMM, HH:mm") + "\n" + (app.selected.cal || "Personal") : ""; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                Row {
                    visible: app.selected !== null; spacing: 8
                    Btn { text: Tr.t("Close"); onClicked: app.selected = null }
                    Btn { text: Tr.t("Delete"); danger: true; visible: app.selected !== null && app.selected.cal !== "Holidays (BG)" && !app.selected.readOnly; onClicked: { Events.remove(app.selected); app.selected = null; } }
                }
            }
        }
    }
    Rectangle { x: 250; width: 1; height: parent.height; color: Theme.glassLine }

    // ---- main area
    Item {
        id: main
        anchors { left: parent.left; leftMargin: 276; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 24 }
        Row {
            id: head
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: app.view === "day" ? Tr.date(app.cursor, "dddd d MMMM") : app.view === "week" ? "Week of " + Tr.date(main.weekStart, "d MMMM") : Tr.date(app.cursor, "MMMM yyyy")
                font.family: Theme.font; font.pixelSize: Theme.px(28); font.weight: Font.Bold; color: Theme.text
            }
            Btn { icon: 0xf0141; text: ""; anchors.verticalCenter: parent.verticalCenter; onClicked: app.shift(-1) }
            Btn { icon: 0xf0142; text: ""; anchors.verticalCenter: parent.verticalCenter; onClicked: app.shift(1) }
            Btn { text: Tr.t("Today"); anchors.verticalCenter: parent.verticalCenter; onClicked: app.cursor = new Date() }
        }
        readonly property date weekStart: { const d = new Date(app.cursor); d.setDate(d.getDate() - (d.getDay() + 6) % 7); d.setHours(0, 0, 0, 0); return d; }
        WheelHandler { acceptedDevices: PointerDevice.AllDevices; onWheel: e => app.shift(e.angleDelta.y > 0 ? -1 : 1) }

        // month
        Item {
            visible: app.view === "month"
            anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 16; bottom: parent.bottom }
            readonly property date first: new Date(app.cursor.getFullYear(), app.cursor.getMonth(), 1)
            readonly property int lead: (first.getDay() + 6) % 7
            Row {
                id: dow
                Repeater { model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                    delegate: Text { required property string modelData; width: main.width / 7; leftPadding: 12; text: modelData; font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; color: Theme.muted } }
            }
            Grid {
                anchors { top: dow.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom }
                columns: 7
                Repeater {
                    model: 42
                    delegate: Rectangle {
                        required property int index
                        readonly property date day: new Date(parent.parent.first.getFullYear(), parent.parent.first.getMonth(), index - parent.parent.lead + 1)
                        readonly property bool inMonth: day.getMonth() === app.cursor.getMonth()
                        readonly property bool today: app.sameDay(day, new Date())
                        width: main.width / 7; height: (main.height - 70) / 6
                        color: dh.hovered ? Theme.ink(0.03) : "transparent"
                        border.width: 1; border.color: Theme.ink(0.04)
                        Rectangle {
                            x: 8; y: 8; width: 26; height: 26; radius: 13
                            color: parent.today ? Theme.accent : "transparent"
                            Text { anchors.centerIn: parent; text: parent.parent.day.getDate(); font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: parent.parent.today ? Font.Bold : Font.Normal
                                   color: parent.parent.today ? Theme.accentInk : (parent.parent.inMonth ? Theme.text : Theme.dim) }
                        }
                        Column {
                            x: 4; y: 40; width: parent.width - 12; spacing: 4
                            Repeater {
                                model: app.eventsOn(parent.parent.day).slice(0, 3)
                                delegate: Rectangle {
                                    required property var modelData
                                    width: parent.width; height: 20; radius: 6
                                    color: Qt.rgba(Qt.color(app.calColor(modelData.cal)).r, Qt.color(app.calColor(modelData.cal)).g, Qt.color(app.calColor(modelData.cal)).b, 0.22)
                                    Text { x: 4; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 10; elide: Text.ElideRight
                                           text: modelData.title + (modelData.allDay ? "" : " " + Qt.formatTime(new Date(modelData.start), "HH:mm")); font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.text }
                                    TapHandler { onTapped: { app.selected = modelData; app.adding = false; } }
                                }
                            }
                        }
                        HoverHandler { id: dh }
                        TapHandler { onDoubleTapped: { app.cursor = parent.day; app.view = "day"; } }
                    }
                }
            }
        }

        // week + day: hours 07-23 down, days across
        Flickable {
            id: wk
            visible: app.view !== "month"
            anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 16; bottom: parent.bottom }
            contentHeight: 17 * 52 + 40
            clip: true
            readonly property int days: app.view === "week" ? 7 : 1
            readonly property date start: app.view === "week" ? main.weekStart : (() => { const d = new Date(app.cursor); d.setHours(0, 0, 0, 0); return d; })()
            Row {
                x: 56
                Repeater { model: wk.days
                    delegate: Text { required property int index; width: (main.width - 56) / wk.days; horizontalAlignment: Text.AlignHCenter
                        readonly property date d: new Date(wk.start.getTime() + index * 86400000)
                        text: Tr.date(d, "ddd d"); font.family: Theme.font; font.pixelSize: Theme.px(13); font.weight: app.sameDay(d, new Date()) ? Font.Bold : Font.Normal; color: app.sameDay(d, new Date()) ? Theme.accent : Theme.muted } }
            }
            Repeater {
                model: 17
                delegate: Item {
                    required property int index
                    y: 32 + index * 52; width: main.width; height: 52
                    Text { width: 46; horizontalAlignment: Text.AlignRight; text: String(index + 7).padStart(2, "0") + ":00"; font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.dim }
                    Rectangle { x: 56; width: parent.width - 56; height: 1; color: Theme.glassLine }
                }
            }
            Repeater {
                model: wk.days
                delegate: Item {
                    required property int index
                    readonly property date d: new Date(wk.start.getTime() + index * 86400000)
                    x: 56 + index * (main.width - 56) / wk.days; y: 32
                    width: (main.width - 56) / wk.days; height: 17 * 52
                    Repeater {
                        model: app.eventsOn(parent.d)
                        delegate: Rectangle {
                            required property var modelData
                            readonly property date s: new Date(modelData.start)
                            x: 4; width: parent.width - 6
                            y: modelData.allDay ? 0 : Math.max(0, (s.getHours() + s.getMinutes() / 60 - 7) * 52)
                            height: modelData.allDay ? 22 : Math.max(24, ((modelData.end || modelData.start + 3600000) - modelData.start) / 3600000 * 52 - 3)
                            radius: 8
                            color: Qt.rgba(Qt.color(app.calColor(modelData.cal)).r, Qt.color(app.calColor(modelData.cal)).g, Qt.color(app.calColor(modelData.cal)).b, 0.25)
                            border.width: 1; border.color: app.calColor(modelData.cal)
                            Text { x: 8; y: 4; width: parent.width - 12; elide: Text.ElideRight; text: (modelData.allDay ? "" : Qt.formatTime(parent.s, "HH:mm") + "  ") + modelData.title; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.text }
                            TapHandler { onTapped: { app.selected = modelData; app.adding = false; } }
                        }
                    }
                }
            }
        }
    }
}
