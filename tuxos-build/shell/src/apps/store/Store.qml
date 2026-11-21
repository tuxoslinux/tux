import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Store and updates (mockup apps/10-store): picked apps by category,
// search across the repositories, Flathub and the AUR, the gaming set in
// one click, updates (with Undo: the versions from before come back from
// pacman's cache), installed apps, sources. Repository changes go through
// pkexec tuxos-pkg; Flathub apps install for the user (no password); AUR
// apps build in a terminal with yay, where you can read what is built.
AppWindow {
    id: app
    appName: "Store"
    appIcon: 0xf0110
    searchable: true
    searchHint: "Search apps, games and packages"
    property string page: Quickshell.env("TUXOS_PAGE") || "discover"
    IpcHandler { target: "store"; function page(id: string): void { app.page = id; } }

    // ---- what is installed
    property var pkgs: ({})                  // name -> version
    property var flatpaks: ({})              // id -> true
    Cmd {
        id: installedProc
        command: ["sh", "-c", "pacman -Q; echo ---; command -v flatpak >/dev/null && flatpak list --app --columns=application 2>/dev/null"]
        Component.onCompleted: run()
        onDone: out => {
            const [a, b] = out.split("---\n");
            const p = {}; for (const l of (a || "").split("\n")) { const t = l.split(" "); if (t[1]) p[t[0]] = t[1]; }
            const f = {}; for (const l of (b || "").split("\n")) if (l.trim()) f[l.trim()] = true;
            app.pkgs = p; app.flatpaks = f;
        }
    }
    function isInstalled(a) { return !!((a.pkg && pkgs[a.pkg] !== undefined) || (a.aur && pkgs[a.aur] !== undefined) || (a.flatpak && flatpaks[a.flatpak] === true)); }

    // ---- updates (repositories: checkupdates; Flathub)
    property var updates: []
    property bool checking: false
    Cmd {
        id: updProc
        command: ["sh", "-c", "{ checkupdates 2>/dev/null || pacman -Qu 2>/dev/null; } | grep -v '\\[ignored\\]'; echo ---; command -v flatpak >/dev/null && flatpak remote-ls --updates --app --columns=application 2>/dev/null"]
        Component.onCompleted: { app.checking = true; run(); }
        onDone: out => {
            app.checking = false;
            const [a, b] = out.split("---\n");
            const l = [];
            for (const line of (a || "").split("\n")) { const m = /^(\S+) (\S+) -> (\S+)/.exec(line); if (m) l.push({ name: m[1], from: m[2], to: m[3], kind: "pkg" }); }
            for (const line of (b || "").split("\n")) if (line.trim()) l.push({ name: line.trim(), from: "", to: "", kind: "flatpak" });
            app.updates = l;
        }
    }
    readonly property var important: updates.filter(u => /^(linux|mesa|nvidia|helium|steam|vulkan|proton)/.test(u.name)).map(u => u.name)

    // ---- jobs: one at a time, output shown
    property string jobText: ""
    property string jobFor: ""
    Process {
        id: job
        property var after: null
        stdout: SplitParser { onRead: line => { if (line.trim()) app.jobText = line.trim().slice(0, 140); } }
        stderr: SplitParser { onRead: line => { if (line.trim() && !/^(warning|::)/.test(line)) app.jobText = line.trim().slice(0, 140); } }
        onExited: code => {
            app.jobText = code === 0 ? Tr.t("Done") : (code === 126 || code === 127 ? Tr.t("Cancelled") : Tr.f("Did not finish - {m}", { m: app.jobText }));
            const a = after; after = null; app.jobFor = "";
            installedProc.run(); updProc.run();
            if (a) a(code);
        }
    }
    function run(cmd, forName, after) {
        if (job.running) return;
        jobFor = forName || ""; jobText = Tr.t("Starting...");
        job.after = after || null; job.command = cmd; job.running = true;
    }
    function install(a) {
        if (a.pkg && repoHas(a.pkg)) run(["pkexec", "tuxos-pkg", "install", a.pkg], a.name);
        else if (a.flatpak) run(["sh", "-c", "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && flatpak install --user -y --noninteractive flathub \"$1\"", "sh", a.flatpak], a.name);
        else if (a.aur) aurInstall(a.aur);
        else if (a.pkg) run(["pkexec", "tuxos-pkg", "install", a.pkg], a.name);
    }
    function remove(a) {
        if (a.flatpak && flatpaks[a.flatpak]) run(["flatpak", "uninstall", "--user", "-y", "--noninteractive", a.flatpak], a.name);
        else { const n = a.pkg && pkgs[a.pkg] !== undefined ? a.pkg : a.aur; run(["pkexec", "tuxos-pkg", "remove", n], a.name); }
    }
    function aurInstall(name) {
        // AUR packages are built from scripts anyone can upload: built in a terminal where they can be read first
        Quickshell.execDetached(["sh", "-c", "exec \"$1\" -e sh -c 'yay -S \"$0\"; echo; echo Press Enter to close; read x' \"$2\"", "sh", Prefs.terminal || "kitty", name]);
        jobText = Tr.t("Building in the terminal - follow it there");
    }
    // which repository packages exist (for the picked apps)
    property var repoNames: ({})
    Cmd {
        id: repoProc
        command: ["sh", "-c", "pacman -Slq 2>/dev/null"]
        Component.onCompleted: run()
        onDone: out => { const m = {}; for (const l of out.split("\n")) if (l) m[l] = true; app.repoNames = m; }
    }
    function repoHas(n) { return repoNames[n] === true; }

    // ---- search: picked apps, repositories, Flathub, AUR
    property var results: []
    property bool searching: false
    onSearchAccepted: doSearch()
    onSearchChanged: { if (!app.search.trim()) { results = []; } else searchTimer.restart(); }
    Timer { id: searchTimer; interval: 450; onTriggered: app.doSearch() }
    function doSearch() {
        const q = app.search.trim();
        if (q.length < 2) return;
        searching = true;
        searchProc.command = ["sh", "-c", `
q="$1"
pacman -Ss -- "$q" 2>/dev/null | head -n 60
echo "---F"
command -v flatpak >/dev/null && flatpak search --columns=application,name,description -- "$q" 2>/dev/null | head -n 15
echo "---A"
curl -fsS --max-time 6 "https://aur.archlinux.org/rpc/v5/search/$(printf %s "$q" | jq -sRr @uri)?by=name-desc" 2>/dev/null | jq -r '.results | sort_by(-.Popularity) | .[:15][] | [.Name, .Description // ""] | @tsv'`, "sh", q];
        searchProc.running = true;
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                app.searching = false;
                const [a, rest] = text.split("---F\n");
                const [f, aur] = (rest || "").split("---A\n");
                const out = [];
                const lines = (a || "").split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const m = /^(\S+)\/(\S+) (\S+)/.exec(lines[i]);
                    if (m) out.push({ name: m[2], sub: (lines[i + 1] || "").trim(), source: m[1], pkg: m[2], icon: 0xf03d3 });
                }
                for (const l of (f || "").split("\n")) { const t = l.split("\t"); if (t.length >= 2 && t[0].indexOf(".") > 0) out.push({ name: t[1], sub: t[2] || "", source: "Flathub", flatpak: t[0], icon: 0xf03d3 }); }
                for (const l of (aur || "").split("\n")) { const t = l.split("\t"); if (t[0]) out.push({ name: t[0], sub: t[1] || "", source: "AUR", aur: t[0], icon: 0xf03d3 }); }
                app.results = out;
            }
        }
    }

    // ---- sidebar
    Column {
        id: side
        x: 12; y: 12; width: 226
        spacing: 4
        Repeater {
            model: Catalog.cats.concat([["", "YOUR SYSTEM", 0], ["updates", "Updates", 0xf01da], ["installed", "Installed", 0xf012c], ["sources", "Sources", 0xf0493]])
            delegate: Item {
                required property var modelData
                width: side.width; height: modelData[0] === "" ? 34 : 38
                Text { visible: modelData[0] === ""; x: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
                Rectangle {
                    visible: modelData[0] !== ""
                    anchors.fill: parent; radius: 11
                    readonly property bool on: app.page === modelData[0] && !app.search.trim()
                    color: on ? Theme.accentFill : (sh.hovered ? Theme.fill : "transparent")
                    border.width: on ? 1 : 0; border.color: Theme.accentLine
                    Row { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 12
                        Text { text: String.fromCodePoint(modelData[2] || 32); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: parent.parent.on ? Theme.accent : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; anchors.verticalCenter: parent.verticalCenter } }
                    Text { visible: modelData[0] === "updates" && app.updates.length > 0; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: app.updates.length; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.accent }
                    HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { app.page = modelData[0]; app.search = ""; } }
                }
            }
        }
    }
    Rectangle { x: side.x + side.width + 11; y: 0; width: 1; height: parent.height; color: Theme.glassLine }

    Flickable {
        id: main
        anchors { left: side.right; leftMargin: 28; right: parent.right; rightMargin: 24; top: parent.top; topMargin: 20; bottom: jobBar.visible ? jobBar.top : parent.bottom; bottomMargin: 12 }
        contentHeight: col.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: main.width
            spacing: 16

            // banner: the gaming set
            Rectangle {
                visible: app.page === "discover" && !app.search.trim()
                width: parent.width; height: 196; radius: 22
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) } GradientStop { position: 1; color: Theme.fill } }
                border.width: 1; border.color: Theme.glassLine
                Text { anchors { right: parent.right; rightMargin: 40; verticalCenter: parent.verticalCenter } text: String.fromCodePoint(0xf0297); font.family: Theme.symbols; font.pixelSize: Theme.px(120); color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) }
                Column {
                    anchors { left: parent.left; leftMargin: 32; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Rectangle { width: tag.implicitWidth + 16; height: 24; radius: 7; color: Theme.accentFill; Text { id: tag; anchors.centerIn: parent; text: Tr.t("Gaming"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.accent } }
                    Text { text: Tr.t("Everything for games, in one click"); font.family: Theme.font; font.pixelSize: Theme.px(28); font.weight: Font.Bold; color: Theme.text }
                    Text { text: Tr.t("Steam, Proton-CachyOS, MangoHud and gamescope, set up for TuxOS game mode."); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
                    Btn { text: app.pkgs.steam !== undefined ? "Installed" : "Install the gaming set"; primary: app.pkgs.steam === undefined; icon: 0xf01da
                          onClicked: if (app.pkgs.steam === undefined) app.run(["pkexec", "tuxos-gaming"], "gaming") }
                }
            }
            // updates summary
            Rectangle {
                visible: (app.page === "discover" && !app.search.trim() && app.updates.length > 0) || (app.page === "updates" && !app.search.trim())
                width: parent.width; height: 76; radius: 18
                color: Theme.fill; border.width: 1; border.color: Theme.glassLine
                Rectangle { id: ui; x: 16; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40; radius: 11; color: Theme.accent
                    Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf01da); font.family: Theme.symbols; font.pixelSize: Theme.px(20); color: Theme.accentInk } }
                Column { anchors { left: ui.right; leftMargin: 12; verticalCenter: parent.verticalCenter; right: upBtns.left; rightMargin: 12 } spacing: 4
                    Text { text: app.checking ? Tr.t("Checking for updates...") : (app.updates.length ? Tr.f(app.updates.length === 1 ? "{n} update ready" : "{n} updates ready", { n: app.updates.length }) : Tr.t("TuxOS is up to date")); font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text }
                    Text { width: parent.width; elide: Text.ElideRight; text: app.important.length ? app.important.slice(0, 4).join(", ") : Tr.t("Drivers, kernel and apps together; Undo puts the old versions back"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted } }
                Row { id: upBtns; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } spacing: 8
                    Btn { visible: app.page === "updates"; text: "Undo the last update"; onClicked: app.run(["pkexec", "tuxos-pkg", "undo"], "undo") }
                    Btn { visible: app.updates.length > 0; text: "Update all"; primary: true
                          onClicked: app.run(["sh", "-c", "pkexec tuxos-pkg update && { command -v flatpak >/dev/null && flatpak update --user -y --noninteractive 2>/dev/null; true; }"], "update") } }
            }
            // heading
            Text {
                visible: !(app.page === "discover" && !app.search.trim())
                text: app.search.trim() ? Tr.f("Results for \"{q}\"", { q: app.search.trim() }) : Tr.t((Catalog.cats.find(c => c[0] === app.page) || [0, { updates: "Updates", installed: "Installed", sources: "Sources" }[app.page] || ""])[1])
                font.family: Theme.font; font.pixelSize: Theme.px(28); font.weight: Font.Bold; color: Theme.text
            }
            Text { visible: app.page === "discover" && !app.search.trim(); text: Tr.t("POPULAR"); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
            // picked apps
            Grid {
                visible: !app.search.trim() && app.page !== "updates" && app.page !== "installed" && app.page !== "sources"
                columns: Math.max(1, Math.floor((col.width + 14) / 290))
                spacing: 12
                Repeater {
                    model: Catalog.apps.filter(a => app.page === "discover" ? a.popular : a.cat === app.page)
                    delegate: AppCard { required property var modelData; item: modelData; width: (col.width - 14 * (parent.columns - 1)) / parent.columns }
                }
            }
            // search results
            Text { visible: app.search.trim() && app.searching; text: Tr.t("Searching..."); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
            Grid {
                visible: app.search.trim() !== ""
                columns: Math.max(1, Math.floor((col.width + 14) / 290))
                spacing: 12
                Repeater {
                    model: app.search.trim() ? Catalog.apps.filter(a => (a.name + " " + a.sub).toLowerCase().indexOf(app.search.trim().toLowerCase()) !== -1).concat(app.results) : []
                    delegate: AppCard { required property var modelData; item: modelData; width: (col.width - 14 * (parent.columns - 1)) / parent.columns }
                }
            }
            // updates list
            Repeater {
                model: app.page === "updates" && !app.search.trim() ? app.updates : []
                delegate: Rectangle {
                    required property var modelData
                    width: col.width; height: 44; radius: 11; color: Theme.fill
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                    Text { anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: modelData.kind === "flatpak" ? "Flathub" : modelData.from + "  →  " + modelData.to; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                }
            }
            // installed
            Repeater {
                model: app.page === "installed" && !app.search.trim() ? Catalog.apps.filter(a => app.isInstalled(a)).concat(Object.keys(app.flatpaks).filter(id => !Catalog.apps.some(a => a.flatpak === id)).map(id => ({ name: id, sub: "Flathub", flatpak: id, icon: 0xf03d3 }))) : []
                delegate: AppCard { required property var modelData; item: modelData; width: col.width }
            }
            Text { visible: app.page === "installed" && !app.search.trim(); width: col.width; wrapMode: Text.Wrap; text: Tr.t("Apps from the Store and Flathub. Everything else that is installed shows in Settings > Storage."); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
            // sources
            SettingCard {
                visible: app.page === "sources" && !app.search.trim()
                width: col.width
                SettingRow { title: "TuxOS, Artix and Arch"; description: "The system and most apps · signed packages" }
                SettingRow { title: "CachyOS"; description: "Faster builds for your processor (x86-64-v3 / v4 / Zen 4)" }
                SettingRow { title: "Flathub"; description: "Apps in their own sandbox · installed for you only, no password"; Text { text: Object.keys(app.flatpaks).length ? Tr.f("{n} apps", { n: Object.keys(app.flatpaks).length }) : Tr.t("added on first use"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted } }
                SettingRow { title: "AUR"; description: "Community build scripts · built in a terminal with yay so you can read them first"; last: true }
            }
        }
    }

    // ---- job bar
    Rectangle {
        id: jobBar
        visible: app.jobText !== ""
        anchors { left: side.right; leftMargin: 28; right: parent.right; rightMargin: 24; bottom: parent.bottom; bottomMargin: 12 }
        height: 52; radius: 14
        color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
        Text { anchors { left: parent.left; leftMargin: 16; right: closeJob.left; rightMargin: 12; verticalCenter: parent.verticalCenter } elide: Text.ElideRight
               text: (job.running && app.jobFor ? app.jobFor + ": " : "") + app.jobText; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text }
        Text { id: closeJob; visible: !job.running; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: String.fromCodePoint(0xf0156); font.family: Theme.symbols; font.pixelSize: Theme.px(16); color: Theme.muted
               TapHandler { onTapped: app.jobText = "" } }
    }

    component AppCard: Rectangle {
        id: card
        property var item
        readonly property bool installed: app.isInstalled(item)
        readonly property bool busy: job.running && app.jobFor === item.name
        height: 76; radius: 18
        color: ch.hovered ? Theme.fillHover : Theme.fill
        border.width: 1; border.color: Theme.glassLine
        Rectangle { id: ic; x: 16; anchors.verticalCenter: parent.verticalCenter; width: 46; height: 46; radius: 13; color: Theme.ink(0.08)
            Text { anchors.centerIn: parent; text: String.fromCodePoint(card.item.icon || 0xf03d3); font.family: Theme.symbols; font.pixelSize: Theme.px(22); color: Theme.text } }
        Column { anchors { left: ic.right; leftMargin: 12; right: btn.left; rightMargin: 8; verticalCenter: parent.verticalCenter } spacing: 4
            Text { width: parent.width; text: card.item.name; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
            Text { width: parent.width; text: Tr.t(card.item.sub || "") + (card.item.source ? " · " + card.item.source : ""); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted } }
        Btn {
            id: btn
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: card.busy ? "Working..." : card.installed ? (rh.hovered ? "Remove" : "Installed") : "Install"
            primary: !card.installed && !card.busy
            danger: card.installed && rh.hovered
            enabled2: !job.running
            onClicked: { if (job.running) return; card.installed ? app.remove(card.item) : app.install(card.item); }
            HoverHandler { id: rh }
        }
        HoverHandler { id: ch }
    }
}
