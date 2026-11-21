import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services

// Everything the launcher can find for a query (SPEC "App launcher",
// round 3-5): answers (maths, units, money, time in a city), apps, app
// actions, TuxOS Control pages, commands, events from plain text, files,
// the local AI and the web. Results: { title, subtitle, tag, icon | entry,
// run() }.
QtObject {
    id: search

    property string query: ""
    readonly property string q: query.trim().toLowerCase()

    // helper entries TuxOS keeps out of the launcher (still searchable by id)
    readonly property var hidden: ["footclient", "foot-server", "qv4l2", "qvidcap", "xfce4-about", "avahi-discover", "bssh", "bvnc",
        "lstopo", "mate-color-select", "nm-connection-editor", "kitty-open", "mpv", "uxterm", "xterm", "assistant", "designer",
        "linguist", "qdbusviewer", "org.kde.kdeconnect.nonplasma", "electron", "cmake-gui", "htop", "btop", "vim", "nvim"]
    // ---- apps, most used first
    readonly property var apps: {
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay && hidden.indexOf(e.id) === -1);
        const u = Usage.counts;
        return all.slice().sort((a, b) => ((u[b.id] || 0) - (u[a.id] || 0)) || a.name.localeCompare(b.name));
    }

    // DesktopEntry lists (keywords, categories) arrive as string lists
    function words(v) { return (typeof v === "string" ? v : (v ? Array.from(v).join(" ") : "")).toLowerCase(); }

    function score(e) {
        const n = e.name.toLowerCase();
        let s = 0;
        if (n === q) s = 100;
        else if (n.startsWith(q)) s = 80;
        else if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) s = 60;
        else if (n.indexOf(q) !== -1) s = 40;
        else if (words(e.genericName).indexOf(q) !== -1 || words(e.keywords).indexOf(q) !== -1) s = 25;
        else if (e.id.toLowerCase().indexOf(q) !== -1 || words(e.comment).indexOf(q) !== -1) s = 12;
        else if (fuzzy(n, q)) s = 8;
        if (s > 0) s += Math.min(15, Usage.count(e.id));
        return s;
    }
    function fuzzy(text, pat) {
        let j = 0;
        for (let k = 0; k < text.length && j < pat.length; k++) if (text[k] === pat[j]) j++;
        return j === pat.length && pat.length >= 3;
    }

    // ---- TuxOS Control pages
    readonly property var pages: [
        ["appearance", "Appearance", "theme dark light accent colour color glass blur font"],
        ["appearance", "Wallpaper", "background picture live depth lock screen"],
        ["appearance", "Share your setup", "tuxtheme export import theme share"],
        ["displays", "Displays", "monitor screen resolution refresh rate hz scale hdr vrr"],
        ["sound", "Sound", "audio volume speaker headset microphone mic eq equalizer noise"],
        ["network", "Network & Wi-Fi", "wifi internet ethernet vpn dns proxy"],
        ["bluetooth", "Bluetooth", "devices headphones controller pair"],
        ["gaming", "Gaming", "steam fps hud vrr tearing frame limit game mode proton"],
        ["performance", "Performance", "cpu scheduler zram tuning power profile"],
        ["power", "Power & battery", "battery sleep lid charge limit"],
        ["notifications", "Notifications", "do not disturb dnd focus modes"],
        ["keyboard", "Keyboard & shortcuts", "keys layout bulgarian shortcuts snippets"],
        ["mouse", "Mouse & touchpad", "dpi pointer cursor gestures touchpad"],
        ["apps", "Default apps", "browser terminal music messaging files"],
        ["updates", "Updates & drivers", "update upgrade driver nvidia kernel rollback undo"],
        ["users", "Users", "account password avatar fingerprint"],
        ["privacy", "Privacy & security", "camera microphone location secure boot encryption search index"],
        ["datetime", "Date & time", "clock timezone world clocks 24h"],
        ["region", "Language & region", "language bulgarian english formats translate"],
        ["accessibility", "Accessibility", "reduce motion contrast zoom larger text screen reader"],
        ["storage", "Storage & cleanup", "disk space clean trash downloads"],
        ["ai", "AI", "ollama local ask assistant"],
        ["winapps", "Apps for Windows", "windows exe msi wine proton umu program"],
        ["developer", "Developer", "developer code git ssh key podman docker distrobox ubuntu fedora debian"],
        ["performance", "Fans", "fan curve quiet cooling noise rpm"],
        ["about", "About TuxOS", "version system info hardware report problem bug"]
    ]

    // ---- command palette
    readonly property var commands: [
        ["wifi off", "Turn Wi-Fi off", Icons.wifiOff, "nmcli radio wifi off"],
        ["wifi on", "Turn Wi-Fi on", Icons.wifi, "nmcli radio wifi on"],
        ["bluetooth off", "Turn Bluetooth off", Icons.bluetoothOff, "bluetoothctl power off"],
        ["bluetooth on", "Turn Bluetooth on", Icons.bluetooth, "bluetoothctl power on"],
        ["restart audio", "Restart audio", Icons.volumeHigh, "dinitctl restart pipewire pipewire-pulse wireplumber 2>/dev/null || { pkill -x wireplumber; pkill -x pipewire-pulse; pkill -x pipewire; sleep 0.5; (pipewire & pipewire-pulse & wireplumber &); }"],
        ["empty trash", "Empty the Trash", Icons.trashCanOutline, "gio trash --empty"],
        ["do not disturb", "Do not disturb on / off", Icons.bellOff, "@dnd"],
        ["dnd", "Do not disturb on / off", Icons.bellOff, "@dnd"],
        ["night light on", "Night light on", Icons.weatherNight, "pkill -x hyprsunset; hyprsunset -t 4500 &"],
        ["night light off", "Night light off", Icons.whiteBalanceSunny, "pkill -x hyprsunset"],
        ["game mode on", "Gaming focus mode on", Icons.gamepadVariant, "@focus:gaming"],
        ["game mode off", "Focus mode off", Icons.gamepadVariant, "@focus:"],
        ["update", "Update the system", Icons.download, "kitty --title 'TuxOS update' sh -c 'sudo pacman -Syu; echo; read -p \"Done. Enter closes.\" x'"],
        ["screenshot", "Take a screenshot", Icons.monitorScreenshot, "@screenshot"],
        ["record screen", "Start / stop screen recording", Icons.recordRec, "@record"],
        ["colour picker", "Pick a colour from the screen", Icons.eyedropper, "hyprpicker -a"],
        ["color picker", "Pick a colour from the screen", Icons.eyedropper, "hyprpicker -a"],
        ["emoji", "Emoji picker", Icons.emoticonHappyOutline, "@overlay:emoji"],
        ["clipboard", "Clipboard history", Icons.clipboardTextOutline, "@overlay:clipboard"],
        ["shortcuts", "Keyboard shortcuts", Icons.keyboard, "@overlay:sheet"],
        ["notes", "Quick notes", Icons.noteEditOutline, "@overlay:notes"],
        ["lock", "Lock the screen", Icons.lock, "@lock"],
        ["log out", "Log out", Icons.logout, "@logout"],
        ["sleep", "Sleep", Icons.sleep, "@suspend"],
        ["restart", "Restart", Icons.restart, "@reboot"],
        ["shut down", "Shut down", Icons.power, "@poweroff"],
        ["power off", "Shut down", Icons.power, "@poweroff"],
        ["boot menu", "Restart into the boot menu", Icons.restart, "@bootmenu"],
        ["system manager", "System manager", Icons.speedometer, "@app:monitor"],
        ["task manager", "System manager", Icons.speedometer, "@app:monitor"]
    ]

    signal action(string what)   // "@..." commands handled by the launcher

    function runCommand(cmd) {
        if (cmd.startsWith("@")) action(cmd.slice(1));
        else Apps.run(cmd);
    }

    // ---- files (async, after a pause in typing)
    property var files: []
    property var inside: []            // [{ path, snip }] text found inside files (tuxos-index)
    property Timer fileTimer: Timer {
        interval: 180
        onTriggered: {
            if (search.q.length < 3) { search.files = []; return; }
            fileProc.running = false;
            // file names, then text inside files (the index; "@@" between)
            fileProc.command = ["sh", "-c", "find \"$HOME\" -maxdepth 5 \\( -name '.*' -prune \\) -o -iname \"*$1*\" -print 2>/dev/null | head -n 5; echo @@; tuxos-index search \"$1\" 2>/dev/null", "sh", search.query.trim()];
            fileProc.running = true;
        }
    }
    property Process fileProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const [names, inside] = text.split("@@\n");
                search.files = (names || "").split("\n").filter(l => l.length > 0);
                search.inside = (inside || "").split("\n").filter(l => l.indexOf("\t") > 0).map(l => { const i = l.indexOf("\t"); return { path: l.slice(0, i), snip: l.slice(i + 1) }; })
                    .filter(x => search.files.indexOf(x.path) === -1);
            }
        }
    }
    onQueryChanged: { if (q.length < 3) { files = []; inside = []; } fileTimer.restart(); }

    function fileIcon(p) {
        if (/\.(png|jpe?g|webp|gif|svg|avif)$/i.test(p)) return Icons.fileImage;
        if (/\.(mp3|flac|ogg|opus|wav|m4a)$/i.test(p)) return Icons.musicNote;
        if (/\.(mp4|mkv|webm|mov|avi)$/i.test(p)) return Icons.play;
        if (/\.(pdf|odt|docx?|txt|md)$/i.test(p)) return Icons.fileDocument;
        return Icons.file;
    }

    // ---- results
    readonly property var results: {
        const out = [];
        const raw = query.trim();
        if (!raw) return out;
        void Calc.zoneAnswer; void Calc.rates;   // re-run when async answers arrive

        // saved setups: "setup Streaming" opens one, "save setup Work" saves
        // the apps open now (Session)
        const ql = raw.toLowerCase();
        let sm;
        if ((sm = /^save (?:setup|as setup) (.+)$/i.exec(raw)))
            out.push({ title: Tr.f("Save the open apps as setup \"{n}\"", { n: sm[1].trim() }), subtitle: Tr.t("Opens them again on the same desktops later"), tag: "Setup", icon: Icons.restore, run: () => Session.saveSetup(sm[1]) });
        for (const name of Object.keys(Session.setups)) {
            const n = name.toLowerCase();
            if (n.indexOf(ql) === 0 || ("setup " + n).indexOf(ql) === 0 || (ql.length > 2 && n.indexOf(ql) !== -1)) {
                const apps = Session.setups[name];
                out.push({ title: Tr.f("Open setup \"{n}\"", { n: name }), subtitle: Tr.f("{n} apps on their desktops", { n: apps.length }), tag: "Setup", icon: Icons.restore, run: () => Session.openSetup(name) });
            }
        }
        if (/^setups?$/.test(ql) && Object.keys(Session.setups).length === 0)
            out.push({ title: Tr.t("No saved setups yet"), subtitle: Tr.t("Open some apps, then type \"save setup Streaming\""), tag: "Setup", icon: Icons.restore, run: () => {} });

        // local AI: "?" prefix (SPEC round 4: Ollama, off by default)
        // hidden in lite mode (SPEC: old PCs) unless local AI was turned on
        if (raw.startsWith("?") && raw.length > 1 && (!Theme.lite || Prefs.aiEnabled))
            out.push({ title: Tr.t("Ask: ") + raw.slice(1).trim(), subtitle: Tr.t("Local AI (Ollama) · off by default, turn on in TuxOS Control > AI"), tag: "Ask", icon: Icons.robot, run: () => action("ask:" + raw.slice(1).trim()) });

        const ans = Calc.answer(raw);
        if (ans) out.push({ title: ans.title, subtitle: ans.subtitle, tag: ans.kind, icon: ans.kind === "Time" ? Icons.clockOutline : ans.kind === "Currency" ? Icons.currencyUsd : Icons.calculator,
                             run: () => { if (ans.copy) Quickshell.clipboardText = ans.copy; }, hint: Tr.t("Enter to copy") });
        if (raw.startsWith("=")) return out;

        const ev = Events.parse(raw);
        const scored = [];
        for (const e of apps) { const s = score(e); if (s > 0) scored.push([s, e]); }
        scored.sort((a, b) => b[0] - a[0]);
        for (const [s, e] of scored.slice(0, 6))
            out.push({ entry: e, title: e.name, subtitle: e.genericName || e.comment || Tr.t("Application"), tag: "App", run: () => Usage.launch(e), hint: Tr.t("Enter to open") });

        // games (Steam, Heroic, Lutris), with their cover and "Will it run?"
        const gq = q.replace(/^(play|игра)\s+/, "");
        for (const g of Games.list) {
            const n = g.name.toLowerCase();
            if (gq.length < 2 || (n.indexOf(gq) === -1 && !n.split(/\s+/).some(w => w.startsWith(gq)))) continue;
            const b = Games.badgeOf(g);
            const item = { title: g.name, subtitle: g.source + (b ? " · " + Games.tierText(b) + (Games.antiText(b) ? ", " + Games.antiText(b) : "") : ""),
                           tag: "Game", cover: g.cover || "", icon: g.cover ? undefined : Icons.gamepadVariant, run: () => Games.launch(g), hint: Tr.t("Enter to play") };
            if (b) item.badgeColor = Games.tierColor(b);
            // a name that starts with the query beats apps
            if (n.startsWith(gq)) out.unshift(item); else out.push(item);
        }

        // app actions ("Firefox: new private window") for the best matches
        for (const [s, e] of scored.slice(0, 2))
            for (const a of (e.actions || [])) {
                if (s >= 60 || a.name.toLowerCase().indexOf(q) !== -1)
                    out.push({ entry: e, title: `${e.name}: ${a.name.toLowerCase()}`, subtitle: "", tag: "Action", run: () => { Usage.bump(e.id); a.execute(); } });
            }

        for (const c of commands)
            if (c[0].startsWith(q) || (q.length >= 3 && c[0].indexOf(q) !== -1) || (q.length >= 4 && (c[1].toLowerCase().indexOf(q) !== -1 || Tr.t(c[1]).toLowerCase().indexOf(q) !== -1)))
                if (!out.some(o => o.title === Tr.t(c[1]))) out.push({ title: Tr.t(c[1]), subtitle: "", tag: "Command", icon: c[2], run: () => runCommand(c[3]), hint: Tr.t("Enter to run") });

        // "kill <app>"
        const km = /^(?:kill|end|убий)\s+(\S+)/i.exec(raw);
        if (km) out.push({ title: Tr.f("End {n}", { n: km[1] }), subtitle: Tr.t("Closes every process named ") + km[1], tag: "Command", icon: Icons.close, run: () => Quickshell.execDetached(["pkill", "-i", "-x", km[1]]) });

        if (q.length >= 2)
            for (const p of pages)
                if (p[1].toLowerCase().indexOf(q) !== -1 || Tr.t(p[1]).toLowerCase().indexOf(q) !== -1 || (q.length >= 3 && p[2].indexOf(q) !== -1))
                    out.push({ title: Tr.t(p[1]), subtitle: "", tag: "TuxOS Control", icon: p[0] === "privacy" ? Icons.shield : Icons.cog,
                               run: () => Apps.run(`${Prefs.settingsApp} --page ${p[0]}`) });

        if (ev) {
            const d = new Date(ev.start);
            const when = Tr.date(d, ev.allDay ? "ddd d MMM" : "ddd d MMM, HH:mm");
            out.push({ title: Tr.t("Add to calendar: ") + ev.title, subtitle: when, tag: "Event", icon: Icons.calendar, run: () => Events.add(ev.title, ev.start), hint: Tr.t("Enter to add") });
        }

        for (const f of files)
            out.push({ title: f.split("/").pop(), subtitle: "", tag: f.replace(Quickshell.env("HOME"), "~").replace(/\/[^/]*$/, ""), icon: fileIcon(f), run: () => Quickshell.execDetached(["gio", "open", f]) });
        // text inside documents and notes
        for (const x of inside.slice(0, 4))
            out.push({ title: x.path.split("/").pop(), subtitle: x.snip, tag: Tr.t("Inside"), icon: fileIcon(x.path), run: () => Quickshell.execDetached(["gio", "open", x.path]), hint: Tr.t("Enter to open") });

        out.push({ title: Tr.f("Search the web for \"{q}\"", { q: raw }), subtitle: "", tag: "Web", icon: Icons.web,
                   run: () => Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(raw)]), hint: Tr.t("Enter to search") });
        return out;
    }
}
