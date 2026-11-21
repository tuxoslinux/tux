pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The shell's own settings (~/.config/tuxos/shell.json). TuxOS Control
// writes the same file; the shell picks changes up live.
Singleton {
    id: prefs

    property alias terminal: data.terminal
    property alias browser: data.browser
    property alias music: data.music
    property alias messaging: data.messaging
    property alias files: data.files
    property alias settingsApp: data.settingsApp
    property alias monitorApp: data.monitorApp
    property alias dndHours: data.dndHours
    property alias lockMinutes: data.lockMinutes
    property alias pins: data.pins
    property alias reduceMotion: data.reduceMotion
    property alias lite: data.lite
    property alias symbolOverrides: data.symbolOverrides
    property alias userName: data.userName
    property alias notes: data.notes
    property alias worldClocks: data.worldClocks
    property alias bootCard: data.bootCard
    property alias seasonalTux: data.seasonalTux
    property alias screenCorners: data.screenCorners
    property alias desktopNames: data.desktopNames
    property alias weatherCity: data.weatherCity
    property alias accent: data.accent
    property alias animations: data.animations
    property alias textScale: data.textScale
    property alias glass: data.glass
    property alias barStyle: data.barStyle
    property alias roundness: data.roundness
    property alias smartSymbols: data.smartSymbols
    property alias dockAutoHide: data.dockAutoHide
    property alias barAutoHide: data.barAutoHide
    property alias use24h: data.use24h
    property alias lightMode: data.lightMode
    property alias nightLight: data.nightLight
    property alias uiSounds: data.uiSounds
    property alias highContrast: data.highContrast
    property alias gameSilence: data.gameSilence
    property alias superInFullscreen: data.superInFullscreen
    property alias fpsLimit: data.fpsLimit
    property alias allowTearing: data.allowTearing
    property alias screenTime: data.screenTime
    property alias clipboardHistory: data.clipboardHistory
    property alias language: data.language
    property alias aiEnabled: data.aiEnabled
    property alias weatherUnits: data.weatherUnits
    property alias location: data.location
    property alias restoreApps: data.restoreApps
    property alias smartPower: data.smartPower
    property alias wallpapers: data.wallpapers
    property alias accentFromWallpaper: data.accentFromWallpaper
    property alias accentFromAlbum: data.accentFromAlbum
    property alias depthEffect: data.depthEffect
    property alias acProfile: data.acProfile
    property alias battery60: data.battery60
    property alias titleBars: data.titleBars
    property alias fileIndex: data.fileIndex
    property alias tidyDownloads: data.tidyDownloads
    property alias tidyDays: data.tidyDays
    property alias tidyLast: data.tidyLast
    property alias mutedApps: data.mutedApps
    property alias updateFailSeen: data.updateFailSeen
    property alias achievementToasts: data.achievementToasts
    property alias saveBackups: data.saveBackups
    property alias gpuPreset: data.gpuPreset
    property alias rgbAccent: data.rgbAccent
    property alias driversSeen: data.driversSeen
    property alias screenOffMinutes: data.screenOffMinutes
    property alias sleepBattery: data.sleepBattery
    property alias sleepAc: data.sleepAc
    property alias playReminder: data.playReminder
    property alias driveAdvisor: data.driveAdvisor
    property alias drivesAdvised: data.drivesAdvised
    property alias replayMode: data.replayMode
    property alias replaySeconds: data.replaySeconds

    // ---- settings from an older TuxOS: brought up to date once, in order
    // (new settings simply take their defaults; this is for changed meanings)
    readonly property int currentVersion: 1
    function migrate() {
        const v = data.settingsVersion;
        if (v >= currentVersion) return;
        // 1 (build11): the lock and login screens' depth clock is the default design
        if (v < 1) data.depthEffect = true;
        data.settingsVersion = currentVersion;
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/tuxos/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: prefs.migrate()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) { data.settingsVersion = prefs.currentVersion; writeAdapter(); } }

        JsonAdapter {
            id: data
            // default apps (SPEC shortcuts: all choosable in Settings)
            property string terminal: "kitty"
            property string browser: "helium"
            property string music: "spotify"
            property string messaging: "discord"
            property string files: "tuxos-files"
            property string settingsApp: "tuxos-control"
            property string monitorApp: "tuxos-monitor"
            property real dndHours: 3                 // Super + D
            property int lockMinutes: 5               // lock after 5 min without input
            property var pins: ["tuxos-files", "helium", "kitty", "steam", "spotify", "tuxos-editor"]
            property bool reduceMotion: false
            property string lite: "auto"              // auto / on / off
            property var symbolOverrides: ({})
            property string userName: ""
            property string notes: ""
            property var worldClocks: ["Europe/London", "America/New_York", "Asia/Tokyo"]
            property bool bootCard: true
            property bool seasonalTux: true
            property bool screenCorners: false
            property var desktopNames: ({})           // "3": "Gaming"
            property string weatherCity: ""           // empty: the time zone's city
            property string accent: "#8fb8ff" // accent colour (Appearance)
            property bool animations: true    // droplets, window motion, unlock
            property real textScale: 1.0      // Small 0.9 / Default 1 / Large 1.15 / Larger 1.3
            property real glass: 0.62         // glass tint strength
            property string barStyle: "floating" // floating / attached
            property string roundness: "large" // small / medium / large
            property bool smartSymbols: true  // one-colour symbols chosen from what each app is
            property bool dockAutoHide: true  // dock slides away under windows
            property bool barAutoHide: false  // bar hides until the top edge / Super
            property bool use24h: true        // 24-hour clock
            property string lightMode: "dark" // dark / light / auto (sunset)
            property string nightLight: "off" // off / sunset / on
            property bool uiSounds: false     // unlock, notification, screenshot sounds
            property bool highContrast: false // accessibility
            property bool gameSilence: true   // do not disturb while a game runs
            property bool superInFullscreen: false // Super alone opens the launcher over full-screen apps
            property int fpsLimit: 0          // 0 = off (frame limiter default)
            property bool allowTearing: false // tear-free by default
            property bool screenTime: true    // local screen time
            property bool clipboardHistory: true // Super + C history
            property string language: "en"    // en / bg
            property bool aiEnabled: false    // local AI (Ollama)
            property string weatherUnits: "c" // c / f
            property var wallpapers: ({})        // per desktop / monitor / live (services/Wallpapers.qml)
            property bool accentFromWallpaper: false
            property bool accentFromAlbum: false
            property int settingsVersion: 0      // see migrate()
            property bool depthEffect: true      // lock + login screen: clock behind the wallpaper's subject (when it has one)
            property bool smartPower: true       // profiles follow battery / AC (Settings > Power)
            property string acProfile: "performance" // on AC and on desktops: performance / balanced
            property bool battery60: true        // 60 Hz on battery
            property bool titleBars: true        // TuxOS title bar for apps that draw none
            property bool fileIndex: true        // search inside files (local index, built when idle)
            property bool tidyDownloads: false   // old files in Downloads go to the Trash (once a day)
            property int tidyDays: 30
            property string tidyLast: ""        // the day it last ran
            property var mutedApps: []           // apps whose notifications never pop up
            property double updateFailSeen: 0    // the failed update already warned about
            property bool achievementToasts: true // Steam achievements as TuxOS toasts
            property bool saveBackups: true      // Ludusavi game save backups (when installed)
            property string gpuPreset: "stock"   // LACT: quiet / stock / performance
            property bool rgbAccent: false       // OpenRGB lighting follows the accent
            property var driversSeen: []         // "mesa 1:26.2.6-1": driver news already shown
            property int screenOffMinutes: 10    // 0 = never
            property int sleepBattery: 20        // minutes without input on battery; 0 = never
            property int sleepAc: 0              // plugged in (desktops): never by default
            property int playReminder: 0         // minutes; 0 = off (play-time reminders)
            property bool driveAdvisor: true     // card when a game sits on a slow drive
            property var drivesAdvised: []       // game ids already advised (once each)
            property string replayMode: "games"  // instant replay: games / always / off
            property int replaySeconds: 60       // 30 / 45 / 60
            property string restoreApps: "ask"   // ask / always / never (open apps again at login)
            property var location: ({})       // { lat, lon } of the weather place (sunrise / sunset)
        }
    }

    // first name for greetings ("Good day, Alex"): the name set in Settings,
    // else the account's full name (as the login screen greets), else the login
    property string accountName: ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$(id -un)\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: prefs.accountName = text.trim() }
    }
    readonly property string firstName: {
        const n = userName || accountName || Quickshell.env("USER") || "";
        const f = n.split(/\s+/)[0];
        return f.charAt(0).toUpperCase() + f.slice(1);
    }
}
