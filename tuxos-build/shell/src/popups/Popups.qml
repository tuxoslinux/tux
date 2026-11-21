import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// One transparent layer under the bar per screen that hosts the droplet
// panels. Only the open panel takes input (mask); the compositor blurs only
// its visible pixels (layer rule with ignore_alpha).
PanelWindow {
    id: win

    property string screenName: ""          // set once by shell.qml
    readonly property bool mine: Shell.screenName === screenName
    readonly property string open: mine ? Shell.panel : ""

    anchors { top: true; left: true; right: true }
    margins.top: Theme.barTop + Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: 820
    color: "transparent"
    visible: tipBox.opacity > 0 || privDrop.progress > 0 || gameDrop.progress > 0 || wifiDrop.progress > 0 || open !== "" || calDrop.progress > 0 || statusDrop.progress > 0 || osdDrop.progress > 0 || mediaDrop.progress > 0 || menuDrop.progress > 0

    WlrLayershell.namespace: "tuxos-drop"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open === "status" || open === "privacy" || open === "wifi" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region { item: win.open === "status" ? statusDrop : win.open === "media" ? mediaDrop : win.open === "privacy" ? privDrop : win.open === "wifi" ? wifiDrop : win.open === "gamesum" ? gameDrop : win.open === "menu" ? menuDrop : calDrop }

    // tooltip pill under the bar (never takes input)
    Rectangle {
        id: tipBox
        readonly property bool on: Shell.tip !== "" && Shell.tipScreen === win.screenName && win.open === ""
        opacity: on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        y: 4
        x: Math.max(Theme.edge, Math.min(win.width - width - Theme.edge, Shell.tipX - width / 2))
        width: tipText.implicitWidth + 22; height: 30; radius: 10
        color: Theme.glassPanel
        border.width: 1; border.color: Theme.glassLine
        Text { id: tipText; anchors.centerIn: parent; text: Shell.tip; textFormat: Text.StyledText; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text }
    }

    function placeX(w) {
        return Math.max(Theme.edge, Math.min(win.width - w - Theme.edge, Shell.anchorX - w / 2));
    }

    // ---- clock: opens on hover, closes when the pointer leaves both
    Droplet {
        id: calDrop
        width: 440
        panelHeight: calContent.implicitHeight + neckHeight
        x: win.placeX(width)
        neckX: Shell.anchorX - x
        neckWidth: Math.min(150, Shell.anchorWidth)
        progress: win.open === "calendar" ? 1 : 0
        Behavior on progress { enabled: !Theme.reduceMotion; Spring { unit: true } }
        visible: progress > 0
        Loader {
            // built only while open (memory)
            id: calContent
            width: parent.width
            active: win.open === "calendar" || calDrop.progress > 0
            sourceComponent: Component { CalendarDrop {} }
        }
        HoverHandler { id: calHover }
    }
    Timer {
        // small grace period so moving from the clock into the panel keeps it open
        interval: 220
        running: win.open === "calendar" && !Shell.clockHovered && !calHover.hovered
        onTriggered: Shell.close()
    }

    // ---- live activity chip: opens on hover, like the clock
    Droplet {
        id: mediaDrop
        width: 470
        panelHeight: mediaContent.implicitHeight + neckHeight
        x: win.placeX(width)
        neckX: Shell.anchorX - x
        neckWidth: Math.min(170, Shell.anchorWidth)
        progress: win.open === "media" ? 1 : 0
        Behavior on progress { enabled: !Theme.reduceMotion; Spring { unit: true } }
        visible: progress > 0
        Loader {
            // built only while open (memory)
            id: mediaContent
            width: parent.width
            active: win.open === "media" || mediaDrop.progress > 0
            sourceComponent: Component { MediaDrop {} }
        }
        HoverHandler { id: mediaHover }
    }
    Timer {
        interval: 220
        running: win.open === "media" && !Shell.mediaHovered && !mediaHover.hovered
        onTriggered: Shell.close()
    }

    // ---- status group: opens on click, closes on click outside or Esc
    Droplet {
        id: statusDrop
        width: 400
        panelHeight: statusContent.implicitHeight + neckHeight
        x: win.placeX(width)
        neckX: Shell.anchorX - x
        neckWidth: Math.min(120, Shell.anchorWidth)
        progress: win.open === "status" ? 1 : 0
        Behavior on progress { enabled: !Theme.reduceMotion; Spring { unit: true } }
        visible: progress > 0
        Loader {
            // built only while open (memory)
            id: statusContent
            width: parent.width
            active: win.open === "status" || statusDrop.progress > 0
            sourceComponent: Component { StatusDrop {} }
        }
    }
    Item {
        focus: win.open === "status"
        Keys.onEscapePressed: Shell.close()
    }
    // ---- volume flyout: any volume / mute change on the default output
    // shows it on the focused screen for ~1.5 s (SPEC)
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [win.sink] }
    property bool osdShown: false
    property string osdKind: "volume"          // "volume" | "generic"
    property bool osdArmed: false        // ignore the values reported at start
    Timer { interval: 1500; running: true; onTriggered: win.osdArmed = true }
    Timer { id: osdHide; interval: 1500; onTriggered: win.osdShown = false }
    function showOsd(kind) {
        if (!osdArmed || win.open === "status") return;
        win.osdKind = kind || "volume";
        const fm = Hyprland.focusedMonitor;
        if (fm && fm.name !== win.screenName) return;
        osdShown = true;
        osdHide.restart();
    }
    Connections {
        target: Shell
        function onFlyoutSerialChanged() { win.showOsd("generic"); }
    }
    // microphone mute (key or app): a flyout too
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [win.source] }
    Connections {
        target: win.source && win.source.audio ? win.source.audio : null
        function onMutedChanged() {
            Shell.flyout({ icon: win.source.audio.muted ? Icons.microphoneOff : Icons.microphone, title: win.source.description || "Microphone",
                           sub: "Microphone", text: win.source.audio.muted ? "Muted" : "On", off: win.source.audio.muted, value: -1 });
        }
    }
    Connections {
        target: win.sink && win.sink.audio ? win.sink.audio : null
        function onVolumeChanged() { win.showOsd(); }
        function onMutedChanged() { win.showOsd(); }
    }
    Droplet {
        id: osdDrop
        width: 360
        panelHeight: (win.osdKind === "volume" ? osdContent.implicitHeight : (Shell.flyoutData && Shell.flyoutData.value >= 0 ? 100 : 82)) + neckHeight
        x: Math.max(Theme.edge, Math.min(win.width - width - Theme.edge, Shell.statusXFor(win.screenName) - width / 2))
        neckX: Shell.statusXFor(win.screenName) - x
        neckWidth: Math.min(100, Shell.statusWidth)
        progress: win.osdShown ? 1 : 0
        Behavior on progress { enabled: !Theme.reduceMotion; Spring { unit: true } }
        visible: progress > 0
        VolumeOsd { id: osdContent; width: parent.width; sink: win.sink; visible: win.osdKind === "volume" }
        Flyout { width: parent.width; visible: win.osdKind === "generic" }
    }

    // ---- Wi-Fi password (from the status droplet's network list)
    Droplet {
        id: wifiDrop
        width: 380
        panelHeight: wifiContent.implicitHeight + neckHeight
        x: win.placeX(width)
        neckX: Shell.anchorX - x
        neckWidth: Math.min(120, Shell.anchorWidth)
        progress: win.open === "wifi" ? 1 : 0
        Behavior on progress { enabled: !Theme.reduceMotion; Spring { unit: true } }
        visible: progress > 0
        onProgressChanged: if (progress === 1 && wifiContent.item) wifiContent.item.focus()
        Loader {
            // built only while open (memory)
            id: wifiContent
            width: parent.width
            active: win.open === "wifi" || wifiDrop.progress > 0
            sourceComponent: Component { WifiPassword {} }
        }
    }

    // ---- right-click menus of the bar's items (Shell.menu)
    Droplet {
        id: menuDrop
        width: 260
        panelHeight: menuCol.implicitHeight + neckHeight + 16
        x: win.placeX(width)
        neckX: Shell.anchorX - x
        neckWidth: 60
        progress: win.open === "menu" ? 1 : 0
        Behavior on progress { enabled: !Theme.reduceMotion; Spring { unit: true } }
        visible: progress > 0
        Column {
            id: menuCol
            x: 8; y: 8
            width: parent.width - 16
            Repeater {
                model: win.open === "menu" && Array.isArray(Shell.panelData) ? Shell.panelData : []
                delegate: MenuRow {
                    required property var modelData
                    width: menuCol.width
                    label: modelData.label; icon: modelData.icon || 0; danger: !!modelData.danger
                    onHit: { const r = modelData.run; Shell.close(); r(); }   // closing first destroys this row
                }
            }
        }
    }

    // ---- game session summary (after a game closes; click outside or 20 s)
    Droplet {
        id: gameDrop
        width: 460
        panelHeight: gameContent.implicitHeight + neckHeight
        x: win.placeX(width)
        neckX: Shell.anchorX - x
        neckWidth: 140
        progress: win.open === "gamesum" ? 1 : 0
        Behavior on progress { enabled: !Theme.reduceMotion; Spring { unit: true } }
        visible: progress > 0
        Loader {
            // built only while open (memory)
            id: gameContent
            width: parent.width
            active: win.open === "gamesum" || gameDrop.progress > 0
            sourceComponent: Component { GameSummary {} }
        }
        HoverHandler { id: gameHover }
    }
    Timer { interval: 20000; running: win.open === "gamesum" && !gameHover.hovered; onTriggered: Shell.close() }

    // ---- privacy pill: who uses the mic / camera / screen, with Stop
    Droplet {
        id: privDrop
        width: 360
        panelHeight: privCol.implicitHeight + neckHeight + 36
        x: win.placeX(width)
        neckX: Shell.anchorX - x
        neckWidth: Math.min(90, Shell.anchorWidth)
        progress: win.open === "privacy" ? 1 : 0
        Behavior on progress { enabled: !Theme.reduceMotion; Spring { unit: true } }
        visible: progress > 0
        Column {
            id: privCol
            x: 20; y: 16
            width: parent.width - 40
            spacing: 8
            Text { text: Tr.t("In use right now"); font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
            Repeater {
                model: Privacy.list
                delegate: Item {
                    required property var modelData
                    width: privCol.width; height: 44
                    Rectangle {
                        width: 34; height: 34; radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(1, 0.54, 0.40, 0.18)
                        Sym { anchors.centerIn: parent; code: modelData.kind === "Microphone" ? Icons.microphone : modelData.kind === "Camera" ? Icons.webcam : Icons.monitorScreenshot; color: Theme.warn; font.pixelSize: Theme.px(16) }
                    }
                    Column {
                        x: 44; anchors.verticalCenter: parent.verticalCenter
                        Text { text: modelData.app; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                        Text { text: Tr.t(modelData.kind); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                    }
                    Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 64; height: 30; radius: 10
                        color: Qt.rgba(1, 0.48, 0.54, stopH.hovered ? 0.35 : 0.2)
                        Text { anchors.centerIn: parent; text: Tr.t("Stop"); font.family: Theme.font; font.pixelSize: Theme.px(13); font.weight: Font.DemiBold; color: Theme.danger }
                        HoverHandler { id: stopH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Privacy.stop(modelData) }
                    }
                }
            }
        }
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open === "status" || win.open === "privacy" || win.open === "wifi" || win.open === "gamesum"
        onCleared: Shell.close()
    }
}
