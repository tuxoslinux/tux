import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// The wallpaper of one screen (Wallpapers.qml has the rules): the desktop
// shown on this screen picks it; a change crossfades (200 ms). Live
// wallpapers: a looping, muted video (desktop/LiveVideo.qml, loaded only
// then) or a shader; both pause per Wallpapers.paused. Right click on the
// empty desktop: change wallpaper, display settings, Settings (no icons).
PanelWindow {
    id: bg
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "tuxwall"            // not blurred (not "tuxos-*")

    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === bg.screen.name) || null
    readonly property int wsId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
    readonly property string path: Wallpapers.pathFor(bg.screen.name, wsId)
    readonly property bool live: Wallpapers.isLive(path)

    // two picture layers for the crossfade
    property bool flip: false
    property string shownA: ""
    property string shownB: ""
    function show(p) {
        if (Wallpapers.isLive(p)) return;
        const url = "file://" + p + "?s=" + Wallpapers.stamp;
        if (flip ? shownB === url : shownA === url) return;
        if (flip) shownA = url; else shownB = url;
        flip = !flip;
    }
    onPathChanged: show(path)
    Connections { target: Wallpapers; function onStampChanged() { bg.show(bg.path); } }
    Component.onCompleted: show(path)

    Image {
        id: a
        anchors.fill: parent
        source: bg.shownA
        sourceSize: Qt.size(bg.width * (bg.screen.devicePixelRatio || 1), bg.height * (bg.screen.devicePixelRatio || 1))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: !bg.live && !bg.flip ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
    }
    Image {
        id: b
        anchors.fill: parent
        source: bg.shownB
        sourceSize: a.sourceSize
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: !bg.live && bg.flip ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
    }
    // a video wallpaper (Qt Multimedia is loaded only for it)
    Loader {
        anchors.fill: parent
        active: Wallpapers.isVideo(bg.path)
        source: "LiveVideo.qml"
        onLoaded: { item.file = Qt.binding(() => bg.path); item.paused = Qt.binding(() => Wallpapers.paused); }
    }
    // a shader wallpaper
    Loader {
        anchors.fill: parent
        active: Wallpapers.isShader(bg.path)
        sourceComponent: ShaderEffect {
            property real time: 0
            property vector2d resolution: Qt.vector2d(width, height)
            property color accent: Theme.accent
            fragmentShader: Qt.resolvedUrl("../assets/shaders/" + bg.path.slice(7) + ".frag.qsb")
            NumberAnimation on time { from: 0; to: 3600; duration: 3600000; loops: Animation.Infinite; paused: Wallpapers.paused || Theme.reduceMotion }
        }
    }

    // accent from the wallpaper (first screen only)
    ColorPick {
        id: pick
        source: Prefs.accentFromWallpaper && bg.screen === Quickshell.screens[0] && !bg.live ? (bg.flip ? bg.shownB : bg.shownA) : ""
        onPicked: c => { if (Prefs.accentFromWallpaper && c.toString() !== Theme.baseAccent.toString()) Prefs.accent = c.toString(); }
    }
    // accent from album art while music plays (first screen only; the shell only)
    ColorPick {
        id: albumPick
        readonly property bool mine: bg.screen === Quickshell.screens[0]
        source: Prefs.accentFromAlbum && mine && Media.player && Media.player.isPlaying && Media.player.trackArtUrl ? Media.player.trackArtUrl : ""
        onPicked: c => { if (source.toString() !== "") Theme.accentOverride = c; }
        // music stopped / paused / no cover / switched off: back to the normal accent
        onSourceChanged: { if (mine && source.toString() === "") Theme.accentOverride = "transparent"; }
    }

    // the depth-effect mask of the wallpaper picture, made once (first screen)
    Loader {
        active: Wallpapers.depthWanted !== "" && bg.screen === Quickshell.screens[0]
        sourceComponent: DepthMask {
            source: "file://" + Wallpapers.defaultFile
            onMade: {
                if (!found) { Wallpapers.depthNotFound(); return; }
                Quickshell.execDetached(["mkdir", "-p", Wallpapers.depthDir]);
                Qt.callLater(() => { if (save(Wallpapers.depthWanted)) Wallpapers.depthSaved(); });
            }
        }
    }

    // right click on the desktop
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: m => bg.openMenuAt(m.x, m.y)
    }
    // touch: long press = right click
    TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: bg.openMenuAt(point.position.x, point.position.y) }
    function openMenuAt(x, y) { menu.x = Math.min(x, bg.width - menu.width - 12); menu.y = Math.min(y, bg.height - menu.height - 12); menu.visible = true; }
    MouseArea { anchors.fill: parent; visible: menu.visible; acceptedButtons: Qt.AllButtons; onPressed: menu.visible = false }
    // it also closes when a window takes focus, an overlay or droplet opens,
    // or after a while without the pointer on it (the background layer gets
    // no other way to know)
    Connections {
        target: Hyprland
        enabled: menu.visible
        function onRawEvent(e) { if (e.name === "activewindow" || e.name === "openwindow" || e.name === "workspace") menu.visible = false; }
    }
    Connections { target: Shell; enabled: menu.visible; function onOverlayChanged() { menu.visible = false; } function onPanelChanged() { menu.visible = false; } }
    Timer { interval: 8000; running: menu.visible && !menuHover.hovered; onTriggered: menu.visible = false }
    Rectangle {
        id: menu
        visible: false
        HoverHandler { id: menuHover }
        width: 250; height: mcol.implicitHeight + 12; radius: 14
        color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
        Column {
            id: mcol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            Repeater {
                model: [[0xf0e09, "Change wallpaper", "appearance"], [0xf0379, "Display settings", "displays"], [0xf05b5, "Desktop and dock", "desktop"], [0xf0493, "Settings", ""]]
                delegate: MenuRow {
                    required property var modelData
                    width: mcol.width
                    icon: modelData[0]; label: modelData[1]
                    onHit: { menu.visible = false; Quickshell.execDetached(["tuxos-app", "control"].concat(modelData[2] ? ["--page", modelData[2]] : [])); }
                }
            }
        }
    }
}
