pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// TuxOS design tokens: the one place for colours, sizes and timings.
// Every surface reads from here (SPEC.md "Look").
Singleton {
    id: theme
    // the user's choices from ~/.config/tuxos/shell.json (TuxOS Control >
    // Appearance / Accessibility); every surface follows them live
    property var user: ({})
    FileView {
        path: Quickshell.env("HOME") + "/.config/tuxos/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { theme.user = JSON.parse(text()); } catch (e) {} }
    }

    // ---- modes (Appearance / Accessibility)
    // light: "light", or "auto" = light between sunrise and sunset (from the
    // weather place when known, else 07:00-19:00)
    property bool daytime: true
    function sunTimes(d, lat, lon) {
        // NOAA sunrise equation, minutes after local midnight
        const rad = Math.PI / 180;
        const start = new Date(d.getFullYear(), 0, 0);
        const n = Math.floor((d - start) / 86400000);
        const g = 2 * Math.PI / 365 * (n - 1);
        const eq = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g) - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
        const decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
        const c = (Math.cos(90.833 * rad) / (Math.cos(lat * rad) * Math.cos(decl))) - Math.tan(lat * rad) * Math.tan(decl);
        if (c > 1) return [720, 720];       // polar night
        if (c < -1) return [0, 1440];       // midnight sun
        const ha = Math.acos(c) / rad;
        const tz = -d.getTimezoneOffset();
        return [720 - 4 * (lon + ha) - eq + tz, 720 - 4 * (lon - ha) - eq + tz];
    }
    function checkDaytime() {
        const d = new Date();
        const loc = user.location;
        const t = loc && loc.lat !== undefined ? sunTimes(d, loc.lat, loc.lon) : [420, 1140];
        const m = d.getHours() * 60 + d.getMinutes();
        daytime = m >= t[0] && m < t[1];
    }
    Timer {
        running: theme.user.lightMode === "auto"
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: theme.checkDaytime()
    }
    readonly property bool light: user.lightMode === "light" || (user.lightMode === "auto" && daytime)
    readonly property bool contrast: user.highContrast === true
    // lite: solid glass, shorter animations (old GPUs, software rendering,
    // 4 GB of RAM or less; "auto" decides from the hardware, see autoLite)
    property bool autoLite: false
    readonly property bool lite: user.lite === "on" || (user.lite !== "off" && autoLite)
    Process {
        running: true
        command: ["sh", "-c", "m=$(awk '/MemTotal/{print $2}' /proc/meminfo); [ \"$m\" -le 4300000 ] && { echo lite; exit; }; ls /dev/dri/renderD* >/dev/null 2>&1 || { echo lite; exit; }; true"]
        stdout: StdioCollector { onStreamFinished: theme.autoLite = text.indexOf("lite") !== -1 }
    }

    // ink: the colour of text and of the faint fills on the glass (white on
    // dark glass, near-black on light glass); a = strength
    function ink(a) { return light ? Qt.rgba(16 / 255, 20 / 255, 28 / 255, Math.min(1, a * 1.1)) : Qt.rgba(1, 1, 1, a); }
    // text size (Accessibility): every font size goes through px()
    function px(n) { return Math.round(n * textScale); }

    // colours
    // the user's accent; while music plays it can ease to a colour from the
    // album art (accent from album art: accentOverride, the shell only)
    readonly property color baseAccent: user.accent || "#8fb8ff"
    property color accentOverride: "transparent"
    property color accent: accentOverride.a > 0 ? accentOverride : baseAccent
    Behavior on accent { ColorAnimation { duration: 600 } }
    readonly property color accentDeep: "#5b8def"
    readonly property color accentInk: "#0b1424"
    readonly property color text: light ? "#10141c" : "#f4f7fb"
    readonly property color muted: light ? (contrast ? "#2c3340" : "#566070") : (contrast ? "#c4ccd8" : "#8b95a5")
    readonly property color dim: light ? "#98a1af" : (contrast ? "#7d8696" : "#4c5463")
    readonly property color danger: light ? "#d6334a" : "#ff7a8a"
    readonly property color warn: light ? "#d9562b" : "#ff8a65"
    readonly property color good: light ? "#23845a" : "#7fd6a0"

    // the one glass: the compositor blurs what is behind, we add tint + edge;
    // high contrast and lite make it (nearly) solid
    // lite has no blur, so its glass is solid (no text from behind shows through)
    readonly property real glassStrength: lite ? 1.0 : (contrast ? 0.94 : Math.max(0.4, Math.min(0.95, user.glass || 0.62)))
    readonly property color glassBase: light ? Qt.rgba(246 / 255, 248 / 255, 252 / 255, 1) : Qt.rgba(10 / 255, 12 / 255, 16 / 255, 1)
    readonly property color glass: Qt.rgba(glassBase.r, glassBase.g, glassBase.b, lite ? 1.0 : Math.min(0.97, glassStrength - 0.07))
    readonly property color glassPanel: Qt.rgba(glassBase.r, glassBase.g, glassBase.b, Math.min(1.0, glassStrength + (light ? 0.08 : 0)))
    readonly property color glassLine: light ? Qt.rgba(20 / 255, 40 / 255, 80 / 255, contrast ? 0.45 : 0.12) : Qt.rgba(210 / 255, 225 / 255, 1, contrast ? 0.42 : 0.10)
    readonly property color glassHighlight: light ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.035)
    readonly property color fill: ink(0.04)
    readonly property color fillHover: ink(0.08)
    readonly property color accentFill: Qt.rgba(accent.r, accent.g, accent.b, light ? 0.22 : 0.12)
    readonly property color accentLine: Qt.rgba(accent.r, accent.g, accent.b, light ? 0.5 : 0.28)

    // type
    readonly property string font: "Adwaita Sans"
    readonly property string symbols: "JetBrainsMono Nerd Font"

    // geometry
    readonly property int edge: 12          // bar / dock distance from the screen sides
    readonly property int barTop: 10
    readonly property int barHeight: 46
    // roundness (Appearance): small / medium / large
    readonly property real round: user.roundness === "small" ? 0.45 : (user.roundness === "medium" ? 0.72 : 1.0)
    readonly property int barRadius: Math.round(16 * round)
    readonly property int itemHeight: 34
    readonly property int itemRadius: Math.round(11 * round)
    readonly property int panelRadius: Math.round(28 * round)

    // motion (one curve everywhere; "reduce motion" sets durations to 0)
    readonly property bool reduceMotion: user.reduceMotion === true || user.animations === false
    readonly property real textScale: user.textScale || 1.0
    // SPEC "One motion system": 120-250 ms, one curve. Movement and size
    // use the spring (components/Spring.qml, ~220 ms); timed changes
    // (fades, sequences) use these durations and Hyprland's "tux" curve.
    readonly property int fast: reduceMotion ? 0 : (lite ? 90 : 120)
    readonly property int medium: reduceMotion ? 0 : (lite ? 140 : 200)
    readonly property int slow: reduceMotion ? 0 : (lite ? 180 : 250)
    readonly property real springStiffness: lite ? 20 : 16
    readonly property real springDamping: lite ? 0.95 : 0.9
    // the same bezier as Hyprland's "tux" curve (fast start, soft end)
    readonly property var bezier: [0.22, 1, 0.36, 1, 1, 1]
    // opacity changes stay as short fades even with Reduce motion (SPEC:
    // movement becomes fades)
    readonly property int fade: reduceMotion ? 160 : medium
}
