import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// TuxOS Control (Settings; Super + S; mockups apps/01-02-settings): every
// setting of TuxOS in one place. Sidebar grouped System / Personal / TuxOS,
// "Search all settings" across every page. `tuxos-control --page <id>` opens
// a page directly (the launcher and the shell use it).
AppWindow {
    id: app
    appName: "Settings"
    appIcon: 0xf0493
    searchable: true

    property string page: Quickshell.env("TUXOS_PAGE") || "appearance"
    IpcHandler {
        target: "control"
        function page(id: string): void { app.page = id; }
    }

    readonly property var pages: [
        ["System", "network", "Wi-Fi & network", 0xf05a9, "wifi internet ethernet vpn dns proxy hotspot qr"],
        ["System", "bluetooth", "Bluetooth", 0xf00af, "devices headphones controller pair"],
        ["System", "displays", "Displays", 0xf0379, "monitor screen resolution refresh rate hz scale hdr vrr mirror"],
        ["System", "sound", "Sound", 0xf057e, "audio volume speaker headset microphone noise output input"],
        ["System", "power", "Power & battery", 0xf0079, "battery sleep lid charge limit profile lock"],
        ["System", "storage", "Storage & cleanup", 0xf02ca, "disk space clean trash cache downloads"],
        ["Personal", "appearance", "Appearance", 0xf00e3, "theme wallpaper accent colour color glass blur bar corner animation text size light dark"],
        ["Personal", "desktop", "Desktop & dock", 0xf056e, "dock bar auto hide desktops names corners seasonal"],
        ["Personal", "windows", "Window rules", 0xf05b2, "window rules per app desktop monitor floating maximized full screen on top opacity"],
        ["Personal", "notifications", "Notifications", 0xf009a, "do not disturb dnd focus modes sounds"],
        ["Personal", "keyboard", "Keyboard & shortcuts", 0xf030c, "keys layout bulgarian shortcuts snippets"],
        ["Personal", "mouse", "Mouse & touchpad", 0xf037d, "pointer speed natural scroll touchpad gestures cursor shake hide typing"],
        ["Personal", "apps", "Default apps", 0xf003b, "browser terminal music messaging files"],
        ["Personal", "datetime", "Date & time", 0xf0150, "clock timezone 24h world clocks weather"],
        ["Personal", "region", "Language & region", 0xf05ca, "language bulgarian english formats"],
        ["Personal", "accessibility", "Accessibility", 0xf02e6, "reduce motion contrast zoom larger text"],
        ["TuxOS", "gaming", "Gaming", 0xf0297, "steam fps hud vrr tearing frame limit game mode proton mangohud scheduler"],
        ["TuxOS", "performance", "Performance", 0xf04c5, "cpu scheduler zram tuning bore"],
        ["TuxOS", "updates", "Updates & drivers", 0xf01da, "update upgrade driver nvidia kernel"],
        ["TuxOS", "privacy", "Privacy & security", 0xf099d, "camera microphone lock clipboard search index screen time"],
        ["TuxOS", "users", "Users", 0xf000e, "account password avatar"],
        ["TuxOS", "winapps", "Apps for Windows", 0xf05b3, "windows exe msi wine proton umu program"],
        ["TuxOS", "developer", "Developer", 0xf0169, "developer code git ssh key podman docker distrobox ubuntu fedora debian container toolbox"],
        ["TuxOS", "ai", "AI", 0xf06a9, "ollama local ask assistant"],
        ["TuxOS", "about", "About", 0xf02fc, "version system info hardware report problem"]
    ]
    readonly property var shown: {
        const q = app.search.trim().toLowerCase();
        if (!q) return pages;
        return pages.filter(p => p[2].toLowerCase().indexOf(q) !== -1 || p[4].indexOf(q) !== -1);
    }
    onSearchAccepted: if (shown.length) page = shown[0][1]

    // ---- sidebar
    Flickable {
        id: side
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 250
        contentHeight: sideCol.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: sideCol
            x: 12; y: 12
            width: side.width - 24
            spacing: 4
            Repeater {
                model: app.shown
                delegate: Column {
                    required property var modelData
                    required property int index
                    width: sideCol.width
                    Text {
                        visible: index === 0 || app.shown[index - 1][0] !== modelData[0]
                        text: Tr.t(modelData[0]).toUpperCase()
                        leftPadding: 8; topPadding: index === 0 ? 6 : 16; bottomPadding: 4
                        font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted
                    }
                    Rectangle {
                        width: parent.width; height: 38; radius: 11
                        color: app.page === modelData[1] ? Theme.accentFill : (ih.hovered ? Theme.fill : "transparent")
                        border.width: app.page === modelData[1] ? 1 : 0; border.color: Theme.accentLine
                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            Text { width: 18; text: String.fromCodePoint(modelData[3]); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: app.page === modelData[1] ? Theme.accent : Theme.muted }
                            Text { text: Tr.t(modelData[2]); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                        }
                        HoverHandler { id: ih; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: app.page = modelData[1] }
                    }
                }
            }
        }
    }
    Rectangle { anchors { left: side.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.glassLine }

    // ---- the page
    Flickable {
        id: pageArea
        anchors { left: side.right; leftMargin: 1; right: parent.right; top: parent.top; bottom: parent.bottom }
        contentHeight: loader.item ? loader.item.implicitHeight + 64 : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Loader {
            id: loader
            x: 28; y: 28
            width: pageArea.width - 60
            source: {
                const map = { network: "PageNetwork", bluetooth: "PageBluetooth", displays: "PageDisplays", sound: "PageSound", power: "PagePower",
                              storage: "PageStorage", appearance: "PageAppearance", desktop: "PageDesktop", windows: "PageWindows", notifications: "PageNotifications",
                              keyboard: "PageKeyboard", mouse: "PageMouse", apps: "PageApps", datetime: "PageDateTime", region: "PageRegion",
                              accessibility: "PageAccessibility", gaming: "PageGaming", performance: "PagePerformance", updates: "PageUpdates",
                              privacy: "PagePrivacy", users: "PageUsers", ai: "PageAi", about: "PageAbout", winapps: "PageWinApps", developer: "PageDeveloper" };
                return (map[app.page] || "PageAppearance") + ".qml";
            }
            onSourceChanged: pageArea.contentY = 0
        }
    }
}
