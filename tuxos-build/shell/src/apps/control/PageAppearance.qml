import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Appearance (mockup apps/01-settings): wallpaper, accent colour, glass,
// bar, corners, animations, smart symbols, text size, light mode.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Appearance"); description: Tr.t("Wallpaper, colours and how the shell looks and moves.") }

    // wallpapers: TuxOS' own, ~/Pictures/Wallpapers, live ones (shaders,
    // videos in ~/Videos/Wallpapers); for all desktops, this desktop or
    // this monitor (the shell draws them: services/Wallpapers.qml)
    property var walls: []
    property var videos: []
    Cmd {
        id: wl
        command: ["sh", "-c", "ls -1 /usr/share/tuxos/wallpapers/*.jpg /usr/share/tuxos/wallpapers/*.png \"$HOME\"/Pictures/Wallpapers/*.jpg \"$HOME\"/Pictures/Wallpapers/*.png 2>/dev/null; echo ---; ls -1 \"$HOME\"/Videos/Wallpapers/*.mp4 \"$HOME\"/Videos/Wallpapers/*.webm \"$HOME\"/Videos/Wallpapers/*.mkv 2>/dev/null"]
        Component.onCompleted: run()
        onDone: out => { const [a, b] = out.split("---\n"); page.walls = (a || "").split("\n").filter(l => l); page.videos = (b || "").split("\n").filter(l => l); }
    }
    readonly property string home: Quickshell.env("HOME")
    readonly property string defaultFile: home + "/.local/share/tuxos/wallpaper.png"
    property int scopeIndex: 0                       // all desktops / this desktop / this monitor
    readonly property int wsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property string monName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property string scope: scopeIndex === 1 ? "ws:" + wsId : scopeIndex === 2 ? "mon:" + monName : "default"
    readonly property var rules: Prefs.wallpapers || ({})
    // what the chosen scope shows now ("" = the default picture file)
    readonly property string currentPath: scope === "default" ? (rules["default"] || "") : (rules[scope] || "")
    property int stamp: 0
    Timer { id: stampLater; interval: 500; onTriggered: page.stamp++ }
    function setWallpaper(f) {
        Quickshell.execDetached(["qs", "-c", "tuxos", "ipc", "call", "wallpaper", "set", f, page.scope]);
        if (page.scope === "default" && !f.startsWith("shader:") && !/\.(mp4|webm|mkv|mov)$/i.test(f)) page.pickedFile = f;
        stampLater.restart();
    }
    property string pickedFile: ""
    function isCurrent(f) {
        if (f.startsWith("shader:") || /\.(mp4|webm|mkv|mov)$/i.test(f)) return page.currentPath === f;
        return page.currentPath === f || (page.scope === "default" && page.currentPath === "" && page.pickedFile === f);
    }

    Text { text: Tr.t("WALLPAPER"); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
    Row {
        spacing: 12
        Segmented { width: 420; options: [Tr.t("All desktops"), Tr.f("Desktop {n}", { n: page.wsId }), page.monName || Tr.t("This monitor")]; current: page.scopeIndex; onPicked: i => page.scopeIndex = i }
        Btn { visible: page.scope !== "default" && page.currentPath !== ""; text: "Use the default"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.setWallpaper("") }
    }
    Flow {
        width: parent.width
        spacing: 12
        Repeater {
            model: page.walls
            delegate: Rectangle {
                required property string modelData
                readonly property bool cur: page.isCurrent(modelData)
                width: 208; height: 116; radius: 14
                color: "transparent"
                border.width: cur ? 2 : 1
                border.color: cur ? Theme.accent : Theme.glassLine
                clip: true
                Image {
                    anchors { fill: parent; margins: 4 }
                    source: "file://" + modelData
                    sourceSize: Qt.size(416, 232)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.setWallpaper(modelData) }
            }
        }
        // live: TuxOS' shaders (a moving preview) and your videos
        Repeater {
            model: Wallpapers.shaders
            delegate: Rectangle {
                required property var modelData
                readonly property bool cur: page.isCurrent(modelData[0])
                width: 208; height: 116; radius: 14
                color: "black"
                border.width: cur ? 2 : 1
                border.color: cur ? Theme.accent : Theme.glassLine
                clip: true
                ShaderEffect {
                    anchors { fill: parent; margins: 4 }
                    property real time: 0
                    property vector2d resolution: Qt.vector2d(width, height)
                    property color accent: Theme.accent
                    fragmentShader: Qt.resolvedUrl("../../assets/shaders/" + modelData[0].slice(7) + ".frag.qsb")
                    NumberAnimation on time { from: 0; to: 600; duration: 600000; loops: Animation.Infinite; paused: Theme.reduceMotion }
                }
                Rectangle { anchors { left: parent.left; bottom: parent.bottom; margins: 8 } width: liveLbl.implicitWidth + 16; height: 24; radius: 8; color: Qt.rgba(0, 0, 0, 0.55)
                    Text { id: liveLbl; anchors.centerIn: parent; text: Tr.t(modelData[1]) + " · " + Tr.t("live"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: "white" } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.setWallpaper(modelData[0]) }
            }
        }
        Repeater {
            model: page.videos
            delegate: Rectangle {
                required property string modelData
                readonly property bool cur: page.isCurrent(modelData)
                width: 208; height: 116; radius: 14
                color: Theme.fill
                border.width: cur ? 2 : 1
                border.color: cur ? Theme.accent : Theme.glassLine
                Column { anchors.centerIn: parent; spacing: 4
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xf022b); font.family: Theme.symbols; font.pixelSize: Theme.px(28); color: Theme.text }
                    Text { width: 180; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle; text: modelData.substring(modelData.lastIndexOf("/") + 1); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.setWallpaper(modelData) }
            }
        }
    }
    Text {
        width: parent.width; wrapMode: Text.Wrap
        text: Tr.t("Your pictures: ~/Pictures/Wallpapers · videos: ~/Videos/Wallpapers. Live wallpapers pause in games, in full screen, on battery and while locked.")
        font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted
    }

    Text { text: Tr.t("ACCENT COLOUR"); topPadding: 8; font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
    Row {
        spacing: 12
        Repeater {
            model: ["#8fb8ff", "#8fe3c0", "#b9a8ff", "#ffa8c0", "#ffd08f", "#e8edf5"]
            delegate: Rectangle {
                required property string modelData
                width: 40; height: 40; radius: 20
                color: modelData
                border.width: Prefs.accent === modelData ? 3 : 0
                border.color: Theme.ink(0.9)
                Rectangle { anchors.centerIn: parent; visible: Prefs.accent === modelData; width: 46; height: 46; radius: 23; color: "transparent"; border.width: 2; border.color: modelData }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Prefs.accent = modelData }
            }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; leftPadding: 8; text: Tr.t("Blue is the TuxOS default"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
    }

    SettingCard {
        header: Tr.t("Shell")
        SettingRow {
            title: Tr.t("Glass"); description: Tr.t("How strongly panels tint what is behind them")
            Slider { width: 260; value: (Prefs.glass - 0.4) / 0.45; onMoved: v => Prefs.glass = Math.round((0.4 + v * 0.45) * 100) / 100 }
        }
        SettingRow {
            title: Tr.t("Bar"); description: Tr.t("Floating or attached to the screen edge")
            Segmented { width: 220; options: ["Floating", "Attached"]; current: Prefs.barStyle === "attached" ? 1 : 0; onPicked: i => Prefs.barStyle = i === 1 ? "attached" : "floating" }
        }
        SettingRow {
            title: Tr.t("Corner roundness")
            Segmented { width: 300; options: ["Small", "Medium", "Large"]; current: ["small", "medium", "large"].indexOf(Prefs.roundness); onPicked: i => Prefs.roundness = ["small", "medium", "large"][i] }
        }
        SettingRow {
            title: Tr.t("Animations"); description: Tr.t("Droplets, window motion, unlock")
            Toggle { checked: Prefs.animations; onToggled: v => Prefs.animations = v }
        }
        SettingRow {
            title: Tr.t("Lite mode"); description: Tr.t("Solid glass, no blur or shadows, shorter animations, AI hidden. Auto turns it on for 4 GB of RAM or less and for PCs without GPU acceleration") + (Theme.autoLite ? " (this PC: on)" : "")
            Segmented { width: 300; options: ["Auto", "On", "Off"]; current: ["auto", "on", "off"].indexOf(Prefs.lite); onPicked: i => Prefs.lite = ["auto", "on", "off"][i] }
        }
        SettingRow {
            title: Tr.t("Smart app symbols"); description: Tr.t("One-colour symbols chosen from what each app is")
            Toggle { checked: Prefs.smartSymbols; onToggled: v => Prefs.smartSymbols = v }
        }
        SettingRow {
            title: Tr.t("Text size"); last: true
            Segmented { width: 360; options: ["Small", "Default", "Large", "Larger"]; current: [0.9, 1.0, 1.15, 1.3].indexOf(Prefs.textScale); onPicked: i => Prefs.textScale = [0.9, 1.0, 1.15, 1.3][i] }
        }
    }
    // ---- an app's own symbol (SPEC: "the user can override any app's
    // symbol"): find the app, pick one of TuxOS' symbols; saved as
    // Prefs.symbolOverrides (app id -> symbol), used everywhere apps show
    property string symFor: ""          // the app id whose symbol is being picked
    readonly property string symQuery: symFind.text.trim().toLowerCase()
    readonly property var symApps: symQuery.length < 2 ? [] : DesktopEntries.applications.values
        .filter(e => !e.noDisplay && (e.name.toLowerCase().indexOf(symQuery) !== -1 || e.id.toLowerCase().indexOf(symQuery) !== -1)).slice(0, 6)
    readonly property var symChoices: {
        const a = AppSymbols, seen = {}, out = [];
        for (const c of [a.globe, a.terminal, a.folder, a.gamepad, a.chat, a.music, a.play, a.pencil, a.code, a.cog, a.image, a.document,
                         a.calculator, a.mail, a.robot].concat(Object.values(a.known)))
            if (c !== undefined && !seen[c]) { seen[c] = true; out.push(c); }
        return out;
    }
    function setSymbol(id, code) {
        const o = Object.assign({}, Prefs.symbolOverrides || {});
        if (code === undefined) delete o[AppSymbols.norm(id)]; else o[AppSymbols.norm(id)] = code;
        Prefs.symbolOverrides = o;
    }
    SettingCard {
        header: Tr.t("App symbols")
        SettingRow {
            title: Tr.t("An app's own symbol"); description: Tr.t("Shown in the dock, the launcher, the switcher and notifications")
            last: page.symApps.length === 0
            Field { id: symFind; width: 260; placeholder: Tr.t("Find an app") }
        }
        Repeater {
            model: page.symApps
            delegate: Column {
                id: symRow
                required property var modelData
                required property int index
                readonly property string key: AppSymbols.norm(modelData.id)
                readonly property bool own: (Prefs.symbolOverrides || {})[key] !== undefined
                width: parent ? parent.width : 600
                SettingRow {
                    title: symRow.modelData.name
                    description: symRow.own ? Tr.t("Your symbol") : Tr.t("Chosen by TuxOS")
                    last: symRow.index === page.symApps.length - 1 && page.symFor !== symRow.modelData.id
                    Row {
                        spacing: 10
                        AppTile { size: 34; entry: symRow.modelData; appId: symRow.modelData.id; anchors.verticalCenter: parent.verticalCenter }
                        Btn { text: page.symFor === symRow.modelData.id ? Tr.t("Done") : Tr.t("Change"); anchors.verticalCenter: parent.verticalCenter
                              onClicked: page.symFor = page.symFor === symRow.modelData.id ? "" : symRow.modelData.id }
                        Btn { visible: symRow.own; text: Tr.t("Default"); anchors.verticalCenter: parent.verticalCenter; onClicked: page.setSymbol(symRow.modelData.id, undefined) }
                    }
                }
                // the symbols to choose from
                Flow {
                    visible: page.symFor === symRow.modelData.id
                    x: 24; width: parent.width - 48
                    spacing: 6; bottomPadding: 14
                    Repeater {
                        model: page.symFor === symRow.modelData.id ? page.symChoices : []
                        delegate: Rectangle {
                            required property int modelData
                            readonly property bool chosen: (Prefs.symbolOverrides || {})[symRow.key] === modelData
                            width: 40; height: 40; radius: 12
                            color: chosen ? Theme.accentFill : (symHover.hovered ? Theme.fillHover : Theme.fill)
                            border.width: 1; border.color: chosen ? Theme.accentLine : Theme.glassLine
                            Accessible.role: Accessible.Button
                            Accessible.name: Tr.t("Symbol")
                            Sym { anchors.centerIn: parent; code: parent.modelData; font.pixelSize: Theme.px(19); color: Theme.text }
                            HoverHandler { id: symHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.setSymbol(symRow.modelData.id, parent.modelData) }
                        }
                    }
                }
            }
        }
    }
    SettingCard {
        header: Tr.t("Colours from")
        SettingRow { title: Tr.t("Accent from the wallpaper"); description: Tr.t("Picks a readable accent from the picture; grey pictures keep yours"); Toggle { checked: Prefs.accentFromWallpaper; onToggled: v => Prefs.accentFromWallpaper = v } }
        SettingRow { title: Tr.t("RGB lighting follows the accent"); description: Tr.t("Keyboard, mouse, headset and case lights (OpenRGB); dark while locked")
                     Row { spacing: 8
                         Btn { visible: !page.hasOpenRgb; text: Tr.t("Install"); onClicked: Quickshell.execDetached(["sh", "-c", "pkexec tuxos-pkg install openrgb && notify-send 'OpenRGB is installed' 'RGB lighting can follow the accent now'"]) }
                         Toggle { visible: page.hasOpenRgb; checked: Prefs.rgbAccent; onToggled: v => Prefs.rgbAccent = v } } }
        SettingRow { title: Tr.t("Accent from album art"); description: Tr.t("While music plays the shell takes a colour from the cover, then goes back"); last: true; Toggle { checked: Prefs.accentFromAlbum; onToggled: v => Prefs.accentFromAlbum = v } }
    }
    property bool hasOpenRgb: false
    Cmd { command: ["sh", "-c", "command -v openrgb >/dev/null && echo yes"]; Component.onCompleted: run(); onDone: out => page.hasOpenRgb = out.trim() === "yes" }
    SettingCard {
        header: Tr.t("Lock and login screen")
        SettingRow {
            title: Tr.t("Depth effect")
            description: !Prefs.depthEffect ? Tr.t("The clock sits behind the wallpaper's subject (mountains, skylines, people)")
                       : Wallpapers.depthMask ? Tr.t("The clock sits behind the wallpaper's subject")
                       : Wallpapers.depthNone ? Tr.t("This wallpaper has no clear subject: the usual layout with a note is used")
                       : Tr.t("Finding the subject...")
            Toggle { checked: Prefs.depthEffect; onToggled: v => Prefs.depthEffect = v }
        }
        SettingRow {
            visible: Prefs.depthEffect && (Wallpapers.depthMask !== "" || Wallpapers.depthNone)
            title: Tr.t("Subject"); last: true
            description: Wallpapers.depthMask ? Tr.t("Found by itself for this wallpaper; touch it up by hand") : Tr.t("None found; paint it by hand if the picture has one")
            Btn { text: Wallpapers.depthMask ? "Touch up..." : "Paint it..."; onClicked: depthEd.active = true }
        }
    }
    Loader {
        id: depthEd
        active: false
        parent: page.parent
        anchors.fill: parent
        z: 50
        sourceComponent: DepthEditor { maskFile: Wallpapers.depthMask || (Wallpapers.depthDir + "/" + Wallpapers.depthKey + ".png"); onDone: depthEd.active = false }
    }
    SettingCard {
        header: Tr.t("Light and dark")
        SettingRow {
            title: Tr.t("Style"); description: Tr.t("Light mode turns the glass white; apps that follow TuxOS' theme follow it too")
            Segmented { width: 300; options: ["Dark", "Light", "Auto"]; current: ["dark", "light", "auto"].indexOf(Prefs.lightMode); onPicked: i => Prefs.lightMode = ["dark", "light", "auto"][i] }
        }
        SettingRow {
            title: Tr.t("Night light"); description: Tr.t("Warmer colours in the evening; fades in over 30 minutes at sunset"); last: true
            Segmented { width: 300; options: ["Off", "At sunset", "On"]; current: ["off", "sunset", "on"].indexOf(Prefs.nightLight); onPicked: i => Prefs.nightLight = ["off", "sunset", "on"][i] }
        }
    }
    // ---- Share your setup (SPEC round 5 #20): .tuxtheme export / import with a preview
    property var shared: null                // the setup being previewed
    property string sharedDir: ""
    property string shareNote: ""
    Process {
        id: exportProc
        stdout: StdioCollector { onStreamFinished: { const f = text.trim().split("\n").pop(); page.shareNote = f ? Tr.f("Saved as {n}", { n: f.split("/").pop() }) : ""; } }
    }
    Process {
        id: importProc
        command: ["sh", "-c", "f=$(tuxos-pick open 'Open a TuxOS setup' | head -1); [ -n \"$f\" ] || exit 0; d=$(tuxos-tuxtheme open \"$f\") || { echo BAD; exit 0; }; echo \"$d\"; cat \"$d/setup.json\"; echo; ls \"$d\" | grep '^wallpaper' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t) return;
                if (t === "BAD") { page.shareNote = Tr.t("That file is not a TuxOS setup"); return; }
                const lines = t.split("\n");
                const dir = lines.shift(), wall = lines[lines.length - 1].startsWith("wallpaper") ? lines.pop() : "";
                try { page.shared = Object.assign(JSON.parse(lines.join("\n")), { image: wall ? dir + "/" + wall : "" }); page.sharedDir = dir; page.shareNote = ""; }
                catch (e) { page.shareNote = Tr.t("That file is not a TuxOS setup"); }
            }
        }
    }
    readonly property var shareKeys: ["accent", "lightMode", "highContrast", "glass", "roundness", "animations", "barStyle", "barAutoHide", "dockAutoHide", "pins", "desktopNames", "screenCorners", "smartSymbols", "symbolOverrides", "seasonalTux", "accentFromWallpaper", "depthEffect"]
    function applyShared() {
        const s = shared;
        if (!s) return;
        for (const k of shareKeys) if (s[k] !== undefined && Prefs[k] !== undefined) Prefs[k] = s[k];
        if (s.wallpaper && String(s.wallpaper).startsWith("shader:")) Wallpapers.set(s.wallpaper, "default");
        else if (s.image) {
            // kept with the user's pictures, then used
            const dest = Quickshell.env("HOME") + "/Pictures/Wallpapers/" + (s.name || "Shared setup").replace(/[\/]/g, "-") + s.image.slice(s.image.lastIndexOf("."));
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && cp -f \"$1\" \"$2\"", "sh", s.image, dest]);
            Qt.callLater(() => Wallpapers.set(dest, "default"));
        }
        shareNote = Tr.f("{n} applied", { n: s.name || Tr.t("The setup") });
        shared = null;
    }
    SettingCard {
        header: Tr.t("Share your setup")
        SettingRow {
            title: Tr.t("Export"); description: Tr.t("Accent, light / dark, glass, bar and dock, desktop names and the wallpaper as one .tuxtheme file")
            Btn {
                text: Tr.t("Export...")
                onClicked: {
                    exportProc.command = ["sh", "-c", "f=$(tuxos-pick save 'Save your setup' 'My TuxOS setup.tuxtheme' | head -1); [ -n \"$f\" ] && tuxos-tuxtheme export \"$f\" \"$(basename \"$f\" .tuxtheme)\""];
                    exportProc.running = true;
                }
            }
        }
        SettingRow {
            title: Tr.t("Import"); description: page.shareNote || Tr.t("Someone else's .tuxtheme: you see it before anything changes"); last: page.shared === null
            Btn { text: Tr.t("Import..."); onClicked: if (!importProc.running) importProc.running = true }
        }
        Item {
            visible: page.shared !== null
            width: parent.width; height: Theme.px(190)
            Rectangle {
                id: prev
                x: 16; y: 12; width: Theme.px(256); height: Theme.px(144); radius: 12; clip: true
                color: page.shared && page.shared.lightMode === "light" ? "#e9edf3" : "#0c0e13"
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 512
                        source: page.shared && page.shared.image ? "file://" + page.shared.image : "" }
                // a little bar and dock in the setup's colours
                Rectangle { x: 8; y: 6; width: parent.width - 16; height: 12; radius: 6; color: page.shared && page.shared.lightMode === "light" ? "#ccf6f8fc" : "#cc0a0c10"
                    Rectangle { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 6; radius: 3; color: page.shared ? (page.shared.accent || "#8fb8ff") : "transparent" } }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; width: 90; height: 16; radius: 8
                            color: page.shared && page.shared.lightMode === "light" ? "#ccf6f8fc" : "#cc0a0c10" }
            }
            Column {
                anchors { left: prev.right; leftMargin: 18; right: parent.right; rightMargin: 16; top: prev.top }
                spacing: 6
                Text { text: page.shared ? (page.shared.name || Tr.t("Shared setup")) : ""; font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text; width: parent.width; elide: Text.ElideRight }
                Row {
                    spacing: 8
                    Rectangle { width: 16; height: 16; radius: 8; color: page.shared ? (page.shared.accent || "#8fb8ff") : "transparent"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: page.shared ? ((page.shared.accent || "#8fb8ff") + " · " + ({ dark: Tr.t("Dark"), light: Tr.t("Light"), auto: Tr.t("Auto") })[page.shared.lightMode || "dark"]) : ""; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                }
                Text { text: page.shared ? Tr.t("Bar: ") + (page.shared.barStyle === "attached" ? Tr.t("attached") : Tr.t("floating")) + (page.shared.desktopNames && Object.keys(page.shared.desktopNames).length ? " · " + Tr.t("Desktops: ") + Object.values(page.shared.desktopNames).join(", ") : "") : ""
                       font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted; width: parent.width; wrapMode: Text.Wrap }
                Row {
                    spacing: 10; topPadding: 8
                    Btn { text: Tr.t("Apply"); primary: true; onClicked: page.applyShared() }
                    Btn { text: Tr.t("Cancel"); onClicked: page.shared = null }
                }
            }
        }
    }
}
