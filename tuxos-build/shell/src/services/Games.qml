pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

// Games on this PC (SPEC Gaming): Steam, Heroic and Lutris libraries read
// locally by tuxos-games, for the launcher's "Games" row and search (with
// covers), the launch card, the "Will it run?" badge (ProtonDB + anti-cheat,
// cached a day), per-game profiles (Settings > Gaming > a game), play-time
// reminders and the drive advisor.
Singleton {
    id: games

    property var list: []                // [{ id, name, source, appid, cover, launch, dir, size, library }]
    property var badges: ({})            // steam app id -> { tier, anticheat }
    readonly property string profilesPath: Quickshell.env("HOME") + "/.config/tuxos/game-profiles.json"
    property var profiles: ({})          // game id -> profile (see defaultProfile)

    function byId(id) { return list.find(g => g.id === id) || null; }
    function badgeOf(g) { return g && g.source === "Steam" ? (badges[g.appid] || null) : null; }

    // ---- the library
    Process {
        id: listProc
        command: ["tuxos-games", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { games.list = JSON.parse(text) || []; } catch (e) { return; }
                games.checkBadges();
            }
        }
    }
    function refresh() { if (!listProc.running) listProc.running = true; }
    Component.onCompleted: { refresh(); profileFile.reload(); }
    // new installs show up: every 10 minutes and whenever the launcher opens
    Timer { interval: 600000; repeat: true; running: true; onTriggered: games.refresh() }
    Connections { target: Shell; function onOverlayChanged() { if (Shell.overlay === "launcher") games.refresh(); } }

    // ---- "Will it run?": ProtonDB tier + AreWeAntiCheatYet status
    Process {
        id: badgeProc
        stdout: StdioCollector { onStreamFinished: { try { games.badges = Object.assign({}, games.badges, JSON.parse(text)); } catch (e) {} } }
    }
    function checkBadges(extraIds) {
        const ids = list.filter(g => g.source === "Steam").map(g => g.appid).concat(extraIds || []);
        if (ids.length === 0 || badgeProc.running) return;
        badgeProc.command = ["tuxos-games", "willitrun"].concat(ids);
        badgeProc.running = true;
    }
    function tierText(b) {
        if (!b) return "";
        const t = { platinum: "Runs great", gold: "Runs well", silver: "Runs with small issues", bronze: "Runs poorly",
                    borked: "Does not run", native: "Native", pending: "Not rated yet", unknown: "Unknown" }[b.tier] || "Unknown";
        return Tr.t(t);
    }
    function tierColor(b) {
        if (!b) return Theme.muted;
        if (b.anticheat === "Denied" || b.anticheat === "Broken" || b.tier === "borked") return Theme.danger;
        if (b.tier === "platinum" || b.tier === "gold" || b.tier === "native") return Theme.good;
        if (b.tier === "silver" || b.tier === "bronze") return Theme.warn;
        return Theme.muted;
    }
    function antiText(b) {
        if (!b || b.anticheat === "none") return "";
        return { Supported: Tr.t("anti-cheat works"), Running: Tr.t("anti-cheat works"), Planned: Tr.t("anti-cheat: planned"),
                 Broken: Tr.t("anti-cheat blocks it"), Denied: Tr.t("anti-cheat blocks Linux") }[b.anticheat] || "";
    }

    // ---- launching: the launch card shows the cover until the window is up
    property var starting: null          // the game being started
    property double startedAt: 0
    property string startStatus: ""      // "Starting...", "Preparing shaders...", "Ready"
    function launch(g) {
        if (!g) return;
        Usage.bump(g.id);
        starting = g;
        startedAt = Date.now();
        startStatus = Activities.shaders ? Tr.t("Preparing shaders...") : Tr.t("Starting...");
        Quickshell.execDetached(g.launch);
        startTimeout.restart();
    }
    Timer { id: startTimeout; interval: 90000; onTriggered: games.starting = null }
    Timer { id: readyLinger; interval: 1200; onTriggered: games.starting = null }
    Connections {
        target: Hyprland
        enabled: games.starting !== null
        function onRawEvent(event) {
            if (event.name !== "openwindow" || !games.starting) return;
            const cls = (event.data.split(",")[2] || "").toLowerCase();
            const g = games.starting;
            // Steam games: steam_app_<id>; others: anything but Steam's / the launcher's own windows
            const mine = g.source === "Steam" ? cls === "steam_app_" + g.appid
                       : !/^(steam|steamwebhelper|heroic|lutris|net\.lutris\.lutris)$/.test(cls);
            if (mine || (Notifs.gameRunning && Shell.fullscreenFocused)) {
                games.startStatus = Tr.t("Ready");
                readyLinger.restart();
            }
        }
    }
    Connections {
        target: Activities
        function onShadersChanged() {
            if (games.starting) games.startStatus = Activities.shaders ? Tr.t("Preparing shaders...") : Tr.t("Shaders ready");
        }
    }

    // the frame limiter panel next to the Game HUD (overlays/GameControls.qml)
    property bool controlsShown: false

    // ---- the game running now (game mode on): its id and profile
    property string current: ""
    property double currentSince: 0
    Process {
        id: runProc
        command: ["tuxos-games", "running"]
        stdout: StdioCollector { onStreamFinished: { games.current = text.trim(); games.currentSince = Date.now(); games.applyProfile(); } }
    }
    Connections {
        target: Notifs
        function onGameRunningChanged() {
            if (Notifs.gameRunning) runLater.restart();
            else { games.revertProfile(); games.current = ""; games.reminded = 0; }
        }
    }
    Timer { id: runLater; interval: 1500; onTriggered: if (!runProc.running) runProc.running = true }
    readonly property var currentGame: current ? byId(current) : null
    // pop-ups wait while this game runs (its profile, else Settings > Gaming)
    readonly property bool gameQuiet: { const p = profileOf(current); return p.dnd === "on" || (p.dnd === "default" && Prefs.gameSilence); }
    readonly property string currentName: currentGame ? currentGame.name : (current === "gamescope" ? "gamescope" : "")

    // ---- per-game profiles: ~/.config/tuxos/game-profiles.json (the shell
    // applies the desktop side) + ~/.config/tuxos/game-profiles/<id>.conf
    // (power profile, scheduler: read by the root game daemon tuxos-gamed)
    function defaultProfile() {
        return { fps: -1, refresh: "", vrr: "default", hud: false, micMute: false, dnd: "default",
                 power: "default", scheduler: "default", tearing: "default", gpu: "default" };
    }
    function profileOf(id) { return Object.assign(defaultProfile(), profiles[id] || {}); }
    FileView {
        id: profileFile
        path: games.profilesPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { games.profiles = JSON.parse(text()) || {}; } catch (e) { games.profiles = {}; } }
    }
    function setProfile(id, key, value) {
        const all = Object.assign({}, profiles);
        const p = Object.assign(defaultProfile(), all[id] || {});
        p[key] = value;
        all[id] = p;
        profiles = all;
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.config/tuxos/game-profiles"]);
        profileFile.setText(JSON.stringify(all, null, 1));
        // the root side: only plain words reach the daemon's file
        const safe = v => String(v).replace(/[^A-Za-z0-9_.-]/g, "");
        const conf = `# written by TuxOS Settings > Gaming (read by tuxos-gamed)\nPOWER=${safe(p.power)}\nSCHEDULER=${safe(p.scheduler)}\n`;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
                                 "sh", `${Quickshell.env("HOME")}/.config/tuxos/game-profiles/${id.replace(":", "_")}.conf`, conf]);
        if (id === current) applyProfile();
    }

    // what the shell changed for the running game, to put back afterwards
    property var applied: null
    readonly property string mango: Quickshell.env("HOME") + "/.config/MangoHud/MangoHud.conf"
    function mangoSet(key, value) {
        // MangoHud re-reads its config file when it changes (live in the game)
        Quickshell.execDetached(["sh", "-c", "f=\"$1\"; [ -e \"$f\" ] || exit 0; if grep -q \"^$2=\" \"$f\"; then sed -i \"s|^$2=.*|$2=$3|\" \"$f\"; else echo \"$2=$3\" >> \"$f\"; fi",
                                 "sh", mango, key, String(value)]);
    }
    function mangoDel(key) { Quickshell.execDetached(["sh", "-c", "sed -i \"/^$2=/d\" \"$1\" 2>/dev/null; true", "sh", mango, key]); }

    // the frame cap the game gets: its own, else the global one, else (tear-
    // free with VRR) a few frames under the monitor's top refresh rate
    readonly property var mon: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.lastIpcObject : null
    readonly property real maxRate: {
        if (!mon || !mon.availableModes) return mon && mon.refreshRate ? mon.refreshRate : 60;
        let r = 0;
        for (const m of mon.availableModes) { const x = /@([\d.]+)Hz/.exec(m); if (x) r = Math.max(r, parseFloat(x[1])); }
        return r || mon.refreshRate || 60;
    }
    readonly property bool vrrOn: mon ? mon.vrr === true : false
    function capFor(p) {
        if (p.fps >= 0) return p.fps === 999 ? Math.round(maxRate) - 3 : p.fps;     // 999 = "screen refresh"
        if (Prefs.fpsLimit > 0) return Prefs.fpsLimit;
        const tearing = p.tearing === "allow" || (p.tearing === "default" && Prefs.allowTearing);
        if (!tearing && vrrOn) return Math.max(30, Math.round(maxRate) - 3);
        return 0;
    }
    function hudLine(p) {
        const tearing = p.tearing === "allow" || (p.tearing === "default" && Prefs.allowTearing);
        const vrr = vrrOn ? Tr.f("VRR: on ({max} Hz)", { max: Math.round(maxRate) }) : Tr.t("VRR: off");
        return `${vrr}  ·  ${tearing ? Tr.t("Tearing: allowed") : Tr.t("Tearing: off")}`;
    }

    function applyProfile() {
        if (!Notifs.gameRunning) return;
        const p = profileOf(current);
        const a = applied || { mic: null, dnd: false, refresh: "", vrr: null, tearing: false };
        // frame cap + HUD lines (VRR / tearing state)
        mangoSet("fps_limit", capFor(p));
        mangoSet("custom_text", hudLine(p));
        // HUD shown for this game
        if (p.hud && !a.hud) { hudLater.restart(); a.hud = true; }
        // mic muted while this game runs
        if (p.micMute && a.mic === null) { a.mic = true; Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "1"]); }
        // tearing allowed for this game (competitive shooters): immediate presentation for its windows
        const tearing = p.tearing === "allow" || (p.tearing === "default" && Prefs.allowTearing);
        if (tearing !== a.tearing) { a.tearing = tearing; Shell.dispatch(`(function() hl.config({ general = { allow_tearing = ${tearing} } }); return hl.dsp.no_op() end)()`, ""); }
        // GPU tuning preset for this game (LACT)
        if (p.gpu !== "default" && !a.gpu) { a.gpu = true; Gpu.forGame(p.gpu); }
        // refresh rate / VRR for this game
        if ((p.refresh || p.vrr !== "default") && mon && !a.refresh) {
            a.refresh = `${mon.width}x${mon.height}@${mon.refreshRate.toFixed(2)}`;
            a.vrrWas = mon.vrr ? 1 : 0;
            const mode = p.refresh ? `${mon.width}x${mon.height}@${p.refresh}` : a.refresh;
            const vrr = p.vrr === "on" ? 1 : p.vrr === "off" ? 0 : a.vrrWas;
            Shell.dispatch(`(function() hl.monitor({ output = "${mon.name}", mode = "${mode}", position = "${mon.x}x${mon.y}", scale = ${mon.scale}, vrr = ${vrr} }); return hl.dsp.no_op() end)()`, "");
            a.monName = mon.name; a.pos = `${mon.x}x${mon.y}`; a.scale = mon.scale;
        }
        applied = a;
    }
    Timer { id: hudLater; interval: 4000; onTriggered: Hud.show() }
    function revertProfile() {
        const a = applied;
        applied = null;
        mangoSet("fps_limit", Prefs.fpsLimit);
        mangoDel("custom_text");
        if (!a) return;
        if (a.mic) Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "0"]);
        if (a.tearing) Shell.dispatch(`(function() hl.config({ general = { allow_tearing = false } }); return hl.dsp.no_op() end)()`, "");
        if (a.refresh) Shell.dispatch(`(function() hl.monitor({ output = "${a.monName}", mode = "${a.refresh}", position = "${a.pos}", scale = ${a.scale}, vrr = ${a.vrrWas} }); return hl.dsp.no_op() end)()`, "");
    }

    // ---- Steam achievements as TuxOS toasts (with the achievement's icon):
    // while a Steam game runs, Steam's local stats file is read every 15 s;
    // what was not unlocked at the first look and is now gets a toast
    property var achKnown: null           // keys unlocked so far (this session)
    Timer {
        interval: 15000; repeat: true
        running: Notifs.gameRunning && games.current.startsWith("steam:") && Prefs.achievementToasts
        onTriggered: if (!achProc.running) { achProc.command = ["tuxos-games", "achievements", games.current.slice(6)]; achProc.running = true; }
        onRunningChanged: if (!running) games.achKnown = null
    }
    Process {
        id: achProc
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(x => x).map(l => l.split("\t"));
                const keys = rows.map(r => r[0]);
                if (games.achKnown !== null)
                    for (const r of rows)
                        if (games.achKnown.indexOf(r[0]) === -1)
                            Toasts.show(Tr.t("Achievement unlocked"), r[1] + (games.currentName ? " · " + games.currentName : ""), Icons.trophy, null, [], 7000, r[2] || "");
                games.achKnown = keys;
            }
        }
    }

    // ---- play-time reminders (off by default): a gentle toast after the
    // chosen time, never mid-match: it waits until the game loses focus
    property int reminded: 0
    Connections {
        target: Tick
        function onMinute(t) {
            if (!Notifs.gameRunning || Prefs.playReminder <= 0 || !games.currentSince) return;
            const played = (t - games.currentSince) / 60000;
            const due = Math.floor(played / Prefs.playReminder);
            if (due > games.reminded) { if (games.gameFocused) games.remindPending = true; else games.remind(); }
        }
    }
    property bool remindPending: false
    readonly property bool gameFocused: Shell.fullscreenFocused
    onGameFocusedChanged: if (!gameFocused && remindPending) remind()
    function remind() {
        remindPending = false;
        reminded++;
        const h = Math.floor((Date.now() - currentSince) / 3600000), m = Math.round(((Date.now() - currentSince) % 3600000) / 60000);
        Toasts.show(Tr.f("{t} played", { t: h > 0 ? `${h} h ${m} min` : `${m} min` }), Tr.t("Time to stretch, drink some water, rest your eyes?"), Icons.gamepadVariant, null, [], 12000);
    }

    // ---- drive advisor: a game on a slow drive (HDD / USB) while a faster
    // library has room: a card once a day at most
    Process {
        id: drivesProc
        command: ["tuxos-games", "drives"]
        stdout: StdioCollector { onStreamFinished: { try { games.adviseDrives(JSON.parse(text)); } catch (e) {} } }
    }
    function checkDrives() { if (Prefs.driveAdvisor && !drivesProc.running) drivesProc.running = true; }
    Timer { interval: 120000; running: true; onTriggered: games.checkDrives() }   // a while after login
    // speed rank: USB 0, hard disk 1, SATA SSD 2, NVMe 3
    function rank(d) { return d.transport === "usb" ? 0 : (d.rotational && d.transport !== "virtio") ? 1 : d.transport === "nvme" ? 3 : 2; }
    function adviseDrives(drives) {
        for (const g of list.filter(x => x.source === "Steam" && x.size > 2e9)) {
            const d = drives.find(x => x.library === g.library);
            if (!d || rank(d) > 2) continue;
            const target = drives.find(f => rank(f) > rank(d) && f.free > g.size * 1.2);
            if (!target) continue;
            if ((Prefs.drivesAdvised || []).indexOf(g.id) !== -1) continue;
            Prefs.drivesAdvised = (Prefs.drivesAdvised || []).concat([g.id]);
            Toasts.show(Tr.f("{name} is on a slow drive", { name: g.name }),
                        Tr.f("It would load faster from {lib} ({free} free). Steam moves it: Properties > Installed Files > Move install folder.", { lib: target.library.replace(Quickshell.env("HOME"), "~"), free: Activities.size(target.free) }),
                        Icons.harddisk, null,
                        [{ text: Tr.t("Open in Steam"), primary: true, run: () => Quickshell.execDetached(["steam", "steam://nav/games/details/" + g.appid]) }], 0);
            return;   // one card at a time
        }
    }
}
