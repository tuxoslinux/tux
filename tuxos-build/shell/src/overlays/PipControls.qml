import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Controls on a picture-in-picture window that TuxOS made from a player
// without its own PiP (SPEC "Live activities": play / pause, slider, volume,
// full screen, back to the page, close). A thin glass strip along the
// window's bottom edge; faint until the pointer is on it.
PanelWindow {
    id: win

    component B: Item {
        property int code
        signal hit()
        width: 28; height: 44
        Sym { anchors.centerIn: parent; code: parent.code; font.pixelSize: Theme.px(17); color: bh.hovered ? Theme.accent : Theme.text }
        HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: parent.hit() }
    }

    readonly property var player: Media.pipPlayer
    // the pinned window of that player
    readonly property var hwin: {
        if (!player) return null;
        void Hyprland.toplevels.values;
        const want = AppSymbols.norm(player.desktopEntry || player.identity);
        return Hyprland.toplevels.values.find(h => h.lastIpcObject && h.lastIpcObject.pinned && AppSymbols.norm(h.lastIpcObject.class).indexOf(want) !== -1) || null;
    }
    readonly property var ipc: hwin ? hwin.lastIpcObject : null
    readonly property var mon: hwin && hwin.monitor ? hwin.monitor : null

    // the screen is fixed when PiP starts (changing it on a shown window loops)
    property string screenName: ""
    onPlayerChanged: if (player !== null) screenName = Shell.focusedScreen
    screen: Quickshell.screens.find(s => s.name === screenName) || Quickshell.screens[0]
    visible: player !== null && ipc !== null && ipc.size !== undefined && ipc.size[0] > 140
    anchors { top: true; left: true }
    margins.left: ipc && ipc.at ? Math.max(0, ipc.at[0] - screen.x + 8) : 0
    margins.top: ipc && ipc.at ? Math.max(0, ipc.at[1] + ipc.size[1] - screen.y - 52) : 0
    implicitWidth: ipc && ipc.size ? Math.max(120, ipc.size[0] - 16) : 120
    implicitHeight: 44
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "tuxos-pip"
    WlrLayershell.layer: WlrLayer.Overlay

    // keep the window geometry fresh while PiP is up (it can be dragged)
    Timer { interval: 500; repeat: true; running: Media.pipPlayer !== null; onTriggered: Hyprland.refreshToplevels() }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.glassPanel
        border.width: 1; border.color: Theme.glassLine
        opacity: hov.hovered ? 1 : 0.35
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        HoverHandler { id: hov }

        Row {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 8
            B { code: win.player && win.player.isPlaying ? Icons.pause : Icons.play; onHit: win.player.togglePlaying() }
            Slider {
                width: parent.width - 5 * 36 - 8
                anchors.verticalCenter: parent.verticalCenter
                value: Media.progress(win.player)
                onMoved: v => { if (win.player && win.player.canSeek) win.player.position = v * win.player.length; }
            }
            B { code: win.player && win.player.volume < 0.01 ? Icons.volumeOff : Icons.volumeHigh; onHit: win.player.volume = win.player.volume > 0.01 ? 0 : 1 }
            B { code: Icons.fullscreen; onHit: Shell.dispatch(`hl.dsp.window.fullscreen({ window = "address:${win.ipc.address}" })`, `fullscreen`) }
            B {
                // back to the page: the window returns to normal
                code: Icons.windowRestore
                onHit: {
                    const a = `address:${win.ipc.address}`;
                    Shell.dispatch(`hl.dsp.window.pin({ window = "${a}" })`, "pin");
                    Shell.dispatch(`hl.dsp.window.float({ action = "unset", window = "${a}" })`, "settiled");
                    Media.pipPlayer = null;
                }
            }
            B { code: Icons.close; onHit: { Shell.dispatch(`hl.dsp.window.close({ window = "address:${win.ipc.address}" })`, "killactive"); Media.pipPlayer = null; } }
        }
    }
}
