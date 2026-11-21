import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// Window rules (SPEC "Per-app rules"): per app, which desktop and monitor it
// opens on, how it opens (normal / floating / maximized / full screen),
// always on top, opacity. Saved in ~/.config/tuxos/window-rules.json and
// written for Hyprland as ~/.config/hypr/rules.lua (hyprland.lua loads it).
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Window rules"); description: Tr.t("Where and how each app's windows open.") }

    readonly property string jsonPath: Quickshell.env("HOME") + "/.config/tuxos/window-rules.json"
    readonly property string luaPath: Quickshell.env("HOME") + "/.config/hypr/rules.lua"
    property var rules: []

    FileView {
        path: page.jsonPath
        printErrors: false
        onLoaded: { try { page.rules = JSON.parse(text()) || []; } catch (e) { page.rules = []; } }
    }
    FileView { id: jsonOut; path: page.jsonPath; printErrors: false }
    FileView { id: luaOut; path: page.luaPath; printErrors: false }

    readonly property var modes: ["normal", "floating", "maximized", "fullscreen"]
    readonly property var opacities: [1.0, 0.95, 0.9, 0.8]

    function luaString(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'; }
    function regexQuote(s) { return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }
    function save(list) {
        rules = list;
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.config/tuxos", Quickshell.env("HOME") + "/.config/hypr"]);
        jsonOut.setText(JSON.stringify(list, null, 1));
        let lua = "-- written by TuxOS Control > Window rules\n";
        list.forEach((r, i) => {
            const f = [`name = "tuxos-user-${i}"`, `match = { class = ${luaString("(?i)^" + regexQuote(r.cls) + "$")} }`];
            if (r.desktop > 0) f.push(`workspace = ${luaString(r.desktop + " silent")}`);
            if (r.mode === "floating") f.push("float = true");
            if (r.mode === "maximized") f.push("maximize = true");
            if (r.mode === "fullscreen") f.push("fullscreen = true");
            if (r.onTop) f.push("float = true", "pin = true");
            if (r.monitor) f.push(`monitor = ${luaString(r.monitor)}`);
            if (r.opacity && r.opacity < 1) f.push(`opacity = ${luaString(r.opacity + " " + r.opacity)}`);
            lua += `hl.window_rule({ ${f.join(", ")} })\n`;
        });
        luaOut.setText(lua);
        reloadLater.restart();
    }
    Timer { id: reloadLater; interval: 400; onTriggered: Quickshell.execDetached(["hyprctl", "reload"]) }
    function change(i, key, value) {
        const l = rules.map(r => Object.assign({}, r));
        l[i][key] = value;
        save(l);
    }

    // apps that can get a rule: installed apps, open windows first
    readonly property var openClasses: Hyprland.toplevels.values.map(t => (t.lastIpcObject || {}).class).filter(c => !!c)
    readonly property var appChoices: {
        const seen = {}, out = [];
        const add = (cls, label, sub) => { const k = cls.toLowerCase(); if (seen[k]) return; seen[k] = true; out.push({ value: cls, label: label, sub: sub }); };
        for (const c of openClasses) {
            const e = DesktopEntries.heuristicLookup(c);
            add(c, e ? e.name : c, "open now");
        }
        for (const e of DesktopEntries.applications.values)
            if (!e.noDisplay) add(e.startupClass || e.id, e.name, "");
        return out.sort((a, b) => (a.sub === b.sub ? a.label.localeCompare(b.label) : (a.sub ? -1 : 1)));
    }
    function nameOf(cls) {
        const e = DesktopEntries.heuristicLookup(cls);
        return e ? e.name : cls;
    }

    SettingCard {
        header: Tr.t("Title bars")
        SettingRow {
            title: Tr.t("TuxOS title bar for apps without one"); last: true
            description: Tr.t("Floating windows of apps that draw no title bar (kitty, Thunar, Qt apps) get a glass bar: drag to move, double-click to maximize, minimize / maximize / close. Per app: Always / Never below.")
            Toggle { checked: Prefs.titleBars; onToggled: v => Prefs.titleBars = v }
        }
    }

    SettingCard {
        header: Tr.t("Add a rule")
        SettingRow {
            title: Tr.t("App"); description: Tr.t("Open apps are listed first"); last: true
            ChoiceList {
                options: page.appChoices
                current: null
                onPicked: v => {
                    if (page.rules.some(r => r.cls.toLowerCase() === String(v).toLowerCase())) return;
                    page.save(page.rules.concat([{ cls: v, desktop: 0, mode: "normal", onTop: false, monitor: "", opacity: 1.0 }]));
                }
            }
        }
    }

    Text {
        visible: page.rules.length === 0
        text: Tr.t("No rules yet: every app opens on the current desktop, the way it wants.")
        font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted
    }

    Repeater {
        model: page.rules
        delegate: SettingCard {
            required property var modelData
            required property int index
            header: page.nameOf(modelData.cls)
            SettingRow {
                title: Tr.t("Desktop")
                ChoiceList {
                    options: [{ value: 0, label: Tr.t("The current one") }].concat([1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => ({ value: n, label: Prefs.desktopNames[String(n)] || ("Desktop " + n) })))
                    current: modelData.desktop
                    onPicked: v => page.change(index, "desktop", v)
                }
            }
            SettingRow {
                title: Tr.t("Opens")
                Segmented { width: 420; options: ["Normal", "Floating", "Maximized", "Full screen"]; current: page.modes.indexOf(modelData.mode); onPicked: i => page.change(index, "mode", page.modes[i]) }
            }
            SettingRow {
                title: Tr.t("Always on top"); description: Tr.t("Floats above other windows on every desktop")
                Toggle { checked: modelData.onTop; onToggled: v => page.change(index, "onTop", v) }
            }
            SettingRow {
                title: Tr.t("Monitor")
                ChoiceList {
                    options: [{ value: "", label: Tr.t("Any") }].concat(Hyprland.monitors.values.map(m => ({ value: m.name, label: m.name, sub: m.description || "" })))
                    current: modelData.monitor
                    onPicked: v => page.change(index, "monitor", v)
                }
            }
            SettingRow {
                title: Tr.t("Title bar"); description: Tr.t("Auto: only for apps that draw none")
                Segmented { width: 300; options: ["Auto", "Always", "Never"]; current: Math.max(0, ["auto", "always", "never"].indexOf(modelData.titleBar || "auto")); onPicked: i => page.change(index, "titleBar", ["auto", "always", "never"][i]) }
            }
            SettingRow {
                title: Tr.t("Opacity")
                Segmented { width: 300; options: ["100 %", "95 %", "90 %", "80 %"]; current: page.opacities.indexOf(modelData.opacity); onPicked: i => page.change(index, "opacity", page.opacities[i]) }
            }
            SettingRow {
                title: Tr.t("Remove this rule"); last: true
                Btn { text: Tr.t("Remove"); danger: true; onClicked: page.save(page.rules.filter((r, i) => i !== index)) }
            }
        }
    }
}
