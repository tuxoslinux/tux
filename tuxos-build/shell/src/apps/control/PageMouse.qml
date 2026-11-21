import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.theme
import qs.components

// Mouse & touchpad: pointer speed, natural scrolling, tap to click,
// gestures (3 fingers left / right = desktops, up = Mission Control).
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Mouse & touchpad"); description: Tr.t("Pointer speed, scrolling and touchpad gestures.") }
    property real speed: 0
    property bool natural: false
    property bool tap: true
    property bool hideTyping: true
    property bool shake: true
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/hypr/mouse.lua"
        printErrors: false
        onLoaded: {
            const t = text();
            const s = /sensitivity = (-?[\d.]+)/.exec(t); if (s) page.speed = parseFloat(s[1]);
            page.natural = /natural_scroll = true/.test(t); page.tap = !/tap_to_click = false/.test(t);
            page.hideTyping = !/hide_on_key_press = false/.test(t); page.shake = !/tux_shake = false/.test(t);
        }
    }
    function save() {
        const cfg = `input = { sensitivity = ${speed.toFixed(2)}, touchpad = { natural_scroll = ${natural}, tap_to_click = ${tap} } }, cursor = { hide_on_key_press = ${hideTyping} }`;
        file.setText(`-- written by TuxOS Control > Mouse & touchpad\nhl.config({ ${cfg} })\ntux_shake = ${shake}\n`);
        Hyprland.dispatch(`(function() hl.config({ ${cfg} }); tux_shake = ${shake}; return hl.dsp.no_op() end)()`);
    }
    SettingCard {
        SettingRow { title: Tr.t("Pointer speed"); Slider { width: 260; value: (page.speed + 1) / 2; onMoved: v => { page.speed = v * 2 - 1; page.save(); } } }
        SettingRow { title: Tr.t("Natural scrolling"); description: Tr.t("Content moves with your fingers (touchpad)"); Toggle { checked: page.natural; onToggled: v => { page.natural = v; page.save(); } } }
        SettingRow { title: Tr.t("Tap to click"); description: Tr.t("Touchpad"); last: true; Toggle { checked: page.tap; onToggled: v => { page.tap = v; page.save(); } } }
    }
    SettingCard {
        header: Tr.t("Pointer")
        SettingRow { title: Tr.t("Hide the pointer while typing"); description: Tr.t("It comes back as soon as the mouse moves"); Toggle { checked: page.hideTyping; onToggled: v => { page.hideTyping = v; page.save(); } } }
        SettingRow { title: Tr.t("Shake to find the pointer"); description: Tr.t("Move the mouse quickly left and right: the pointer grows for a moment"); last: true; Toggle { checked: page.shake; onToggled: v => { page.shake = v; page.save(); } } }
    }
    // ---- gaming mice (libratbag / ratbagd: Logitech, SteelSeries, Roccat ...)
    property var mice: []                // [{ id, name }]
    property var mouse: null             // { profiles, profile, rate, rates, dpi, dpis, buttons: [actions] }
    property bool hasRatbag: false
    Cmd {
        id: listMice
        command: ["sh", "-c", "command -v ratbagctl >/dev/null || exit 3; ratbagctl list 2>/dev/null"]
        Component.onCompleted: run()
        onDone: (out, code) => {
            page.hasRatbag = code !== 3;
            page.mice = out.split("\n").map(l => /^([a-z0-9-]+):\s+(.*)$/.exec(l.trim())).filter(m => m).map(m => ({ id: m[1], name: m[2] }));
            if (page.mice.length) { infoMouse.command = ["sh", "-c", "ratbagctl \"$1\" info; echo @@; ratbagctl \"$1\" rate get-all; echo @@; ratbagctl \"$1\" dpi get-all", "sh", page.mice[0].id]; Qt.callLater(infoMouse.run); }
        }
    }
    Cmd {
        id: infoMouse
        onDone: out => {
            const [info, rates, dpis] = out.split("@@");
            const m = { profiles: 1, profile: 0, rate: 0, rates: [], dpi: 0, dpis: [], buttons: [] };
            const np = /Number of Profiles:\s*(\d+)/.exec(info); if (np) m.profiles = parseInt(np[1]);
            const ap = /Profile (\d+): \(active\)/.exec(info); if (ap) m.profile = parseInt(ap[1]);
            // the active profile's part only
            const part = info.split(/Profile \d+:/)[m.profile + 1] || info;
            const rr = /Report Rate:\s*(\d+)Hz/.exec(part); if (rr) m.rate = parseInt(rr[1]);
            const ad = /(\d+)dpi \(active\)/.exec(part); if (ad) m.dpi = parseInt(ad[1]);
            const bre = /Button: (\d+) is mapped to '([^']*)'/g; let b;
            while ((b = bre.exec(part)) !== null) m.buttons.push(b[2]);
            m.rates = (rates || "").trim().split(/\s+/).map(Number).filter(x => x > 0);
            const all = (dpis || "").trim().split(/\s+/).map(x => parseInt(x)).filter(x => x > 0);
            // a handful of usual steps the mouse supports
            m.dpis = [400, 800, 1200, 1600, 3200, 6400].filter(v => all.length === 0 || all.indexOf(v) !== -1 || (v >= all[0] && v <= all[all.length - 1]));
            page.mouse = m;
        }
    }
    function ratbag(args) {
        Quickshell.execDetached(["sh", "-c", "ratbagctl \"$@\" >/dev/null 2>&1", "sh", mice[0].id].concat(args));
        Qt.callLater(() => { infoMouse.running = false; infoMouse.run(); });
    }
    readonly property var actions: [["button 1", "Left click"], ["button 2", "Right click"], ["button 3", "Middle click"], ["button 4", "Back"], ["button 5", "Forward"], ["special resolution-cycle-up", "Next DPI step"], ["special profile-cycle-up", "Next profile"]]
    SettingCard {
        header: Tr.t("Gaming mouse")
        SettingRow {
            title: page.mice.length ? page.mice[0].name : Tr.t("No gaming mouse found")
            description: !page.hasRatbag ? Tr.t("Needs libratbag (from the TuxOS repositories)") : page.mice.length ? Tr.t("DPI, polling rate, buttons and on-board profiles (libratbag)") : Tr.t("Logitech, SteelSeries, Roccat and other supported mice show up here")
            last: !page.mouse
            Row {
                spacing: 8
                Btn { visible: !page.hasRatbag; text: Tr.t("Install"); primary: true; onClicked: Quickshell.execDetached(["sh", "-c", "pkexec tuxos-pkg install libratbag && notify-send 'libratbag is installed' 'Gaming mice show up in Settings > Mouse & touchpad'"]) }
                Btn { visible: page.hasRatbag; text: Tr.t("Look again"); onClicked: listMice.run() }
            }
        }
        SettingRow {
            visible: page.mouse !== null && page.mouse.profiles > 1
            title: Tr.t("Profile"); description: Tr.t("Stored on the mouse")
            Segmented { width: Math.min(360, 64 * (page.mouse ? page.mouse.profiles : 1)); options: page.mouse ? Array.from({ length: page.mouse.profiles }, (_, i) => String(i + 1)) : []; current: page.mouse ? page.mouse.profile : 0; onPicked: i => page.ratbag(["profile", "active", "set", String(i)]) }
        }
        SettingRow {
            visible: page.mouse !== null
            title: Tr.t("Sensitivity"); description: page.mouse ? page.mouse.dpi + " DPI" : ""
            Segmented { width: 420; options: page.mouse ? page.mouse.dpis.map(String) : []; current: page.mouse ? page.mouse.dpis.indexOf(page.mouse.dpi) : -1; onPicked: i => page.ratbag(["dpi", "set", String(page.mouse.dpis[i])]) }
        }
        SettingRow {
            visible: page.mouse !== null && page.mouse.rates.length > 0
            title: Tr.t("Polling rate"); description: Tr.t("Higher is smoother, uses a little more power")
            Segmented { width: 360; options: page.mouse ? page.mouse.rates.map(r => r + " Hz") : []; current: page.mouse ? page.mouse.rates.indexOf(page.mouse.rate) : -1; onPicked: i => page.ratbag(["rate", "set", String(page.mouse.rates[i])]) }
        }
        Repeater {
            model: page.mouse ? page.mouse.buttons : []
            delegate: SettingRow {
                required property string modelData
                required property int index
                title: Tr.f("Button {n}", { n: index + 1 })
                last: index === page.mouse.buttons.length - 1
                ChoiceList {
                    options: page.actions.map(a => ({ value: a[0], label: Tr.t(a[1]) })).concat(page.actions.some(a => a[0] === modelData) ? [] : [{ value: modelData, label: modelData }])
                    current: modelData
                    onPicked: v => page.ratbag(["button", String(index), "action", "set"].concat(v.split(" ")))
                }
            }
        }
    }
    SettingCard {
        header: Tr.t("Gestures (touchpad)")
        SettingRow { title: Tr.t("Three fingers left / right"); description: Tr.t("Previous / next desktop") }
        SettingRow { title: Tr.t("Three fingers up"); description: Tr.t("Mission Control") }
        SettingRow { title: Tr.t("Pinch in (3 or 4 fingers)"); description: Tr.t("App launcher"); last: true }
    }
}
