pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Today's weather for the clock droplet (and the Weather app): Open-Meteo
// (free, no account, no tracking). The place comes from Settings
// (weatherCity); without one, from the time zone's city. Fetched at most
// every 30 minutes and only when someone looks.
Singleton {
    id: w

    property string city: ""
    property real temp: NaN
    property real high: NaN
    property real low: NaN
    property int code: -1
    property double fetchedAt: 0
    readonly property bool ready: !isNaN(temp)

    readonly property var codes: ({
        0: ["Clear", Icons.whiteBalanceSunny], 1: ["Mostly clear", Icons.whiteBalanceSunny], 2: ["Partly cloudy", Icons.weatherPartlyCloudy],
        3: ["Cloudy", Icons.weatherPartlyCloudy], 45: ["Fog", Icons.weatherPartlyCloudy], 48: ["Fog", Icons.weatherPartlyCloudy],
        51: ["Drizzle", Icons.weatherPartlyCloudy], 53: ["Drizzle", Icons.weatherPartlyCloudy], 55: ["Drizzle", Icons.weatherPartlyCloudy],
        61: ["Rain", Icons.weatherPartlyCloudy], 63: ["Rain", Icons.weatherPartlyCloudy], 65: ["Heavy rain", Icons.weatherPartlyCloudy],
        71: ["Snow", Icons.weatherPartlyCloudy], 73: ["Snow", Icons.weatherPartlyCloudy], 75: ["Heavy snow", Icons.weatherPartlyCloudy],
        80: ["Showers", Icons.weatherPartlyCloudy], 81: ["Showers", Icons.weatherPartlyCloudy], 82: ["Heavy showers", Icons.weatherPartlyCloudy],
        95: ["Thunderstorm", Icons.lightningBolt], 96: ["Thunderstorm", Icons.lightningBolt], 99: ["Thunderstorm", Icons.lightningBolt]
    })
    readonly property string condition: codes[code] ? Tr.t(codes[code][0]) : ""
    readonly property int icon: codes[code] ? codes[code][1] : Icons.weatherPartlyCloudy

    Process {
        id: proc
        // city -> coordinates (Open-Meteo geocoding), then the forecast
        command: ["sh", "-c", `
c="$1"
[ -n "$c" ] || c=$(readlink /etc/localtime | sed 's|.*/||; s|_| |g')
g=$(curl -fsS --max-time 6 "https://geocoding-api.open-meteo.com/v1/search?count=1&name=$(printf %s "$c" | sed 's/ /%20/g')") || exit 1
lat=$(printf %s "$g" | jq -r '.results[0].latitude'); lon=$(printf %s "$g" | jq -r '.results[0].longitude'); name=$(printf %s "$g" | jq -r '.results[0].name')
f=$(curl -fsS --max-time 6 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1") || exit 1
printf '%s\\n%s %s\\n%s\\n' "$name" "$lat" "$lon" "$f"`, "sh", Prefs.weatherCity]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n");
                if (parts.length < 3) return;
                try {
                    const j = JSON.parse(parts.slice(2).join("\n"));
                    w.city = parts[0];
                    // the place's coordinates: light mode "auto" follows its sunrise / sunset
                    const ll = parts[1].split(" ").map(Number);
                    if (!isNaN(ll[0]) && (!Prefs.location || Prefs.location.lat !== ll[0])) Prefs.location = { lat: ll[0], lon: ll[1] };
                    w.temp = j.current.temperature_2m;
                    w.code = j.current.weather_code;
                    w.high = j.daily.temperature_2m_max[0];
                    w.low = j.daily.temperature_2m_min[0];
                    w.fetchedAt = Date.now();
                } catch (e) {}
            }
        }
    }
    function refresh() {
        if (proc.running || Date.now() - fetchedAt < 30 * 60000) return;
        proc.running = true;
    }
}
