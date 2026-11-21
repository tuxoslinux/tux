import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme
import qs.components
import qs.services

// Right side of the bar: game mode, the status group (network, volume,
// battery) and power. Hardware that is missing hides its symbol (SPEC:
// no battery on a desktop PC, no Wi-Fi symbol without Wi-Fi).
Row {
    id: root
    spacing: 4
    property string screenName: ""

    // ---- sound
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    // ---- battery (only real laptop batteries)
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery && battery.isPresent
    readonly property int batteryPct: hasBattery ? Math.round(battery.percentage * (battery.percentage <= 1 ? 100 : 1)) : 0

    // ---- network: Wi-Fi if a Wi-Fi device is connected, else wired
    readonly property var devices: Networking.devices.values
    readonly property var wifi: {
        for (let i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi) return devices[i];
        return null;
    }
    readonly property bool wired: {
        for (let i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wired && devices[i].connected) return true;
        return false;
    }

    // no internet although connected (NetworkManager's connectivity check)
    readonly property bool noInternet: (root.wired || (root.wifiNet !== null)) && Networking.connectivity !== NetworkConnectivity.Full
                                       && Networking.connectivity !== NetworkConnectivity.Unknown
    readonly property var wifiNet: {
        if (!wifi) return null;
        const n = wifi.networks.values;
        for (let i = 0; i < n.length; i++) if (n[i].connected) return n[i];
        return null;
    }
    function netSymbol() {
        if (root.wired) return root.noInternet ? 0xf0319 : 0xf0200;
        if (root.wifiNet === null) return Networking.wifiEnabled ? 0xf092b : 0xf05aa;   // searching / off
        if (root.noInternet) return 0xf16b5;
        const s = root.wifiNet.signalStrength;
        return s > 0.75 ? 0xf0928 : s > 0.5 ? 0xf0925 : s > 0.25 ? 0xf0922 : 0xf091f;
    }
    function volumeSymbol() {
        if (muted || volume <= 0.001) return 0xf075f;   // volume off
        if (volume < 0.34) return 0xf057f;               // low
        if (volume < 0.67) return 0xf0580;               // medium
        return 0xf057e;                                  // high
    }
    function batterySymbol() {
        const p = batteryPct;
        const steps = [0xf008e, 0xf007a, 0xf007b, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0080, 0xf0081, 0xf0082, 0xf0079];
        return steps[Math.min(10, Math.max(0, Math.round(p / 10)))];
    }

    // ---- privacy: orange pill while the mic, a camera or screen sharing is used
    Rectangle {
        visible: Privacy.any
        anchors.verticalCenter: parent.verticalCenter
        height: 26; radius: 13
        width: privRow.implicitWidth + 18
        color: Qt.rgba(1, 0.54, 0.40, privHover.hovered ? 0.30 : 0.20)
        border.width: 1; border.color: Qt.rgba(1, 0.54, 0.40, 0.55)
        Row {
            id: privRow
            anchors.centerIn: parent
            spacing: 4
            Sym { visible: Privacy.mic.length > 0; code: Icons.microphone; font.pixelSize: Theme.px(14); color: Theme.warn }
            Sym { visible: Privacy.camera.length > 0; code: Icons.webcam; font.pixelSize: Theme.px(14); color: Theme.warn }
            Sym { visible: Privacy.screen.length > 0; code: Icons.monitorScreenshot; font.pixelSize: Theme.px(14); color: Theme.warn }
        }
        HoverHandler { id: privHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                const p = parent.mapToItem(null, parent.width / 2, 0);
                Shell.toggle("privacy", root.screenName, Theme.edge + p.x, parent.width);
            }
        }
    }

    // ---- game mode: blue while a game runs; click = Gaming focus on / off
    Sym {
        code: Icons.gamepadVariant
        width: 30; height: Theme.itemHeight
        color: Notifs.gameRunning || Notifs.focus === "gaming" ? Theme.accent : (gameHover.hovered ? Theme.text : Theme.muted)
        Behavior on color { ColorAnimation { duration: Theme.medium } }
        HoverHandler {
            id: gameHover; cursorShape: Qt.PointingHandCursor
            onHoveredChanged: { if (hovered) { const p = parent.mapToItem(null, parent.width / 2, 0); Shell.showTip(Notifs.gameRunning ? Tr.t("Game mode: on (a game is running)") : `${Tr.t("Gaming focus")}  <font color="${Theme.muted}">${Tr.t("click")}</font>`, root.screenName, Theme.edge + p.x); } else Shell.hideTip(); }
        }
        TapHandler { onTapped: Notifs.setFocus(Notifs.focus === "gaming" ? "" : "gaming") }
    }

    Rectangle {
        id: group
        height: Theme.itemHeight
        width: groupRow.implicitWidth + 16
        radius: Theme.itemRadius
        readonly property bool active: Shell.panel === "status" && Shell.screenName === root.screenName
        color: active ? Qt.rgba(143 / 255, 184 / 255, 1, 0.16) : (groupHover.hovered ? Theme.fillHover : Theme.fill)
        border.width: active ? 1 : 0
        border.color: Qt.rgba(143 / 255, 184 / 255, 1, 0.3)
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Row {
            id: groupRow
            anchors.centerIn: parent
            spacing: 4
            Sym {
                visible: root.wifi !== null || root.wired
                code: root.netSymbol()
                color: root.noInternet ? Theme.warn : Theme.text
                width: 28; height: Theme.itemHeight
            }
            // headset battery (HeadsetControl), e.g. G PRO X 2
            Row {
                visible: Devices.headsetPresent
                spacing: 4
                Sym { code: 0xf02cb; width: 24; height: Theme.itemHeight; color: Devices.headsetCharging ? Theme.accent : Theme.text }
                Text {
                    text: Devices.headsetBattery + "%"
                    font.family: Theme.font; font.pixelSize: Theme.px(12); color: Devices.headsetBattery <= 10 ? Theme.warn : Theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 4
                }
            }
            // controllers while connected
            Repeater {
                model: Devices.controllers
                delegate: Row {
                    required property var modelData
                    spacing: 4
                    Sym { code: Icons.gamepadVariant; width: 24; height: Theme.itemHeight; font.pixelSize: Theme.px(14) }
                    Text { text: Devices.pct(modelData) + "%"; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted; anchors.verticalCenter: parent.verticalCenter; rightPadding: 4 }
                }
            }
            // volume: wheel = volume, middle click = mute
            Sym {
                code: root.volumeSymbol(); width: 28; height: Theme.itemHeight
                WheelHandler {
                    acceptedDevices: PointerDevice.AllDevices
                    onWheel: event => {
                        if (!root.sink || !root.sink.audio) return;
                        const v = root.sink.audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05);
                        root.sink.audio.volume = Math.max(0, Math.min(1, v));
                    }
                }
                TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted }
            }
            // battery: wheel = brightness; glows while charging
            Item {
                visible: root.hasBattery
                width: 28; height: Theme.itemHeight
                Rectangle {
                    anchors.centerIn: parent
                    width: 22; height: 22; radius: 11
                    color: Theme.accent
                    opacity: 0
                    SequentialAnimation on opacity {
                        running: Devices.charging
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.28; duration: 1100; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.0; duration: 1100; easing.type: Easing.InOutSine }
                    }
                }
                Sym { anchors.centerIn: parent; code: Devices.charging ? Icons.batteryCharging : root.batterySymbol(); color: Devices.batteryPct <= 15 && !Devices.charging ? Theme.warn : Theme.text }
                WheelHandler {
                    acceptedDevices: PointerDevice.AllDevices
                    onWheel: event => Quickshell.execDetached(["tuxos-brightness", event.angleDelta.y > 0 ? "up" : "down"])
                }
            }
            Text {
                visible: root.hasBattery
                text: root.batteryPct + "%"
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
                font.weight: Font.Medium
                color: Theme.muted
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 4
            }
        }
        function publish() {
            const p = group.mapToItem(null, group.width / 2, 0);
            const m = Object.assign({}, Shell.statusXs);
            m[root.screenName] = Theme.edge + p.x;
            Shell.statusXs = m;
            Shell.statusWidth = group.width;
        }
        onWidthChanged: Qt.callLater(publish)
        onXChanged: Qt.callLater(publish)
        Component.onCompleted: Qt.callLater(publish)
        HoverHandler {
            id: groupHover; cursorShape: Qt.PointingHandCursor
            onHoveredChanged: { if (hovered) { const p = parent.mapToItem(null, parent.width / 2, 0); Shell.showTip(`${Tr.t("Quick settings")}  <font color="${Theme.muted}">Super + A</font>`, root.screenName, Theme.edge + p.x); } else Shell.hideTip(); }
        }
        TapHandler {
            onTapped: {
                const p = group.mapToItem(null, group.width / 2, 0);
                Shell.toggle("status", root.screenName, Theme.edge + p.x, group.width);
            }
        }
    }

    // ---- power: the power menu
    Sym {
        code: 0xf011
        width: 34; height: Theme.itemHeight
        color: powerHover.hovered ? Theme.text : Theme.muted
        HoverHandler {
            id: powerHover; cursorShape: Qt.PointingHandCursor
            onHoveredChanged: { if (hovered) { const p = parent.mapToItem(null, parent.width / 2, 0); Shell.showTip(`${Tr.t("Power")}  <font color="${Theme.muted}">Super + X</font>`, root.screenName, Theme.edge + p.x); } else Shell.hideTip(); }
        }
        TapHandler { onTapped: Shell.showOverlay("power") }
    }
}
