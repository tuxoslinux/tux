pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every shortcut of the shell and Hyprland (SPEC round 7 #5: the shortcut
// editor): its default keys, the action as Hyprland Lua, and the user's own
// keys (~/.config/tuxos/shortcuts.json, "" = turned off). Changes are
// written as ~/.config/hypr/keys.lua (unbind the default, bind the new keys),
// which hyprland.lua loads after its own binds, and applied with a reload.
Singleton {
    id: sc

    function g(name) { return `hl.dsp.global("tuxos:${name}")`; }
    // [id, group, name, default keys, action]
    readonly property var all: [
        ["launcher", "Apps", "App launcher (tap Super)", "SUPER + Super_L", ""],
        ["terminal", "Apps", "Terminal", "SUPER + W", g("terminal")],
        ["browser", "Apps", "Browser", "SUPER + B", g("browser")],
        ["files", "Apps", "Files", "SUPER + F", g("files")],
        ["settings", "Apps", "Settings", "SUPER + S", g("settings")],
        ["music", "Apps", "Music app", "SUPER + V", g("music")],
        ["messaging", "Apps", "Messaging app", "SUPER + M", g("messaging")],
        ["steam", "Apps", "Steam Big Picture", "SUPER + G", g("steam")],
        ["monitor", "Apps", "System manager", "CTRL + SHIFT + Escape", g("monitor")],
        ["dropterm", "Apps", "Drop-down terminal", "F12", "tux_key_dropterm"],
        ["close", "Windows", "Close the app", "SUPER + Q", "hl.dsp.window.close()"],
        ["kill", "Windows", "Force-quit", "SUPER + SHIFT + Q", "hl.dsp.window.kill()"],
        ["maximize", "Windows", "Maximize", "SUPER + up", "tux_key_up"],
        ["minimize", "Windows", "Restore / minimize", "SUPER + down", "tux_key_down"],
        ["left", "Windows", "Snap to the left half", "SUPER + left", "tux_key_left"],
        ["right", "Windows", "Snap to the right half", "SUPER + right", "tux_key_right"],
        ["fullscreen", "Windows", "Full screen", "SUPER + Return", "hl.dsp.window.fullscreen()"],
        ["float", "Windows", "Float / tile", "SUPER + T", "tux_key_float"],
        ["snap", "Windows", "Snap layouts", "SUPER + Z", g("snap")],
        ["pip", "Windows", "Pin as picture in picture", "SUPER + ALT + P", "tux_key_pip"],
        ["tabs", "Windows", "Window tabs", "SUPER + ALT + T", "hl.dsp.group.toggle()"],
        ["tabnext", "Windows", "Next tab", "SUPER + ALT + right", "hl.dsp.group.next()"],
        ["tabprev", "Windows", "Previous tab", "SUPER + ALT + left", "hl.dsp.group.prev()"],
        ["monleft", "Windows", "Window to the left monitor", "SUPER + SHIFT + left", 'hl.dsp.window.move({ monitor = "-1" })'],
        ["monright", "Windows", "Window to the right monitor", "SUPER + SHIFT + right", 'hl.dsp.window.move({ monitor = "+1" })'],
        ["mission", "Desktops", "Mission Control", "SUPER + space", g("mission")],
        ["mission2", "Desktops", "Mission Control (second key)", "SUPER + Tab", g("mission")],
        ["switcher", "Desktops", "Switch windows", "ALT + Tab", g("switcher")],
        ["deskprev", "Desktops", "Previous desktop", "SUPER + CTRL + left", 'hl.dsp.focus({ workspace = "e-1" })'],
        ["desknext", "Desktops", "Next desktop", "SUPER + CTRL + right", 'hl.dsp.focus({ workspace = "e+1" })'],
        ["quick", "Shell", "Quick settings", "SUPER + A", g("quick")],
        ["centre", "Shell", "Notifications", "SUPER + N", g("centre")],
        ["dnd", "Shell", "Do not disturb", "SUPER + D", g("dnd")],
        ["clipboard", "Shell", "Clipboard history", "SUPER + C", g("clipboard")],
        ["emoji", "Shell", "Emoji", "SUPER + period", g("emoji")],
        ["notes", "Shell", "Quick notes", "SUPER + SHIFT + N", g("notes")],
        ["picker", "Shell", "Colour picker", "SUPER + SHIFT + C", 'hl.dsp.exec_cmd("hyprpicker -a -f hex")'],
        ["sheet", "Shell", "All shortcuts", "SUPER + slash", g("sheet")],
        ["displays", "Shell", "Displays", "SUPER + P", g("displays")],
        ["lock", "Shell", "Lock the screen", "SUPER + L", g("lock")],
        ["power", "Shell", "Power menu", "SUPER + X", g("power")],
        ["restart", "Shell", "Restart (10 s countdown)", "SUPER + grave", g("restart")],
        ["reload", "Shell", "Reload the shell", "SUPER + R", 'hl.dsp.exec_cmd("qs -c tuxos ipc call shell reload")'],
        ["zoomreset", "Shell", "Zoom back to normal", "SUPER + Escape", "tux_zoom_reset"],
        ["screenshot", "Capture", "Screenshot", "SUPER + SHIFT + S", g("screenshot")],
        ["screenfull", "Capture", "Screenshot of the whole screen", "Print", g("screenshot-full")],
        ["record", "Capture", "Record the screen", "SUPER + SHIFT + R", g("record")],
        ["replay", "Capture", "Save the instant replay", "SUPER + ALT + R", g("replay")],
        ["hud", "Gaming", "Game HUD", "SUPER + SHIFT + G", g("hud")]
    ]
    // keys that are not in the list but taken (desktops 1-9, Super + drag ...)
    readonly property var reserved: {
        const r = {};
        for (let i = 1; i <= 9; i++) { r[`SUPER + ${i}`] = "Go to desktop " + i; r[`SUPER + SHIFT + ${i}`] = "Move the window to desktop " + i; }
        r["ALT + SHIFT"] = "Keyboard layout";
        return r;
    }

    property var mine: ({})                 // id -> keys ("" = off)
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/tuxos/shortcuts.json"
        printErrors: false
        onLoaded: { try { sc.mine = JSON.parse(text()) || {}; } catch (e) { sc.mine = {}; } }
    }
    function keysOf(id) { const b = all.find(x => x[0] === id); return mine[id] !== undefined ? mine[id] : (b ? b[3] : ""); }
    function nameOf(id) { const b = all.find(x => x[0] === id); return b ? b[2] : id; }
    // who else uses these keys ("" = nobody)
    function clash(id, keys) {
        if (!keys) return "";
        for (const b of all) if (b[0] !== id && keysOf(b[0]).toUpperCase() === keys.toUpperCase()) return b[0];
        return reserved[keys] ? "reserved:" + reserved[keys] : "";
    }
    function set(id, keys) {
        const m = Object.assign({}, mine);
        const b = all.find(x => x[0] === id);
        if (b && keys === b[3]) delete m[id]; else m[id] = keys;
        mine = m;
        save();
    }
    function resetAll() { mine = {}; save(); }

    function save() {
        file.setText(JSON.stringify(mine, null, 1));
        let lua = "-- written by TuxOS Settings > Keyboard & shortcuts (shortcuts on other keys)\n";
        for (const id in mine) {
            const b = all.find(x => x[0] === id);
            if (!b || !b[4]) continue;
            const act = /^tux_/.test(b[4]) ? b[4] : b[4];
            lua += `pcall(hl.unbind, "${b[3]}")\n`;
            if (mine[id]) lua += `hl.bind("${mine[id]}", ${act})\n`;
        }
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config/hypr\" && printf '%s' \"$1\" > \"$HOME/.config/hypr/keys.lua\" && hyprctl reload >/dev/null", "sh", lua]);
    }

    // a key press (Qt) as Hyprland keys: "SUPER + SHIFT + Q"
    function fromEvent(e) {
        const mods = [];
        if (e.modifiers & Qt.MetaModifier) mods.push("SUPER");
        if (e.modifiers & Qt.ControlModifier) mods.push("CTRL");
        if (e.modifiers & Qt.AltModifier) mods.push("ALT");
        if (e.modifiers & Qt.ShiftModifier) mods.push("SHIFT");
        const named = { [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Space]: "space", [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab",
                        [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Escape]: "Escape",
                        [Qt.Key_Period]: "period", [Qt.Key_Comma]: "comma", [Qt.Key_Slash]: "slash", [Qt.Key_QuoteLeft]: "grave", [Qt.Key_Minus]: "minus",
                        [Qt.Key_Equal]: "equal", [Qt.Key_Print]: "Print", [Qt.Key_Delete]: "Delete", [Qt.Key_Backspace]: "BackSpace",
                        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Insert]: "Insert",
                        [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright", [Qt.Key_Semicolon]: "semicolon" };
        let k = named[e.key] || "";
        if (!k && e.key >= Qt.Key_F1 && e.key <= Qt.Key_F24) k = "F" + (e.key - Qt.Key_F1 + 1);
        if (!k && e.key >= Qt.Key_A && e.key <= Qt.Key_Z) k = String.fromCharCode(e.key);
        if (!k && e.key >= Qt.Key_0 && e.key <= Qt.Key_9) k = String.fromCharCode(e.key);
        if (!k) return "";                                    // a modifier alone: keep waiting
        return mods.concat([k]).join(" + ");
    }
    // as people read it: "Super + Shift + Q"
    function pretty(keys) {
        if (!keys) return Tr.t("Off");
        return keys.split(" + ").map(p => ({ SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift", Super_L: "(tap)", space: "Space", Return: "Enter", period: ".", slash: "/", grave: "`",
                                             up: "↑", down: "↓", left: "←", right: "→", Escape: "Esc", comma: ",", minus: "-", equal: "=" }[p] || p)).join(" + ").replace(" + (tap)", " (tap)");
    }
}
