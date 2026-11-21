import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// TuxOS title bar for apps that draw none (SPEC windows: "TuxOS title bar for
// apps without one (min / max / close)"). Wayland cannot tell the shell
// whether an app draws its own title bar, so apps known to draw one (TuxOS
// apps, browsers, GTK 4 / libadwaita, Steam, Electron chat and music apps)
// are skipped and everything else gets the bar; Settings > Window rules can
// say Always / Never per app, and Settings > Windows turns it off.
// The bar is a glass strip just above the focused floating window: drag it
// to move the window, double-click to maximize, min / max / close on the
// right. While the window moves some other way (Super + drag) the bar steps
// aside and comes back when it stops.
PanelWindow {
    id: win

    // apps that draw their own title bar / tab strip
    readonly property var ownBars: /^(tuxos-.*|helium|chromium|google-chrome.*|brave-browser.*|vivaldi.*|microsoft-edge.*|firefox.*|librewolf|zen.*|floorp|org\.gnome\..*|gnome-.*|nautilus|steam|steamwebhelper|discord|vesktop|webcord|spotify|code|code-oss|vscodium|cursor|obsidian|signal.*|org\.telegram\..*|telegramdesktop|slack|zoom|calamares|mpv|org\.pulseaudio\.pavucontrol|com\.github\.wwmm\.easyeffects|io\.missioncenter\..*|com\.mattjakeman\..*|org\.freedesktop\.impl\..*|xdg-desktop-portal.*|hyprland-share-picker|polkit.*|lutris|heroic|net\.davidotek\.pupgui2|com\.usebottles\..*)$/i

    property var perApp: ({})           // class (lower case) -> "always" / "never"
    FileView {
        path: Quickshell.env("HOME") + "/.config/tuxos/window-rules.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const m = {};
                for (const r of JSON.parse(text()) || []) if (r.titleBar && r.titleBar !== "auto") m[String(r.cls).toLowerCase()] = r.titleBar;
                win.perApp = m;
            } catch (e) { win.perApp = {}; }
        }
    }

    readonly property var hwin: Hyprland.activeToplevel
    readonly property var ipc: hwin ? hwin.lastIpcObject : null
    readonly property string cls: ipc && ipc.class ? String(ipc.class) : ""
    readonly property bool wanted: {
        if (!Prefs.titleBars || !ipc || !ipc.at || !ipc.size || cls === "") return false;
        if (!ipc.floating || ipc.fullscreen > 0 || ipc.pinned) return false;
        if (ipc.workspace && String(ipc.workspace.name).startsWith("special")) return false;
        // the window must be on the desktop its monitor shows (it may have
        // been moved away while still the last active one)
        const ws = hwin.workspace, mws = hwin.monitor ? hwin.monitor.activeWorkspace : null;
        if (!ws || !mws || ws.id !== mws.id) return false;
        if (Shell.fullscreenFocused || Power.locked || Shell.overlay !== "") return false;
        const rule = perApp[cls.toLowerCase()];
        if (rule === "never") return false;
        if (rule !== "always" && ownBars.test(cls)) return false;
        return ipc.size[0] >= 160;
    }

    // the window's screen
    readonly property var mon: hwin && hwin.monitor ? hwin.monitor : null
    screen: Quickshell.screens.find(s => mon && s.name === mon.name) || Quickshell.screens[0]

    // geometry, followed while the bar is up; a change we did not make hides
    // the bar until the window rests again
    property rect geo: Qt.rect(0, 0, 0, 0)
    property bool settling: false
    property bool dragging: false
    function readGeo() {
        if (!ipc || !ipc.at) return;
        const g = Qt.rect(ipc.at[0], ipc.at[1], ipc.size[0], ipc.size[1]);
        if (!dragging && (g.x !== geo.x || g.y !== geo.y || g.width !== geo.width || g.height !== geo.height)) {
            settling = geo.width > 0 && (g.x !== geo.x || g.y !== geo.y) && hwin === lastWin;
            geo = g;
        } else settling = false;
        lastWin = hwin;
    }
    property var lastWin: null
    onIpcChanged: readGeo()
    Timer {
        interval: 150; repeat: true
        running: win.wanted
        onTriggered: { Hyprland.refreshToplevels(); win.readGeo(); }
    }

    readonly property int barH: 30
    // room above the window, below the bar / screen edge
    readonly property bool room: geo.y - barH - 2 >= (mon && mon.lastIpcObject && mon.lastIpcObject.reserved ? mon.lastIpcObject.reserved[1] : 0) + (screen ? screen.y : 0)
    visible: wanted && room && !settling && geo.width > 0
    // while dragging, the surface covers the screen (pointer positions stay
    // in one frame of reference) and the bar is drawn where the window is
    anchors { top: true; left: true; right: dragging; bottom: dragging }
    margins.left: dragging ? 0 : Math.max(0, geo.x - (screen ? screen.x : 0))
    margins.top: dragging ? 0 : Math.max(0, geo.y - barH - 2 - (screen ? screen.y : 0))
    implicitWidth: Math.max(160, geo.width)
    implicitHeight: barH
    readonly property bool full: dragging && screen && width === screen.width
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "tuxos-titlebar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function sel() { return `window = "address:${Shell.addr(win.hwin)}"`; }

    // drag to move, double-click to maximize (window coordinates: the bar
    // alone, or the whole screen while dragging)
    MouseArea {
        id: dragArea
        anchors.fill: parent
        property point press
        property point start
        property point base         // the surface's screen position at press time
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onPressed: m => {
            base = Qt.point(win.margins.left, win.margins.top);
            press = Qt.point(base.x + m.x, base.y + m.y);
            start = Qt.point(win.geo.x, win.geo.y);
            win.dragging = true;
            Shell.dispatch(`hl.dsp.focus({ ${win.sel()} })`, "");
        }
        onPositionChanged: m => {
            if (!pressed) return;
            const p = win.full ? Qt.point(m.x, m.y) : Qt.point(base.x + m.x, base.y + m.y);
            const x = Math.round(start.x + p.x - press.x), y = Math.round(start.y + p.y - press.y);
            if (x === win.geo.x && y === win.geo.y) return;
            win.geo = Qt.rect(x, y, win.geo.width, win.geo.height);
            Shell.dispatch(`hl.dsp.window.move({ x = ${x}, y = ${y}, exact = true, ${win.sel()} })`, "");
        }
        onReleased: m => {
            if (win.full && win.screen) Shell.windowDropped(win.screen.name, m.x, m.y, Shell.addr(win.hwin));
            win.dragging = false;
            Shell.windowsMoved();
        }
        onDoubleClicked: Shell.dispatch(`hl.dsp.window.fullscreen({ mode = "maximized", ${win.sel()} })`, "")
    }

    Rectangle {
        x: win.dragging ? win.geo.x - (win.screen ? win.screen.x : 0) : 0
        y: win.dragging ? win.geo.y - win.barH - 2 - (win.screen ? win.screen.y : 0) : 0
        width: win.dragging ? win.geo.width : parent.width
        height: win.barH
        radius: 10
        color: Theme.glassPanel
        border.width: 1; border.color: Theme.glassLine

        AppTile {
            id: icon
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            size: 20
            appId: win.cls
            entry: win.cls ? DesktopEntries.heuristicLookup(win.cls) : null
        }
        Text {
            anchors { left: icon.right; leftMargin: 8; right: buttons.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: win.ipc && win.ipc.title ? win.ipc.title : win.cls
            elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: Theme.px(13); font.weight: Font.Medium
            color: Theme.text
        }
        Row {
            id: buttons
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            spacing: 4
            Repeater {
                model: [[Icons.windowMinimize, "min", Tr.t("Minimize")], [Icons.windowMaximize, "max", Tr.t("Maximize")], [Icons.windowClose, "close", Tr.t("Close")]]
                delegate: Rectangle {
                    required property var modelData
                    width: 28; height: 24; radius: 8
                    color: bh.hovered ? (modelData[1] === "close" ? Theme.danger : Theme.ink(0.10)) : "transparent"
                    Sym { anchors.centerIn: parent; code: modelData[0]; font.pixelSize: Theme.px(15); color: bh.hovered && modelData[1] === "close" ? "#ffffff" : Theme.text }
                    HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (modelData[1] === "close") Shell.dispatch(`hl.dsp.window.close({ ${win.sel()} })`, "");
                            else if (modelData[1] === "min") Shell.dispatch(`hl.dsp.global("tuxos:minimize")`, "");
                            else Shell.dispatch(`hl.dsp.window.fullscreen({ mode = "maximized", ${win.sel()} })`, "");
                        }
                    }
                }
            }
        }
    }
}
