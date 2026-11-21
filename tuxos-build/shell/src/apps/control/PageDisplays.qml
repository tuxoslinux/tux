import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.theme
import qs.components

// Displays: each monitor's resolution and refresh rate, scale, VRR. Saved
// to ~/.config/hypr/monitors.lua (hyprland.lua loads it) and applied at once.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Displays"); description: Tr.t("Resolution, refresh rate, scale and VRR for each screen.") }
    property var mons: []
    Cmd {
        id: read
        command: ["hyprctl", "-j", "monitors"]
        Component.onCompleted: run()
        onDone: out => { try { page.mons = JSON.parse(out); } catch (e) {} }
    }
    // Lua lines for every monitor, then apply them in the running Hyprland
    property var saved: ({})
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/hypr/monitors.lua"
        printErrors: false
        // what was saved before (every monitor keeps its line)
        onLoaded: {
            const s = {};
            for (const l of text().split("\n")) {
                const m = /output = "([^"]+)", mode = "([^"]+)", position = "auto", scale = ([\d.]+), vrr = (\d)/.exec(l);
                if (m) s[m[1]] = { mode: m[2], scale: parseFloat(m[3]), vrr: parseInt(m[4]), hdr: /cm = "hdr"/.test(l) };
            }
            page.saved = s;
        }
    }
    function line(n, e) {
        // HDR (beta): Hyprland's HDR colour mode, 10 bits per colour
        const hdr = e.hdr ? `, cm = "hdr", bitdepth = 10` : "";
        return `hl.monitor({ output = "${n}", mode = "${e.mode}", position = "auto", scale = ${e.scale}, vrr = ${e.vrr}${hdr} })`;
    }
    function apply(name, mode, scale, vrr, hdr) {
        const s = Object.assign({}, saved);
        const was = s[name] || {};
        s[name] = { mode: mode, scale: scale, vrr: vrr, hdr: hdr === undefined ? !!was.hdr : hdr };
        saved = s;
        let lua = "-- written by TuxOS Control > Displays\n";
        for (const n in s) lua += line(n, s[n]) + "\n";
        file.setText(lua);
        Hyprland.dispatch(`(function() ${line(name, s[name])}; return hl.dsp.no_op() end)()`);
        later.restart();
    }
    Timer { id: later; interval: 800; onTriggered: read.run() }

    Repeater {
        model: page.mons
        delegate: SettingCard {
            id: mcard
            required property var modelData
            header: modelData.description || modelData.name
            readonly property string mode: `${modelData.width}x${modelData.height}@${Math.round(modelData.refreshRate * 100) / 100}`
            SettingRow {
                title: Tr.t("Resolution and refresh rate")
                description: `${modelData.width} × ${modelData.height} at ${Math.round(modelData.refreshRate)} Hz`
                ChoiceList {
                    width: 260
                    options: (modelData.availableModes || []).map(m => ({ value: m.replace("Hz", ""), label: m.replace("@", " · ").replace(/(\d+)\.\d+Hz/, "$1 Hz") }))
                    current: mcard.mode
                    onPicked: v => page.apply(modelData.name, v, modelData.scale, modelData.vrr ? 2 : 0)
                }
            }
            SettingRow {
                title: Tr.t("Scale"); description: Tr.t("Bigger text and controls on high-resolution screens")
                Segmented { width: 320; options: ["100 %", "125 %", "150 %", "200 %"]; current: [1, 1.25, 1.5, 2].indexOf(modelData.scale)
                    onPicked: i => page.apply(modelData.name, mcard.mode, [1, 1.25, 1.5, 2][i], modelData.vrr ? 2 : 0) }
            }
            SettingRow {
                title: Tr.t("Variable refresh rate (VRR)"); description: Tr.t("Smooth games without tearing on FreeSync / G-Sync screens")
                Toggle { checked: modelData.vrr === true; onToggled: v => page.apply(modelData.name, mcard.mode, modelData.scale, v ? 2 : 0) }
            }
            SettingRow {
                title: Tr.t("HDR (beta)"); last: true
                description: Tr.t("For HDR screens: brighter highlights in HDR games and videos (turn HDR on in the game too). Hyprland's HDR is still experimental.")
                Toggle { checked: !!(page.saved[modelData.name] || {}).hdr; onToggled: v => page.apply(modelData.name, mcard.mode, modelData.scale, modelData.vrr ? 2 : 0, v) }
            }
        }
    }
}
