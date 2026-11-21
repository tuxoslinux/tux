import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import Quickshell.Hyprland

// Gaming (mockup apps/02-settings2): game mode (tuxos-gamed), what changes
// while a game runs, tear-free settings, tools.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Gaming"); description: Tr.t("TuxOS switches into game mode by itself whenever a game runs.") }
    property var conf: ({})
    Cmd { id: rc; command: ["sh", "-c", "cat /etc/tuxos/performance.conf 2>/dev/null; echo; command -v steam >/dev/null && echo HAS_STEAM; command -v mangohud >/dev/null && echo HAS_MANGO; command -v gamescope >/dev/null && echo HAS_GAMESCOPE"]
          Component.onCompleted: run()
          onDone: out => { const c = {}; for (const l of out.split("\n")) { const m = /^(\w+)=(.*)$/.exec(l); if (m) c[m[1]] = m[2].replace(/"/g, ""); else if (l.startsWith("HAS_")) c[l] = true; } page.conf = c; } }
    // system settings need the admin password once (pkexec)
    function setConf(key, value) {
        Quickshell.execDetached(["sh", "-c", "pkexec \"$@\" || exit 1", "sh", "sh", "-c", `f=/etc/tuxos/performance.conf; mkdir -p /etc/tuxos; touch "$f"; grep -q '^${key}=' "$f" && sed -i 's/^${key}=.*/${key}=${value}/' "$f" || echo '${key}=${value}' >> "$f"; dinitctl restart tuxos-gamed >/dev/null 2>&1 || true`]);
        const c = Object.assign({}, conf); c[key] = value; conf = c;
    }
    Rectangle {
        width: parent.width; height: 78; radius: 18
        color: Theme.ink(0.035); border.width: 1; border.color: Theme.glassLine
        Row {
            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 12
            Rectangle { width: 40; height: 40; radius: 12; color: Theme.accent; Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf0297); font.family: Theme.symbols; font.pixelSize: Theme.px(19); color: Theme.accentInk } }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: Notifs.gameRunning ? "Game mode is on" : "Game mode is ready"; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
                Text { text: Notifs.gameRunning ? "A game is running right now" : "It turns on by itself when a Steam, Proton or gamescope game starts"; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
            }
        }
    }
    SettingCard {
        header: Tr.t("While a game runs")
        SettingRow { title: Tr.t("Power profile"); description: Tr.t("Performance while playing, back after"); Toggle { checked: (page.conf.GAME_POWER_PROFILE || "performance") === "performance"; onToggled: v => page.setConf("GAME_POWER_PROFILE", v ? "performance" : "balanced") } }
        SettingRow { title: Tr.t("CPU scheduler"); description: Tr.t("BORE is fastest in TuxOS' tests; sched-ext schedulers are optional")
            Segmented { width: 330; options: ["BORE", "scx_lavd", "scx_bpfland"]; current: ["none", "scx_lavd", "scx_bpfland"].indexOf(page.conf.GAME_SCHEDULER || "none"); onPicked: i => page.setConf("GAME_SCHEDULER", ["none", "scx_lavd", "scx_bpfland"][i]) } }
        SettingRow { title: Tr.t("Silence notifications"); description: Tr.t("Do not disturb until the game closes"); Toggle { checked: Prefs.gameSilence; onToggled: v => Prefs.gameSilence = v } }
        SettingRow { title: Tr.t("Pause downloads"); description: Tr.t("System updates, the Store and Flatpak wait until the game closes (Steam: its own setting)"); Toggle { checked: (page.conf.GAME_PAUSE_DOWNLOADS || "yes") === "yes"; onToggled: v => page.setConf("GAME_PAUSE_DOWNLOADS", v ? "yes" : "no") } }
        SettingRow { title: Tr.t("Achievement toasts"); description: Tr.t("Steam achievements show as TuxOS notifications, with their icon"); Toggle { checked: Prefs.achievementToasts; onToggled: v => Prefs.achievementToasts = v } }
        SettingRow { title: Tr.t("Super key alone"); description: Tr.t("Does not open the launcher in full screen"); last: true; Toggle { checked: !Prefs.superInFullscreen; onToggled: v => Prefs.superInFullscreen = !v } }
    }
    SettingCard {
        header: Tr.t("Smooth and tear-free")
        SettingRow { title: Tr.t("Tearing"); description: Tr.t("Off: never tears (VRR + a frame cap a few frames under the refresh rate, V-Sync without VRR)")
            Toggle { checked: Prefs.allowTearing; onToggled: v => Prefs.allowTearing = v } }
        SettingRow { title: Tr.t("Frame limit"); description: Prefs.fpsLimit > 0 ? Prefs.fpsLimit + " FPS for every game (per-game limits win)" : "Off · per-game limits in the Game HUD"; last: true
            Segmented { width: 360; options: ["Off", "60", "120", "144", "165"]; current: [0, 60, 120, 144, 165].indexOf(Prefs.fpsLimit); onPicked: i => {
                const v = [0, 60, 120, 144, 165][i];
                Prefs.fpsLimit = v;
                // MangoHud limits frames inside the game (per-game files in ~/.config/MangoHud win)
                Quickshell.execDetached(["sh", "-c", "f=\"$HOME/.config/MangoHud/MangoHud.conf\"; grep -q '^fps_limit=' \"$f\" && sed -i \"s/^fps_limit=.*/fps_limit=$1/\" \"$f\" || echo \"fps_limit=$1\" >> \"$f\"", "sh", String(v)]);
            } } }
    }
    // ---- GPU tuning (LACT)
    property bool hasLact: false
    Cmd { id: lactCmd; command: ["sh", "-c", "command -v lact >/dev/null && echo yes"]; Component.onCompleted: run(); onDone: out => { page.hasLact = out.trim() === "yes"; if (page.hasLact) Gpu.connect(); } }
    SettingCard {
        header: Tr.t("GPU tuning")
        SettingRow {
            title: Tr.t("Preset")
            description: !page.hasLact ? Tr.t("Needs LACT (from the TuxOS repositories): power limit for AMD, NVIDIA and Intel graphics")
                       : !Gpu.available ? Tr.t("Starting LACT...")
                       : !Gpu.canLimit ? Tr.f("{gpu}: this graphics card does not let LACT change its power limit", { gpu: Gpu.devices.length ? Gpu.devices[0].name : Tr.t("This GPU") })
                       : Tr.f("Power limit {cur} W (stock {def} W, up to {max} W); per game in its profile", { cur: Math.round(Gpu.stats.power.cap_current), def: Math.round(Gpu.stats.power.cap_default || Gpu.stats.power.cap_max), max: Math.round(Gpu.stats.power.cap_max) })
            last: true
            Row {
                spacing: 8
                Btn { visible: !page.hasLact; text: Tr.t("Install"); primary: true
                      onClicked: Quickshell.execDetached(["sh", "-c", "pkexec sh -c 'tuxos-pkg install lact && dinitctl enable lactd' && notify-send 'LACT is installed' 'GPU tuning is ready in Settings > Gaming'"]) }
                Segmented { visible: page.hasLact && Gpu.canLimit; width: 340; options: ["Quiet", "Stock", "Performance"]; current: Math.max(0, ["quiet", "stock", "performance"].indexOf(Gpu.preset)); onPicked: i => Gpu.choose(["quiet", "stock", "performance"][i]) }
            }
        }
    }

    // ---- game streaming host (Sunshine): Moonlight on a phone, TV or laptop
    property bool streamOn: false
    property bool hasSunshine: false
    property var clients: []
    property string pairMsg: ""
    Cmd { id: stCmd; command: ["sh", "-c", "command -v sunshine >/dev/null && echo HAVE; tuxos-stream status; tuxos-stream clients"]; Component.onCompleted: run()
          onDone: out => { const l = out.split("\n").filter(x => x); page.hasSunshine = l[0] === "HAVE"; const r = page.hasSunshine ? l.slice(1) : l; page.streamOn = r[0] === "on"; page.clients = r.slice(1); } }
    Cmd { id: pairCmd; onDone: (out, code) => { page.pairMsg = code === 0 ? Tr.t("Paired: the device can play now") : code === 4 ? Tr.t("No device is waiting: add this PC in Moonlight first") : Tr.t("Wrong PIN, or the request timed out: try again"); stCmd.run(); } }
    SettingCard {
        header: Tr.t("Game streaming")
        SettingRow {
            title: Tr.t("Stream this PC's games"); description: page.hasSunshine ? Tr.t("Moonlight on a phone, TV or laptop plays them (Sunshine)") : Tr.t("Needs Sunshine (from the TuxOS repositories)")
            Row {
                spacing: 8
                Btn { visible: !page.hasSunshine; text: Tr.t("Install"); primary: true; onClicked: Quickshell.execDetached(["sh", "-c", "pkexec tuxos-pkg install sunshine && notify-send 'Sunshine is installed' 'Game streaming can be turned on in Settings > Gaming'"]) }
                Toggle { visible: page.hasSunshine; checked: page.streamOn; onToggled: v => { page.streamOn = v; Quickshell.execDetached(["tuxos-stream", v ? "on" : "off"]); Streaming.refresh(); } }
            }
        }
        SettingRow {
            visible: page.streamOn
            title: Tr.t("Pair a device"); description: page.pairMsg || Tr.t("In Moonlight, add this PC; type the 4-digit PIN it shows here")
            Row {
                spacing: 8
                Rectangle {
                    width: 90; height: 34; radius: 10
                    color: Theme.ink(0.05); border.width: 1; border.color: Theme.glassLine
                    TextInput {
                        id: pinIn
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        maximumLength: 4; validator: RegularExpressionValidator { regularExpression: /[0-9]{0,4}/ }
                        font.family: Theme.font; font.pixelSize: Theme.px(16); font.letterSpacing: 4; color: Theme.text
                        onAccepted: pairBtn.clicked()
                        Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: "PIN"; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                    }
                }
                Btn { id: pairBtn; text: Tr.t("Pair"); primary: true; enabled2: pinIn.text.length === 4
                      onClicked: { page.pairMsg = Tr.t("Pairing..."); pairCmd.command = ["tuxos-stream", "pin", pinIn.text, "Moonlight"]; Qt.callLater(pairCmd.run); pinIn.text = ""; } }
            }
        }
        SettingRow {
            visible: page.streamOn; last: true
            title: Tr.t("Paired devices"); description: page.clients.length ? page.clients.join(" · ") : Tr.t("None yet")
        }
    }

    SettingCard {
        header: Tr.t("Save backups")
        SettingRow {
            title: Tr.t("Back up game saves"); last: true
            description: !Saves.have ? Tr.t("Needs Ludusavi (Flathub): saves of Steam, Heroic, Lutris and emulator games")
                       : Saves.last > 0 ? Tr.f("Daily and before each game update · last {t}", { t: Tr.date(new Date(Saves.last), "d MMM, HH:mm") })
                       : Tr.t("Daily and before each game update · none yet")
            Row {
                spacing: 8
                Btn { visible: !Saves.have; text: Tr.t("Install"); primary: true
                      onClicked: Quickshell.execDetached(["kitty", "--title", "Ludusavi", "sh", "-c", "flatpak install --user -y flathub com.github.mtkennerly.ludusavi; read -p 'Enter closes' x"]) }
                Btn { visible: Saves.have; text: Tr.t("Back up now"); onClicked: Saves.backup("") }
                Toggle { visible: Saves.have; checked: Prefs.saveBackups; onToggled: v => Prefs.saveBackups = v }
            }
        }
    }
    SettingCard {
        header: Tr.t("Instant replay")
        SettingRow { title: Tr.t("Keep the last moments"); description: Tr.t("Super + Alt + R saves them to ~/Videos/Replays (the GPU's video encoder: a few % at most)")
            Segmented { width: 360; options: ["Off", "While a game runs", "Always"]; current: ["off", "games", "always"].indexOf(Prefs.replayMode); onPicked: i => Prefs.replayMode = ["off", "games", "always"][i] } }
        SettingRow { title: Tr.t("Length"); last: true
            Segmented { width: 240; options: ["30 s", "45 s", "60 s"]; current: [30, 45, 60].indexOf(Prefs.replaySeconds); onPicked: i => Prefs.replaySeconds = [30, 45, 60][i] } }
    }
    SettingCard {
        header: Tr.t("Breaks and drives")
        SettingRow { title: Tr.t("Play-time reminders"); description: Tr.t("A gentle note after this long, never mid-match (it waits until the game loses focus)")
            Segmented { width: 300; options: ["Off", "1 h", "2 h", "3 h"]; current: [0, 60, 120, 180].indexOf(Prefs.playReminder); onPicked: i => Prefs.playReminder = [0, 60, 120, 180][i] } }
        SettingRow { title: Tr.t("Drive advisor"); description: Tr.t("Says when a game sits on a slow drive and a faster one has room"); last: true
            Toggle { checked: Prefs.driveAdvisor; onToggled: v => Prefs.driveAdvisor = v } }
    }

    // ---- per-game profiles: the list, or one game's profile
    property var pick: null
    SettingCard {
        header: Tr.t("Games")
        visible: page.pick === null
        Repeater {
            model: Games.list
            delegate: SettingRow {
                required property var modelData
                required property int index
                readonly property var badge: Games.badgeOf(modelData)
                title: modelData.name
                description: modelData.source + (badge ? "  ·  " + Games.tierText(badge) + (Games.antiText(badge) ? ", " + Games.antiText(badge) : "") : "")
                last: index === Games.list.length - 1
                Row {
                    spacing: 8
                    Rectangle {
                        visible: badge !== null
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5; color: Games.tierColor(badge)
                    }
                    Btn { text: Tr.t("Profile"); onClicked: page.pick = modelData }
                }
            }
        }
        SettingRow {
            visible: Games.list.length === 0
            title: Tr.t("No games found yet"); description: Tr.t("Steam, Heroic and Lutris libraries show up here once a game is installed"); last: true
        }
    }
    Loader {
        width: parent.width
        active: page.pick !== null
        sourceComponent: Component {
            Column {
                spacing: 16
                readonly property var g: page.pick
                readonly property var p: Games.profileOf(g.id)
                function set(k, v) { Games.setProfile(g.id, k, v); }
                Row {
                    spacing: 12
                    Btn { text: Tr.t("Back"); icon: Icons.arrowLeft; onClicked: page.pick = null }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: g.name; font.family: Theme.font; font.pixelSize: Theme.px(18); font.weight: Font.DemiBold; color: Theme.text }
                }
                SettingCard {
                    header: Tr.t("While this game runs")
                    SettingRow { title: Tr.t("Frame limit"); description: Tr.t("Also on the Game HUD's slider; \"Screen\" = a few frames under the refresh rate")
                        Segmented { width: 420; options: ["Default", "Off", "30", "60", "120", "144", "Screen"]; current: Math.max(0, [-1, 0, 30, 60, 120, 144, 999].indexOf(p.fps)); onPicked: i => set("fps", [-1, 0, 30, 60, 120, 144, 999][i]) } }
                    SettingRow { title: Tr.t("Allow tearing"); description: Tr.t("Lowest latency for competitive shooters; frames may tear")
                        Segmented { width: 300; options: ["Default", "Allow", "Never"]; current: Math.max(0, ["default", "allow", "never"].indexOf(p.tearing)); onPicked: i => set("tearing", ["default", "allow", "never"][i]) } }
                    SettingRow { title: Tr.t("Refresh rate"); description: Tr.t("Switched while the game runs, back after")
                        ChoiceList { options: [{ value: "", label: Tr.t("Unchanged") }].concat(page.rates.map(r => ({ value: r, label: r + " Hz" }))); current: p.refresh; onPicked: v => set("refresh", v) } }
                    SettingRow { title: Tr.t("VRR"); Segmented { width: 300; options: ["Default", "On", "Off"]; current: Math.max(0, ["default", "on", "off"].indexOf(p.vrr)); onPicked: i => set("vrr", ["default", "on", "off"][i]) } }
                    SettingRow { title: Tr.t("Game HUD"); description: Tr.t("Shown as soon as the game starts"); Toggle { checked: p.hud; onToggled: v => set("hud", v) } }
                    SettingRow { title: Tr.t("Mute the microphone"); Toggle { checked: p.micMute; onToggled: v => set("micMute", v) } }
                    SettingRow { title: Tr.t("Do not disturb"); Segmented { width: 300; options: ["Default", "On", "Off"]; current: Math.max(0, ["default", "on", "off"].indexOf(p.dnd)); onPicked: i => set("dnd", ["default", "on", "off"][i]) } }
                    SettingRow { title: Tr.t("Power profile"); Segmented { width: 360; options: ["Default", "Performance", "Balanced"]; current: Math.max(0, ["default", "performance", "balanced"].indexOf(p.power)); onPicked: i => set("power", ["default", "performance", "balanced"][i]) } }
                    SettingRow { title: Tr.t("GPU tuning"); description: Tr.t("LACT preset while this game runs")
                        Segmented { width: 400; options: ["Default", "Quiet", "Stock", "Performance"]; current: Math.max(0, ["default", "quiet", "stock", "performance"].indexOf(p.gpu)); onPicked: i => set("gpu", ["default", "quiet", "stock", "performance"][i]) } }
                    SettingRow { title: Tr.t("CPU scheduler"); last: true
                        Segmented { width: 400; options: ["Default", "BORE", "scx_lavd", "scx_bpfland"]; current: Math.max(0, ["default", "none", "scx_lavd", "scx_bpfland"].indexOf(p.scheduler)); onPicked: i => set("scheduler", ["default", "none", "scx_lavd", "scx_bpfland"][i]) } }
                }
                SettingCard {
                    header: Tr.t("About this game")
                    SettingRow { title: Tr.t("Will it run?"); description: Games.badgeOf(g) ? Games.tierText(Games.badgeOf(g)) + (Games.antiText(Games.badgeOf(g)) ? " · " + Games.antiText(Games.badgeOf(g)) : "") + " (ProtonDB, AreWeAntiCheatYet)" : Tr.t("Unknown (offline, or not a Steam game)") }
                    SettingRow { visible: Saves.have; title: Tr.t("Saves"); description: Tr.t("Put the newest backup of this game's saves back (Ludusavi)")
                        Btn { text: Tr.t("Restore"); onClicked: Quickshell.execDetached(["sh", "-c", "tuxos-saves restore \"$1\" && notify-send 'Saves restored' \"$1\" || notify-send 'No backup yet' \"$1\"", "sh", g.name]) } }
                    SettingRow { title: Tr.t("Installed in"); description: (g.dir || "").replace(Quickshell.env("HOME"), "~") + (g.size > 0 ? "  ·  " + Activities.size(g.size) : ""); last: true
                        Btn { text: Tr.t("Play"); primary: true; onClicked: Games.launch(g) } }
                }
            }
        }
    }
    // refresh rates the focused monitor offers
    readonly property var rates: {
        const m = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.lastIpcObject : null;
        if (!m || !m.availableModes) return [];
        const out = [];
        for (const x of m.availableModes) { const r = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(x); if (r && +r[1] === m.width && +r[2] === m.height) { const hz = Math.round(parseFloat(r[3])); if (out.indexOf(hz) === -1) out.push(hz); } }
        return out.sort((a, b) => b - a);
    }

    SettingCard {
        header: Tr.t("Tools")
        SettingRow { title: Tr.t("Game HUD"); description: Tr.t("Super + Shift + G: FPS, lows, frame times, temperatures (MangoHud)") + (page.conf.HAS_MANGO ? "" : " · not installed") }
        SettingRow { title: Tr.t("Steam, Proton-CachyOS, gamescope"); description: page.conf.HAS_STEAM ? "Installed · gaming set" : "Not installed"; last: true
            Btn { text: page.conf.HAS_STEAM ? "Manage" : "Install"; primary: !page.conf.HAS_STEAM; onClicked: Quickshell.execDetached(["kitty", "--title", "TuxOS gaming set", "sh", "-c", "pkexec tuxos-gaming; read -p 'Enter closes' x"]) } }
    }
}
