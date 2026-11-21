pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

// Session restore and saved setups (SPEC "Window management").
// The open apps (app, desktop, floating / full screen) are written to
// ~/.local/state/tuxos/session.json once a minute when they changed and
// right before shutdown / restart / logout. At the next login the shell
// offers to open them again on their desktops (Settings: Ask / Always /
// Never). Saved setups ("Streaming", "Work") are named lists of the same
// kind in ~/.local/share/tuxos/setups.json, opened from the launcher.
Singleton {
    id: ses

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/tuxos"
    readonly property string dataDir: Quickshell.env("HOME") + "/.local/share/tuxos"
    property var setups: ({})
    property string lastSaved: ""

    // ---- what is open now
    function snapshot() {
        Hyprland.refreshToplevels();
        const out = [];
        for (const h of Hyprland.toplevels.values) {
            const o = h.lastIpcObject || {};
            const cls = o.class || (h.wayland ? h.wayland.appId : "");
            // the drop-down terminal and Welcome (it opens by itself until done) are never restored
            if (!cls || /^tuxos-(dropterm|welcome)$/.test(cls)) continue;
            const ws = o.workspace ? o.workspace.id : 1;
            if (ws < 1) continue;                               // special desktops (minimized, ...)
            const e = DesktopEntries.heuristicLookup(cls);
            if (!e) continue;                                    // nothing to start it with
            out.push({ app: e.id, cls: cls, ws: ws, floating: o.floating === true, fullscreen: o.fullscreen || 0 });
        }
        out.sort((a, b) => a.ws - b.ws);
        return out;
    }
    function save() {
        const apps = snapshot();
        const t = JSON.stringify(apps);
        if (t === lastSaved) return;
        lastSaved = t;
        Quickshell.execDetached(["mkdir", "-p", stateDir]);
        sessionFile.setText(JSON.stringify({ savedAt: Date.now(), apps: apps }, null, 1));
    }
    FileView { id: sessionFile; path: ses.stateDir + "/session.json"; printErrors: false }
    Connections { target: Tick; function onMinute() { if (ses.started) ses.save(); } }

    // ---- opening a list of apps on their desktops
    property var pending: []               // [{ cls, ws, floating, fullscreen, until }]
    function open(apps) {
        const now = Date.now();
        const p = pending.slice();
        for (const a of apps) {
            const e = DesktopEntries.byId(a.app) || DesktopEntries.heuristicLookup(a.app);
            if (!e) continue;
            p.push({ cls: a.cls, ws: a.ws, floating: a.floating, fullscreen: a.fullscreen, until: now + 30000 });
            e.execute();
        }
        pending = p;
    }
    Connections {
        target: Hyprland
        enabled: ses.pending.length > 0
        function onRawEvent(event) {
            if (event.name !== "openwindow") return;
            const f = event.data.split(",");          // address, workspace, class, title
            const addr = "0x" + f[0].replace(/^0x/, ""), cls = f[2];
            const now = Date.now();
            const p = ses.pending.filter(x => x.until > now);
            const i = p.findIndex(x => x.cls === cls);
            if (i === -1) { ses.pending = p; return; }
            const a = p[i];
            p.splice(i, 1);
            ses.pending = p;
            const w = `window = "address:${addr}"`;
            let lua = `hl.dispatch(hl.dsp.window.move({ workspace = ${a.ws}, follow = false, ${w} }))`;
            if (a.floating) lua += `; tux_float("address:${addr}")`;
            if (a.fullscreen === 1) lua += `; hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", ${w} }))`;
            Shell.dispatch(`(function() ${lua}; return hl.dsp.no_op() end)()`, "");
        }
    }

    // ---- at login: offer the last session
    property bool started: false
    // once per login: a restarted shell (Super + R) does not ask again
    readonly property string offeredMark: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tuxos-session-offered"
    Process {
        id: firstCheck
        command: ["sh", "-c", "[ -e \"$1\" ] && echo seen; touch \"$1\"", "sh", ses.offeredMark]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("seen") !== -1) { ses.started = true; ses.lastSaved = JSON.stringify(ses.snapshot()); }
                else restoreRead.path = ses.stateDir + "/session.json";   // loads it
            }
        }
    }
    function start() { firstCheck.running = true; }
    FileView {
        id: restoreRead
        path: ""                            // set once by firstCheck
        printErrors: false
        blockLoading: false
        onLoaded: {
            if (ses.started) return;
            let last = null;
            try { last = JSON.parse(text()); } catch (e) {}
            ses.started = true;
            if (!last || !last.apps || last.apps.length === 0 || Prefs.restoreApps === "never") return;
            // only what was open when the computer stopped, not older than 2 weeks
            if (Date.now() - last.savedAt > 14 * 86400000) return;
            if (Prefs.restoreApps === "always") { ses.open(last.apps); return; }
            const names = [];
            for (const a of last.apps) {
                const e = DesktopEntries.byId(a.app);
                const n = e ? e.name : a.cls;
                if (names.indexOf(n) === -1) names.push(n);
            }
            Toasts.show(Tr.t("Open your apps again?"), names.slice(0, 4).join(", ") + (names.length > 4 ? ` and ${names.length - 4} more` : "") + " · on the same desktops",
                        Icons.restore, null, [{ text: Tr.t("Open"), primary: true, run: () => ses.open(last.apps) }, { text: Tr.t("Not now"), run: () => {} }], 20000);
        }
        onLoadFailed: ses.started = true
    }

    // ---- saved setups
    FileView {
        id: setupsFile
        path: ses.dataDir + "/setups.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { ses.setups = JSON.parse(text()) || {}; } catch (e) { ses.setups = {}; } }
    }
    function saveSetup(name) {
        name = name.trim();
        if (!name) return;
        const apps = snapshot();
        if (apps.length === 0) { Toasts.show(Tr.t("Nothing to save"), Tr.t("Open the apps of the setup first"), Icons.restore); return; }
        const s = Object.assign({}, setups);
        s[name] = apps;
        setups = s;
        Quickshell.execDetached(["mkdir", "-p", dataDir]);
        setupsFile.setText(JSON.stringify(s, null, 1));
        Toasts.show(Tr.f("Setup \"{n}\" saved", { n: name }), Tr.f("{c} apps · open it from the launcher: \"setup {n}\"", { c: apps.length, n: name }), Icons.restore);
    }
    function openSetup(name) { if (setups[name]) open(setups[name]); }
    function removeSetup(name) {
        const s = Object.assign({}, setups);
        delete s[name];
        setups = s;
        setupsFile.setText(JSON.stringify(s, null, 1));
    }
}
