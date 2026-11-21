import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar
import qs.popups
import qs.dock
import qs.launcher
import qs.notifications
import qs.overlays
import qs.shortcuts
import qs.services
import qs.lock
import qs.theme

// The TuxOS desktop shell: one bar, droplet layer and dock per monitor
// (SPEC: multiple monitors); overlays open on the focused monitor.
Scope {
    Keys {}
    // drives, boot time, refresh rate, low memory / disk / heat warnings
    Component.onCompleted: { Watch.start(); NightLight.start(); SmartPower.refreshRates(); void Idle.sleepMinutes; void GamePad.wanted; void DriverNews.objectName; void Streaming.on; void Gpu.available; void Rgb.on; void Saves.on; void Indexer.on; void Snippets.list; void ScreenTime.on; void Energy.on; void Tidy.on; void GameSessions.last; sessionLater.start(); }
    // after the session has settled: offer the apps of the last session
    Timer { id: sessionLater; interval: 3000; onTriggered: if (!Shell.live) { Session.start(); welcomeCheck.running = true; } }
    // the first login after the install: Welcome (once)
    Process {
        id: welcomeCheck
        command: ["sh", "-c", "[ -e \"$HOME/.local/state/tuxos/welcome-done\" ] || exec tuxos-app welcome"]
    }

    // the theme reaches Hyprland and the apps too: accent on the window
    // border, blur (off in lite mode, brighter in light mode), window
    // animations (off with Reduce motion); saved for the next login in
    // ~/.config/hypr/theme.lua, which hyprland.lua loads. Apps: GTK, Qt
    // (qt6ct) and kitty through tuxos-theme.
    function syncTheme() {
        const c = Theme.baseAccent.toString().replace("#", "");
        const lua = `hl.config({ general = { col = { active_border = "rgba(${c}cc)" } }, decoration = { blur = { enabled = ${!Theme.lite}, brightness = ${Theme.light ? 1.0 : 0.5} }, shadow = { enabled = ${!Theme.lite} } }, animations = { enabled = ${!Theme.reduceMotion} }, group = { groupbar = { col = { active = "rgba(${c}ee)", inactive = "${Theme.light ? 'rgba(e9edf3dd)' : 'rgba(1a1e27dd)'}" }, text_color_inactive = "${Theme.light ? 'rgba(10141cff)' : 'rgba(e8eefaff)'}" } } })`;
        Quickshell.execDetached(["tuxos-theme", Theme.baseAccent.toString(), Theme.light ? "light" : "dark"]);
        // written to theme.lua, then Hyprland reloads its config (a live
        // hl.config does not repaint the tab strips)
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config/hypr\"; f=\"$HOME/.config/hypr/theme.lua\"; n=$(printf '%s\\n' \"-- written by the TuxOS shell (theme)\" \"$1\"); [ \"$(cat \"$f\" 2>/dev/null)\" = \"$n\" ] && exit 0; printf '%s\\n' \"$n\" > \"$f\" && hyprctl reload >/dev/null", "sh", lua]);
    }
    Timer { id: syncLater; interval: 300; onTriggered: syncTheme() }
    // the wallpaper of every screen (replaces swaybg)
    Variants {
        model: Quickshell.screens
        delegate: Component { Background {} }
    }
    // the album-art accent: Hyprland's border follows, live (no reload)
    Timer {
        id: borderLater
        interval: 700
        onTriggered: { const c = Theme.accent.toString().replace("#", ""); Shell.dispatch(`(function() hl.config({ general = { col = { active_border = "rgba(${c}cc)" } } }); return hl.dsp.no_op() end)()`, ""); }
    }
    Connections { target: Theme; function onAccentOverrideChanged() { borderLater.restart(); } }
    Connections {
        target: Theme
        function onBaseAccentChanged() { syncLater.restart(); }
        function onLightChanged() { syncLater.restart(); }
        function onLiteChanged() { syncLater.restart(); }
        function onReduceMotionChanged() { syncLater.restart(); }
    }
    // at login: bring Hyprland and the apps in line with the saved theme
    Timer { interval: 1500; running: true; onTriggered: syncTheme() }
    Lock {}

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar {
                required property var modelData
                screen: modelData
            }
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Popups {
                required property var modelData
                screen: modelData
                screenName: modelData.name
            }
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Dock {
                required property var modelData
                screen: modelData
                screenName: modelData.name
            }
        }
    }

    // overlays: loaded the first time they are opened, then kept
    component OnDemand: LazyLoader {
        id: od
        property string name
        property bool used: false
        active: used || Shell.overlay === name
        Connections { target: Shell; function onOverlayChanged() { if (Shell.overlay === od.name) od.used = true; } }
    }
    OnDemand { name: "power"; PowerMenu {} }
    OnDemand { name: "restart"; RestartCountdown {} }
    OnDemand { name: "shutdown"; ShutdownScreen {} }
    OnDemand { name: "clipboard"; Clipboard {} }
    OnDemand { name: "emoji"; EmojiPicker {} }
    OnDemand { name: "sheet"; ShortcutSheet {} }
    OnDemand { name: "notes"; QuickNotes {} }
    OnDemand { name: "mission"; MissionControl {} }
    OnDemand { name: "wifiqr"; WifiQr {} }
    OnDemand { name: "switcher"; Switcher {} }
    OnDemand { name: "centre"; Centre {} }
    OnDemand { name: "snap"; SnapLayouts {} }
    PolkitPrompt {}

    OnDemand { name: "launcher"; Launcher {} }
    NotifPopups {}
    LazyLoader { active: Media.pipPlayer !== null; PipControls {} }
    ScreenCorners {}
    Minimizer {}
    LazyLoader { active: Prefs.titleBars; TitleBars {} }
    // the game launch card: loaded while a game starts (and a moment after, to fade)
    property bool launchCard: Games.starting !== null
    onLaunchCardChanged: if (launchCard) cardKeep.stop(); else cardKeep.restart()
    Timer { id: cardKeep; interval: 800 }
    LazyLoader { active: launchCard || cardKeep.running; LaunchCard {} }
    LazyLoader { active: Games.controlsShown; GameControls {} }

    OnDemand {
        name: "screenshot"
        Scope {
            Variants {
                model: Quickshell.screens
                delegate: Component { ScreenshotPicker {} }
            }
        }
    }
}
