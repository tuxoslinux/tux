import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// The floating top bar (SPEC "Top bar" - approved): 10 px from the top,
// 12 px from the sides, one glass strip.
PanelWindow {
    id: bar

    anchors { top: true; left: true; right: true }
    margins { top: Theme.barTop; left: Theme.edge; right: Theme.edge }
    implicitHeight: Theme.barHeight
    // auto-hide (Settings > Desktop & dock, for small screens): windows get
    // the whole height; the bar slides away while a tiled, maximized or
    // full-screen window is on this screen's desktop and comes back at the
    // top edge, while Super is held or while one of its droplets is open
    exclusiveZone: Prefs.barAutoHide ? 0 : Theme.barHeight
    color: "transparent"

    readonly property var hyprMonitor: Hyprland.monitors.values.find(m => bar.screen && m.name === bar.screen.name) || null
    property bool covered: false
    function recheck() {
        const ws = hyprMonitor ? hyprMonitor.activeWorkspace : null;
        if (!ws) { covered = false; return; }
        let c = false;
        for (const w of ws.toplevels.values) {
            const o = w.lastIpcObject || {};
            if (o.floating === false || o.fullscreen > 0 || (w.wayland && (w.wayland.maximized || w.wayland.fullscreen))) { c = true; break; }
        }
        covered = c;
    }
    Connections {
        target: Hyprland
        enabled: Prefs.barAutoHide
        function onRawEvent(event) {
            if (/window|workspace|float|fullscreen|move/.test(event.name)) recheckLater.restart();
        }
    }
    Timer { id: recheckLater; interval: 150; onTriggered: { Hyprland.refreshToplevels(); bar.recheck(); } }
    Connections { target: Prefs; function onBarAutoHideChanged() { recheckLater.restart(); } }
    Component.onCompleted: recheckLater.restart()
    property bool peek: false
    Timer { id: peekOff; interval: 1600; onTriggered: bar.peek = false }
    Connections { target: Shell; function onPeekBar() { bar.peek = true; peekOff.restart(); } }
    readonly property bool hidden: Prefs.barAutoHide && covered && !peek && !barHover.hovered && !edgeHover.hovered
                                   && !(Shell.panel !== "" && Shell.screenName === (bar.screen ? bar.screen.name : ""))
    HoverHandler { id: barHover }
    // no clicks land on the hidden bar
    mask: Region { item: hidden ? null : slide }

    // the top-edge strip that brings the hidden bar back
    PanelWindow {
        screen: bar.screen
        visible: Prefs.barAutoHide
        anchors { top: true; left: true; right: true }
        implicitHeight: 2
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.namespace: "tuxos-baredge"
        WlrLayershell.layer: WlrLayer.Top
        HoverHandler { id: edgeHover }
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.01) }
    }

    // right-click menus of the bar's items (SPEC right-click menus)
    function settings(page) { Apps.run(`${Prefs.settingsApp} --page ${page}`); }
    function menuFor(kind, item) {
        const p = item.mapToItem(null, item.width / 2, 0);
        const x = (bar.screen ? bar.screen.x : 0) + Theme.edge + p.x;
        let items = [];
        if (kind === "tux") items = [
            { label: Tr.t("App launcher"), icon: Icons.magnify, run: () => Shell.showOverlay("launcher") },
            { label: Tr.t("Mission Control"), icon: Icons.viewGrid, run: () => Shell.showOverlay("mission") },
            { label: Tr.t("Settings"), icon: Icons.cog, run: () => bar.settings("appearance") },
            { label: Tr.t("About TuxOS"), icon: Icons.informationOutline, run: () => bar.settings("about") },
            { label: Tr.t("Power menu"), icon: Icons.power, run: () => Shell.showOverlay("power") }];
        else if (kind === "clock") items = [
            { label: Tr.t("Calendar"), icon: Icons.calendar, run: () => Apps.run("tuxos-app calendar") },
            { label: Tr.t("Clock, alarms and timers"), icon: Icons.alarm, run: () => Apps.run("tuxos-app clock") },
            { label: Tr.t("Date & time settings"), icon: Icons.cog, run: () => bar.settings("datetime") }];
        else if (kind === "live") {
            const pl = Media.player;
            if (!pl) return;
            items = [
                { label: pl.isPlaying ? Tr.t("Pause") : Tr.t("Play"), icon: pl.isPlaying ? Icons.pause : Icons.play, run: () => pl.togglePlaying() },
                { label: Tr.t("Next"), icon: Icons.skipNext, run: () => { if (pl.canGoNext) pl.next(); } },
                { label: Tr.t("Show the player"), icon: Icons.application, run: () => { if (pl.canRaise) pl.raise(); else Apps.run(Prefs.music); } }];
        } else if (kind === "status") items = [
            { label: Tr.t("Wi-Fi & network settings"), icon: Icons.wifi, run: () => bar.settings("network") },
            { label: Tr.t("Sound settings"), icon: Icons.volumeHigh, run: () => bar.settings("sound") },
            { label: Tr.t("Bluetooth settings"), icon: Icons.bluetooth, run: () => bar.settings("bluetooth") },
            { label: Tr.t("Power & battery settings"), icon: Icons.battery, run: () => bar.settings("power") }];
        if (items.length) Shell.menu(items, bar.screen ? bar.screen.name : "", x);
    }

    WlrLayershell.namespace: "tuxos-bar"
    WlrLayershell.layer: WlrLayer.Top
    // blur exactly behind the rounded bar (when the compositor supports the
    // background-effect protocol; Hyprland's layer rule covers the rest)
    BackgroundEffect.blurRegion: Region { item: glass; radius: Theme.barRadius }

    // slides in from above after the screen unlocks (SPEC password feedback)
    Item {
        id: slide
        width: parent.width
        height: parent.height
        y: Power.locked || bar.hidden ? -(Theme.barTop + Theme.barHeight + 4) : 0
        Behavior on y { enabled: !Theme.reduceMotion; Spring {} }

        Glass {
            id: glass
            anchors.fill: parent
        }

        Row {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 4
            TuxButton { id: tuxBtn; screenName: bar.screen ? bar.screen.name : ""
                        TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: bar.menuFor("tux", tuxBtn) } TapHandler { acceptedButtons: Qt.RightButton; onTapped: bar.menuFor("tux", tuxBtn) } }
            Workspaces { screenName: bar.screen ? bar.screen.name : "" }
        }

        // clock in the middle; a live activity joins it and the pair stays centred
        Row {
            anchors.centerIn: parent
            spacing: 8
            Clock { id: clockItem; screenName: bar.screen ? bar.screen.name : ""
                    TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: bar.menuFor("clock", clockItem) } TapHandler { acceptedButtons: Qt.RightButton; onTapped: bar.menuFor("clock", clockItem) } }
            LiveChip { id: liveItem; screenName: bar.screen ? bar.screen.name : ""
                       TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: bar.menuFor("live", liveItem) } TapHandler { acceptedButtons: Qt.RightButton; onTapped: bar.menuFor("live", liveItem) } }
        }

        Status {
            id: statusItem
            screenName: bar.screen ? bar.screen.name : ""
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: bar.menuFor("status", statusItem) } TapHandler { acceptedButtons: Qt.RightButton; onTapped: bar.menuFor("status", statusItem) }
        }
    }
}
