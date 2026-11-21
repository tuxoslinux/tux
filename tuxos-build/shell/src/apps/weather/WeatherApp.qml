import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Weather (mockup apps/18-weather): Open-Meteo (free, no account, no
// tracking) for the place in Settings (or the time zone's city): now,
// feels like, high / low, wind, humidity, rain chance, UV, sunrise and
// sunset, the next 24 hours and 7 days. The search field changes the place.
AppWindow {
    id: app
    appName: "Weather"
    appIcon: 0xf0595
    searchable: true
    searchHint: "Change the place"
    implicitWidth: 1060; implicitHeight: 780

    property var w: null
    property string place: ""
    property string error: ""
    readonly property bool f: Prefs.weatherUnits === "f"
    function deg(c) { return Math.round(f ? c * 9 / 5 + 32 : c) + "°"; }

    Cmd {
        id: fetch
        command: ["sh", "-c", `
c="$1"; [ -n "$c" ] || c=$(readlink /etc/localtime | sed 's|.*/||; s|_| |g')
g=$(curl -fsS --max-time 8 "https://geocoding-api.open-meteo.com/v1/search?count=1&name=$(printf %s "$c" | jq -sRr @uri)") || exit 2
lat=$(printf %s "$g" | jq -r '.results[0].latitude // empty'); [ -n "$lat" ] || exit 3
lon=$(printf %s "$g" | jq -r '.results[0].longitude'); name=$(printf %s "$g" | jq -r '[.results[0].name, .results[0].country] | map(select(. != null)) | join(", ")')
f=$(curl -fsS --max-time 8 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,relative_humidity_2m,is_day&hourly=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max&timezone=auto&forecast_days=7") || exit 2
printf '%s\\n%s\\n' "$name" "$f"`, "sh", app.place || Prefs.weatherCity]
        onDone: (out, code) => {
            if (code === 3) { app.error = Tr.t("No place with that name"); return; }
            if (code !== 0) { app.error = Tr.t("No internet - the weather needs it"); return; }
            const nl = out.indexOf("\n");
            try { const j = JSON.parse(out.slice(nl + 1)); j.place = out.slice(0, nl); app.w = j; app.error = ""; } catch (e) { app.error = Tr.t("The weather service did not answer"); }
        }
    }
    Component.onCompleted: fetch.run()
    Timer { interval: 30 * 60000; repeat: true; running: true; onTriggered: fetch.run() }
    onSearchAccepted: { place = app.search.trim(); if (place) { Prefs.weatherCity = place; fetch.run(); } }

    readonly property var names: ({ 0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Cloudy", 45: "Fog", 48: "Fog", 51: "Drizzle", 53: "Drizzle", 55: "Drizzle",
        56: "Freezing drizzle", 57: "Freezing drizzle", 61: "Rain", 63: "Rain", 65: "Heavy rain", 66: "Freezing rain", 67: "Freezing rain", 71: "Snow", 73: "Snow", 75: "Heavy snow",
        77: "Snow", 80: "Showers", 81: "Showers", 82: "Heavy showers", 85: "Snow showers", 86: "Snow showers", 95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm" })
    function icon(code, day) {
        if (code === 0 || code === 1) return day === 0 ? 0xf0594 : 0xf0599;
        if (code === 2) return day === 0 ? 0xf0594 : 0xf0595;
        if (code === 3) return 0xf0590;
        if (code === 45 || code === 48) return 0xf0591;
        if (code >= 51 && code <= 67) return code >= 65 ? 0xf0596 : 0xf0597;
        if (code >= 71 && code <= 77 || code === 85 || code === 86) return 0xf0598;
        if (code >= 80 && code <= 82) return 0xf0596;
        if (code >= 95) return 0xf0593;
        return 0xf0590;
    }
    function compass(d) { return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(d / 45) % 8]; }
    function uvText(u) { return u < 3 ? Tr.t("low") : u < 6 ? Tr.t("moderate") : u < 8 ? Tr.t("high") : Tr.t("very high"); }
    function hm(iso) { return iso ? iso.slice(11, 16) : "-"; }

    Flickable {
        anchors { fill: parent; margins: 28; topMargin: 20 }
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: parent.width
            spacing: 20
            Text { visible: app.error !== ""; text: app.error; font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.warn }
            Text { visible: !app.w && !app.error; text: Tr.t("Getting the weather..."); font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.muted }

            // now + details
            Item {
                visible: app.w !== null
                width: parent.width; height: 210
                Column {
                    spacing: 4
                    Row { spacing: 8
                        Text { text: String.fromCodePoint(0xf034e); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: app.w ? app.w.place : ""; font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.muted } }
                    Row { spacing: 16
                        Text { text: app.w ? app.deg(app.w.current.temperature_2m) : ""; font.family: Theme.font; font.pixelSize: Theme.px(104); font.weight: Font.Light; color: Theme.text }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: app.w ? String.fromCodePoint(app.icon(app.w.current.weather_code, app.w.current.is_day)) : ""; font.family: Theme.symbols; font.pixelSize: Theme.px(56); color: Theme.accent } }
                    Text { text: app.w ? Tr.t(app.names[app.w.current.weather_code] || "") : ""; font.family: Theme.font; font.pixelSize: Theme.px(22); color: Theme.text }
                    Text { text: app.w ? Tr.f("Feels like {f} · H {h} L {l}", { f: app.deg(app.w.current.apparent_temperature), h: app.deg(app.w.daily.temperature_2m_max[0]), l: app.deg(app.w.daily.temperature_2m_min[0]) }) : ""
                           font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
                }
                Grid {
                    anchors.right: parent.right
                    columns: 2; columnSpacing: 14; rowSpacing: 12
                    Repeater {
                        model: app.w ? [["Wind", Math.round(app.w.current.wind_speed_10m) + " km/h " + app.compass(app.w.current.wind_direction_10m)], ["Humidity", app.w.current.relative_humidity_2m + " %"],
                                        ["Rain", (app.w.daily.precipitation_probability_max[0] || 0) + " %"], ["UV index", Math.round(app.w.daily.uv_index_max[0] || 0) + " · " + app.uvText(app.w.daily.uv_index_max[0] || 0)],
                                        ["Sunrise", app.hm(app.w.daily.sunrise[0])], ["Sunset", app.hm(app.w.daily.sunset[0])]] : []
                        delegate: Rectangle {
                            required property var modelData
                            width: 196; height: 58; radius: 14
                            color: Theme.fill; border.width: 1; border.color: Theme.glassLine
                            Column { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } spacing: 4
                                Text { text: Tr.t(modelData[0]); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                                Text { text: modelData[1]; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text } }
                        }
                    }
                }
            }

            // the next 24 hours
            Text { visible: app.w !== null; text: Tr.t("NEXT 24 HOURS"); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
            Rectangle {
                visible: app.w !== null
                width: parent.width; height: 116; radius: 18
                color: Theme.fill; border.width: 1; border.color: Theme.glassLine
                ListView {
                    anchors { fill: parent; margins: 8 }
                    orientation: ListView.Horizontal
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int start: { if (!app.w) return 0; const now = app.w.current.time.slice(0, 13); const i = app.w.hourly.time.findIndex(t => t.slice(0, 13) === now); return Math.max(0, i); }
                    model: app.w ? 24 : 0
                    delegate: Column {
                        required property int index
                        readonly property int i: ListView.view.start + index
                        width: 76
                        spacing: 8
                        topPadding: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? Tr.t("Now") : app.w.hourly.time[i].slice(11, 13); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(app.icon(app.w.hourly.weather_code[i], app.w.hourly.is_day[i])); font.family: Theme.symbols; font.pixelSize: Theme.px(24); color: Theme.text }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.deg(app.w.hourly.temperature_2m[i]); font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
                    }
                }
            }

            // 7 days
            Text { visible: app.w !== null; text: Tr.t("NEXT 7 DAYS"); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
            Rectangle {
                visible: app.w !== null
                width: parent.width; height: days.implicitHeight + 12; radius: 18
                color: Theme.fill; border.width: 1; border.color: Theme.glassLine
                readonly property real lo: app.w ? Math.min.apply(null, app.w.daily.temperature_2m_min) : 0
                readonly property real hi: app.w ? Math.max.apply(null, app.w.daily.temperature_2m_max) : 1
                Column {
                    id: days
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
                    Repeater {
                        model: app.w ? app.w.daily.time.length : 0
                        delegate: Item {
                            required property int index
                            width: days.width; height: 52
                            Rectangle { visible: index > 0; anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16 } height: 1; color: Theme.glassLine }
                            Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: index === 0 ? Tr.t("Today") : Tr.date(new Date(app.w.daily.time[index] + "T12:00"), "ddd"); font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.text }
                            Text { x: 110; anchors.verticalCenter: parent.verticalCenter; text: String.fromCodePoint(app.icon(app.w.daily.weather_code[index], 1)); font.family: Theme.symbols; font.pixelSize: Theme.px(20); color: Theme.text }
                            Text { x: 150; anchors.verticalCenter: parent.verticalCenter; text: Tr.t(app.names[app.w.daily.weather_code[index]] || ""); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                            Text { anchors { right: bar.left; rightMargin: 12; verticalCenter: parent.verticalCenter } text: app.deg(app.w.daily.temperature_2m_min[index]); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
                            Rectangle {
                                id: bar
                                anchors { right: parent.right; rightMargin: 72; verticalCenter: parent.verticalCenter }
                                width: 260; height: 6; radius: 3
                                color: Theme.ink(0.10)
                                readonly property real span: Math.max(1, parent.parent.parent.hi - parent.parent.parent.lo)
                                Rectangle {
                                    x: parent.width * (app.w.daily.temperature_2m_min[index] - parent.parent.parent.parent.lo) / parent.span
                                    width: Math.max(6, parent.width * (app.w.daily.temperature_2m_max[index] - app.w.daily.temperature_2m_min[index]) / parent.span)
                                    height: parent.height; radius: 3
                                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.accent } GradientStop { position: 1; color: "#ffd08f" } }
                                }
                            }
                            Text { anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter } text: app.deg(app.w.daily.temperature_2m_max[index]); font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.text }
                        }
                    }
                }
            }
            Row {
                visible: app.w !== null
                spacing: 8
                Segmented { width: 200; options: ["°C", "°F"]; current: app.f ? 1 : 0; onPicked: i => Prefs.weatherUnits = i ? "f" : "c" }
                Text { anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Data: Open-Meteo · no account, no tracking"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim }
            }
        }
    }
}
