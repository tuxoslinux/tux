pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.theme

// Smart power (SPEC round 6) and battery-aware motion (SPEC Polish):
// - power saver below 20 % battery, Balanced on battery, the chosen profile
//   on AC (Performance by default, also on desktops); game mode always
//   wins (tuxos-gamed switches to Performance while a game runs). Only on
//   changes (plugging in / out, crossing 20 %), so a profile picked by hand
//   stays until the next change.
// - on battery, screens faster than 60 Hz drop to 60 Hz (animations and
//   everything else draw at 60), and go back to their own rate on AC.
// The "test" IPC target fakes a battery for checks on PCs without one.
Singleton {
    id: sp

    property var fake: null                 // { pct, ac } from the test hook
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: fake !== null || (dev !== null && dev.isLaptopBattery && dev.isPresent)
    readonly property bool onBattery: fake !== null ? !fake.ac : (hasBattery && UPower.onBattery)
    readonly property int pct: fake !== null ? fake.pct : (hasBattery ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 100)
    readonly property bool gaming: Notifs.gameRunning
    readonly property string want: !Prefs.smartPower || gaming ? "" : !hasBattery ? Prefs.acProfile
                                   : !onBattery ? Prefs.acProfile : (pct < 20 ? "power-saver" : "balanced")
    property string applied: ""
    onWantChanged: apply()
    Component.onCompleted: Qt.callLater(apply)
    function apply() {
        if (!want || want === applied) return;
        applied = want;
        Profiles.set(want);
    }

    // ---- 60 Hz on battery
    property var saved: ({})                // monitor -> "WxH@R"
    readonly property bool cap60: Prefs.battery60 && hasBattery && onBattery
    onCap60Changed: refreshRates()
    Process {
        id: mons
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []; try { list = JSON.parse(text); } catch (e) { return; }
                const s = Object.assign({}, sp.saved);
                let lua = "";
                for (const m of list) {
                    if (m.disabled) continue;
                    const pos = `${m.x}x${m.y}`;
                    if (sp.cap60) {
                        if (m.refreshRate <= 61) continue;
                        const has60 = (m.availableModes || []).some(md => md.startsWith(`${m.width}x${m.height}@`) && Math.abs(parseFloat(md.split("@")[1]) - 60) < 1.5);
                        if (!has60) continue;
                        s[m.name] = `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`;
                        lua += `hl.monitor({ output = "${m.name}", mode = "${m.width}x${m.height}@60", position = "${pos}", scale = ${m.scale} }); `;
                    } else if (s[m.name]) {
                        lua += `hl.monitor({ output = "${m.name}", mode = "${s[m.name]}", position = "${pos}", scale = ${m.scale} }); `;
                        delete s[m.name];
                    }
                }
                sp.saved = s;
                if (lua) Shell.dispatch(`(function() ${lua} return hl.dsp.no_op() end)()`, "");
            }
        }
    }
    function refreshRates() { if (!mons.running) mons.running = true; }

    IpcHandler {
        target: "test"
        // tests on PCs without a battery: qs -c tuxos ipc call test battery 15 false
        function battery(pct: int, ac: bool): void { sp.fake = { pct: pct, ac: ac }; }
        function noBattery(): void { sp.fake = null; }
        function state(): string { return JSON.stringify({ hasBattery: sp.hasBattery, onBattery: sp.onBattery, pct: sp.pct, want: sp.want, applied: sp.applied, cap60: sp.cap60, saved: sp.saved }); }
    }
}
