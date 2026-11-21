import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.theme

// Shell shortcuts (SPEC "Keyboard shortcuts"). Hyprland owns the keys
// (hyprland.lua binds them to hl.dsp.global("tuxos:<name>")); the shell
// receives them here through the global-shortcuts protocol. The same
// actions are reachable from scripts: qs -c tuxos ipc call shell <name>.
Scope {
    id: keys

    function run(name) {
        switch (name) {
        case "launcher":
        case "launcher-tap":
            // Super alone: never over a full-screen game / video
            if (Shell.overlay === "launcher") Shell.hideOverlay();
            else if (!Shell.fullscreenFocused && !Power.locked) Shell.showOverlay("launcher");
            break;
        case "centre": Shell.toggleOverlay("centre"); break;
        case "dnd": Notifs.toggleDnd(); break;
        case "lock": Power.lock(); break;
        case "power": Shell.toggleOverlay("power"); break;
        case "restart": Shell.showOverlay("restart"); break;
        case "clipboard": Shell.toggleOverlay("clipboard"); break;
        case "emoji": Shell.toggleOverlay("emoji"); break;
        case "screenshot": Shell.showOverlay("screenshot"); break;
        case "screenshot-full": Screenshot.full(Shell.focusedScreen); break;
        case "record": Recorder.toggle(); break;
        case "replay": Recorder.saveReplay(); break;
        case "mission": Shell.toggleOverlay("mission"); break;
        case "switcher":
            if (Shell.overlay === "switcher") Shell.switcherStep(1);
            else Shell.showOverlay("switcher", { reverse: false });
            break;
        case "switcher-back":
            if (Shell.overlay === "switcher") Shell.switcherStep(-1);
            else Shell.showOverlay("switcher", { reverse: true });
            break;
        case "snap": {
            if (Shell.overlay === "snap") { Shell.hideOverlay(); break; }
            const t = Hyprland.activeToplevel;
            Shell.showOverlay("snap", t ? { addr: Shell.addr(t), title: t.title } : null);
            break;
        }
        case "peek":
            Shell.peekBar();
            break;
        case "quick": {
            const s = Shell.focusedScreen;
            Shell.toggle("status", s, Shell.statusXFor(s), Shell.statusWidth);
            break;
        }
        case "sheet": Shell.toggleOverlay("sheet"); break;
        case "notes": Shell.toggleOverlay("notes"); break;
        case "hud": Hud.toggle(); Games.controlsShown = !Games.controlsShown; break;
        case "terminal": Apps.openKind("terminal", Prefs.terminal); break;
        case "browser": Apps.openKind("browser", Prefs.browser); break;
        case "music": Apps.openKind("music", Prefs.music); break;
        case "messaging":
            // nothing to open yet: the Store's chat apps instead of silence
            if (Apps.find("messaging", Prefs.messaging)) Apps.openKind("messaging", Prefs.messaging);
            else Toasts.show(Tr.t("No messaging app yet"), Tr.t("Discord, Telegram, Signal and more are in the Store"), Icons.messageReplyTextOutline,
                             null, [{ text: Tr.t("Open the Store"), primary: true, run: () => Apps.run("tuxos-app store --page internet") }]);
            break;
        case "files": Apps.openKind("files", Prefs.files); break;
        case "settings": Apps.openKind("settings", Prefs.settingsApp); break;
        case "monitor": Apps.openKind("monitor", Prefs.monitorApp); break;
        case "steam":
            if (Apps.entry("steam")) Quickshell.execDetached(["steam", "steam://open/bigpicture"]);
            else Toasts.show(Tr.t("Steam is not installed"), Tr.t("Install it from the Store, with the gaming set"), Icons.gamepadVariant,
                             null, [{ text: Tr.t("Open the Store"), primary: true, run: () => Apps.run("tuxos-app store --page discover") }]);
            break;
        case "minimize": Shell.minimizeActive(); break;
        case "geometry": Shell.windowsMoved(); break;      // the config moved / resized windows (maximize)
        case "dropped": dropProc.running = false; dropProc.running = true; break;   // a Super + drag ended
        case "locks": locksProc.running = true; break;
        case "displays": Apps.run(`${Prefs.settingsApp} --page displays`); break;
        }
    }

    Variants {
        model: ["launcher", "launcher-tap", "centre", "dnd", "lock", "power", "restart", "clipboard", "emoji", "screenshot", "screenshot-full",
                "record", "replay", "mission", "switcher", "switcher-back", "quick", "sheet", "notes", "hud", "terminal",
                "browser", "music", "messaging", "files", "settings", "monitor", "steam", "displays", "minimize", "locks", "peek", "snap", "geometry", "dropped"]
        delegate: Component {
            GlobalShortcut {
                required property string modelData
                appid: "tuxos"
                name: modelData
                description: "TuxOS: " + modelData     // fixed at creation (not translated)
                // release binds (Super alone) arrive as "released" only
                readonly property bool onRelease: modelData === "launcher-tap" || modelData === "dropped"
                onPressed: if (!onRelease) keys.run(modelData)
                onReleased: if (onRelease) keys.run(modelData)
            }
        }
    }

    // Caps Lock / Num Lock flyout: read the state from Hyprland's devices
    Process {
        id: locksProc
        property string which: ""
        command: ["sh", "-c", "sleep 0.12; hyprctl -j devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const k = JSON.parse(text).keyboards.find(x => x.main) || JSON.parse(text).keyboards[0];
                    const caps = k.capsLock, num = k.numLock;
                    if (caps !== keys.lastCaps) Shell.flyout({ icon: Icons.formatLetterCase, title: Tr.t("Caps Lock"), sub: "Keyboard", text: caps ? "On" : "Off", off: !caps, value: -1 });
                    else if (num !== keys.lastNum) Shell.flyout({ icon: Icons.numeric1Box, title: Tr.t("Num Lock"), sub: "Keyboard", text: num ? "On" : "Off", off: !num, value: -1 });
                    keys.lastCaps = caps; keys.lastNum = num;
                } catch (e) {}
            }
        }
    }
    // a window drag ended: where the pointer is decides (desktop numbers in
    // the bar take the window)
    Process {
        id: dropProc
        command: ["sh", "-c", "hyprctl -j cursorpos; echo @@; hyprctl -j activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split("@@");
                    const c = JSON.parse(parts[0]), w = JSON.parse(parts[1]);
                    for (const m of Hyprland.monitors.values) {
                        const o = m.lastIpcObject || {}, s = o.scale || 1;
                        if (o.x === undefined) continue;
                        if (c.x >= o.x && c.x < o.x + o.width / s && c.y >= o.y && c.y < o.y + o.height / s) {
                            Shell.windowDropped(m.name, c.x - o.x, c.y - o.y, w.address || "");
                            break;
                        }
                    }
                } catch (e) {}
            }
        }
    }
    property bool lastCaps: false
    property bool lastNum: false

    Connections { target: Shell; function onShortcut(name) { keys.run(name); } }

    IpcHandler {
        target: "shell"
        function call(name: string): void { keys.run(name); }
        function toast(title: string, body: string): void { Toasts.show(title, body); }
        // show the summary of the last game session again (and for tests)
        function gameSummary(): void { GameSessions.summarise(); }
        // the Clock app saved timers / alarms
        function clockChanged(): void { ClockStore.reload(); }
        // tuxos-brightness reports the new level (laptop panel or DDC/CI monitors)
        function brightness(percent: int, device: string): void {
            Shell.flyout({ icon: Icons.brightness6, title: device || "Display", sub: "Brightness", value: percent / 100 });
        }
        // Super + R: restart the shell process; tuxos-shell starts it again at
        // once (an in-process reload would leave the polkit agent behind)
        function reload(): void { Quickshell.execDetached(["kill", String(Quickshell.processId)]); }
    }
}
