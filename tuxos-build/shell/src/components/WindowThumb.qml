import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.services

// A live picture of one window (Alt + Tab, Mission Control, dock previews,
// video preview). First choice: the compositor's per-window capture. Where
// that is not available (Hyprland 0.57 refuses it in the dev VM) and the
// window is on a visible desktop, a crop of the screen capture; otherwise
// the app's smart symbol on a tile.
ClippingRectangle {
    id: thumb

    property var toplevel: null                  // Quickshell Toplevel
    property bool live: true
    radius: 14
    color: Theme.ink(0.05)

    readonly property var hypr: toplevel ? Hyprland.toplevels.values.find(h => h.wayland === toplevel) || null : null
    readonly property var ipc: hypr ? hypr.lastIpcObject : null
    readonly property var ws: hypr ? hypr.workspace : null
    readonly property bool onScreen: ws !== null && ws.monitor !== null && ws.monitor.activeWorkspace === ws
    readonly property var screen: ws && ws.monitor ? Quickshell.screens.find(s => s.name === ws.monitor.name) || null : null

    property bool directFailed: false
    Timer { interval: 900; running: thumb.toplevel !== null && !direct.hasContent; onTriggered: thumb.directFailed = true }

    ScreencopyView {
        id: direct
        anchors.fill: parent
        captureSource: thumb.directFailed ? null : thumb.toplevel
        live: thumb.live
        visible: hasContent
    }

    // crop of the screen the window is on
    Item {
        anchors.fill: parent
        visible: !direct.hasContent && thumb.directFailed && thumb.onScreen && thumb.ipc && thumb.ipc.at !== undefined && crop.hasContent
        // one scale for both axes: fill the thumbnail, centred
        readonly property real sc: thumb.ipc && thumb.ipc.size ? Math.max(width / thumb.ipc.size[0], height / thumb.ipc.size[1]) : 1
        readonly property real ox: thumb.ipc && thumb.ipc.size ? (width - thumb.ipc.size[0] * sc) / 2 : 0
        readonly property real oy: thumb.ipc && thumb.ipc.size ? (height - thumb.ipc.size[1] * sc) / 2 : 0
        ScreencopyView {
            id: crop
            captureSource: thumb.directFailed && thumb.onScreen ? thumb.screen : null
            live: thumb.live
            width: thumb.screen ? thumb.screen.width * parent.sc : 0
            height: thumb.screen ? thumb.screen.height * parent.sc : 0
            x: thumb.ipc && thumb.ipc.at && thumb.screen ? -(thumb.ipc.at[0] - thumb.screen.x) * parent.sc + parent.ox : 0
            y: thumb.ipc && thumb.ipc.at && thumb.screen ? -(thumb.ipc.at[1] - thumb.screen.y) * parent.sc + parent.oy : 0
        }
    }

    // no picture: the app's symbol
    AppTile {
        anchors.centerIn: parent
        visible: !direct.hasContent && !(thumb.directFailed && thumb.onScreen && crop.hasContent)
        size: Math.min(64, Math.min(parent.width, parent.height) * 0.45)
        appId: thumb.toplevel ? thumb.toplevel.appId : ""
        entry: thumb.toplevel ? DesktopEntries.heuristicLookup(thumb.toplevel.appId) : null
    }
}
