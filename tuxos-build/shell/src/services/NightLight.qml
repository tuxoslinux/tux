pragma Singleton

import QtQuick
import Quickshell
import qs.theme

// Night light (Settings > Appearance): warmer colours through hyprsunset.
// "on": warm all the time; "sunset": fades in over 30 minutes after sunset
// (the weather place's sunset, else 19:00) and ends at sunrise; "off": the
// screen's own colours and hyprsunset is not running.
Singleton {
    id: nl

    readonly property int warm: 4000
    readonly property int neutral: 6500
    property int applied: -1                // last temperature sent, 0 = identity

    function target(now) {
        const mode = Prefs.nightLight;
        if (mode === "on") return warm;
        if (mode !== "sunset") return 0;
        const d = new Date(now);
        const loc = Prefs.location;
        const t = loc && loc.lat !== undefined ? Theme.sunTimes(d, loc.lat, loc.lon) : [420, 1140];
        const m = d.getHours() * 60 + d.getMinutes();
        if (m >= t[0] && m < t[1]) return 0;                    // day
        const since = m >= t[1] ? m - t[1] : m + 1440 - t[1];   // minutes since sunset
        const f = Math.min(1, since / 30);
        return Math.round((neutral - (neutral - warm) * f) / 50) * 50;
    }
    function apply(now) {
        const k = target(now || Date.now());
        if (k === applied) return;
        applied = k;
        if (k === 0)
            Quickshell.execDetached(["sh", "-c", "pgrep -x hyprsunset >/dev/null || exit 0; hyprctl hyprsunset identity >/dev/null 2>&1; pkill -x hyprsunset"]);
        else
            Quickshell.execDetached(["sh", "-c", "pgrep -x hyprsunset >/dev/null || { hyprsunset -i >/dev/null 2>&1 & sleep 0.6; }; hyprctl hyprsunset temperature \"$1\" >/dev/null", "sh", String(k)]);
    }
    function start() { apply(); }
    Connections { target: Tick; function onMinute(t) { nl.apply(t); } }
    Connections { target: Prefs; function onNightLightChanged() { nl.apply(); } function onLocationChanged() { nl.apply(); } }
}
