import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme
import qs.components
import qs.services

// Status droplet content (SPEC): battery, network (Wi-Fi with nearby
// networks, or Ethernet), Bluetooth, volume, brightness, power profile.
// Every part hides when the PC lacks that hardware.
Item {
    id: st
    implicitWidth: 400
    implicitHeight: col.implicitHeight + 48

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [st.sink] }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery && battery.isPresent
    readonly property var devices: Networking.devices.values
    readonly property var wifi: {
        for (let i = 0; i < devices.length; i++) if (devices[i].type === DeviceType.Wifi) return devices[i];
        return null;
    }
    readonly property var wired: {
        for (let i = 0; i < devices.length; i++) if (devices[i].type === DeviceType.Wired) return devices[i];
        return null;
    }
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var source: Pipewire.defaultAudioSource
    // apps playing sound right now
    // (by class: n.audio only arrives once tracked, and only listed nodes are tracked)
    readonly property var streams: (Pipewire.nodes.values || []).filter(n => n.isStream && n.isSink && !/^playback\.tuxos-/.test(n.name || ""))
    PwObjectTracker { objects: [st.source].concat(st.streams) }
    property bool noiseOn: false
    property int kbdLight: -1         // -1: no keyboard backlight
    Process {
        running: Shell.panel === "status"
        command: ["sh", "-c", "brightnessctl -m -d '*::kbd_backlight' info 2>/dev/null | cut -d, -f4 | tr -d %; pgrep -f 'tuxos-noise' >/dev/null && echo NOISE"]
        stdout: StdioCollector { onStreamFinished: { const l = text.split("\n"); st.kbdLight = l[0] !== "" && !isNaN(parseInt(l[0])) ? parseInt(l[0]) : -1; st.noiseOn = text.indexOf("NOISE") !== -1; } }
    }
    Connections { target: Shell; function onPanelChanged() { if (Shell.panel === "status") NetExtras.refresh(); } }

    component Card: Rectangle {
        width: parent.width
        radius: 20
        color: Theme.ink(0.04)
        border.width: 1
        border.color: Theme.glassLine
    }
    component Label: Text {
        font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text
        elide: Text.ElideRight
    }
    component Small: Text {
        font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted
        elide: Text.ElideRight
    }

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
        spacing: 12

        // ---- battery (laptops only)
        Card {
            visible: st.hasBattery
            height: 84
            Row {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                spacing: 16
                Rectangle {
                    width: 64; height: 30; radius: 8; color: "transparent"
                    border.width: 2; border.color: Theme.ink(0.6)
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        x: 4; y: 4; height: parent.height - 8; radius: 4
                        width: (parent.width - 8) * (st.hasBattery ? st.battery.percentage : 0)
                        color: Theme.accent
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: Math.round((st.hasBattery ? st.battery.percentage : 0) * 100) + "%"; font.family: Theme.font; font.pixelSize: Theme.px(28); font.weight: Font.Bold; color: Theme.text }
                    Small {
                        text: {
                            if (!st.hasBattery) return "";
                            const s = st.battery.state === UPowerDeviceState.Charging ? st.battery.timeToFull : st.battery.timeToEmpty;
                            const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
                            const t = s > 0 ? (h > 0 ? h + " h " : "") + m + " min" : "";
                            return st.battery.state === UPowerDeviceState.Charging ? "Charging" + (t ? " · " + t + " to full" : "") : (t ? t + " left" : "On battery");
                        }
                    }
                }
            }
        }

        // ---- network + Bluetooth tiles
        Row {
            width: parent.width
            spacing: 12
            readonly property int tiles: (st.wifi !== null || st.wired !== null ? 1 : 0) + (st.adapter !== null ? 1 : 0)

            Rectangle {
                id: netTile
                visible: st.wifi !== null || st.wired !== null
                width: parent.tiles > 1 ? (parent.width - 12) / 2 : parent.width
                height: 96
                radius: 20
                readonly property bool on: st.wifi !== null ? Networking.wifiEnabled : (st.wired !== null && st.wired.connected)
                color: on ? Qt.rgba(143 / 255, 184 / 255, 1, 0.14) : Theme.ink(0.04)
                border.width: 1
                border.color: on ? Theme.accentLine : Theme.glassLine
                Sym { x: 16; y: 16; code: st.wifi !== null ? 0xf05a9 : 0xf0200; font.pixelSize: Theme.px(20); color: netTile.on ? Theme.accent : Theme.muted }
                Toggle {
                    visible: st.wifi !== null
                    x: parent.width - width - 16; y: 16
                    checked: Networking.wifiEnabled
                    onToggled: v => Networking.wifiEnabled = v
                }
                Column {
                    x: 16; y: 50; width: parent.width - 36
                    Label { width: parent.width; text: st.wifi !== null ? "Wi-Fi" : "Ethernet"; font.weight: Font.DemiBold }
                    Small {
                        width: parent.width
                        text: {
                            if (st.wifi !== null) {
                                const nets = st.wifi.networks.values;
                                for (let i = 0; i < nets.length; i++) if (nets[i].connected) return nets[i].name;
                                return Networking.wifiEnabled ? "Not connected" : "Off";
                            }
                            return st.wired.connected ? "Connected" + (st.wired.linkSpeed > 0 ? " · " + (st.wired.linkSpeed >= 1000 ? st.wired.linkSpeed / 1000 + " Gbit/s" : st.wired.linkSpeed + " Mbit/s") : "") : "Cable unplugged";
                        }
                    }
                }
            }

            Rectangle {
                id: btTile
                visible: st.adapter !== null
                width: parent.tiles > 1 ? (parent.width - 12) / 2 : parent.width
                height: 96
                radius: 20
                readonly property bool on: st.adapter !== null && st.adapter.enabled
                color: on ? Qt.rgba(143 / 255, 184 / 255, 1, 0.14) : Theme.ink(0.04)
                border.width: 1
                border.color: on ? Theme.accentLine : Theme.glassLine
                Sym { x: 16; y: 16; code: 0xf00af; font.pixelSize: Theme.px(20); color: btTile.on ? Theme.accent : Theme.muted }
                Toggle {
                    x: parent.width - width - 16; y: 16
                    checked: btTile.on
                    onToggled: v => { if (st.adapter) st.adapter.enabled = v; }
                }
                Column {
                    x: 16; y: 50; width: parent.width - 36
                    Label { width: parent.width; text: Tr.t("Bluetooth"); font.weight: Font.DemiBold }
                    Small {
                        width: parent.width
                        text: {
                            if (!btTile.on) return "Off";
                            const d = st.adapter.devices.values.filter(x => x.connected);
                            return d.length ? d[0].name + (d[0].batteryAvailable ? " · " + Math.round(d[0].battery * 100) + "%" : "") : "No devices";
                        }
                    }
                }
            }
        }

        // ---- nearby Wi-Fi networks
        Card {
            visible: st.wifi !== null && Networking.wifiEnabled && netList.count > 0
            height: netCol.implicitHeight + 16
            Column {
                id: netCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                Repeater {
                    id: netList
                    model: st.wifi !== null ? st.wifi.networks.values.slice().sort((a, b) => b.signalStrength - a.signalStrength).slice(0, 4) : []
                    delegate: Rectangle {
                        required property var modelData
                        width: netCol.width; height: 40; radius: 12
                        color: modelData.connected ? Theme.ink(0.05) : (rowHover.hovered ? Theme.fillHover : "transparent")
                        Sym { x: 12; anchors.verticalCenter: parent.verticalCenter; code: 0xf05a9; font.pixelSize: Theme.px(15); color: parent.modelData.connected ? Theme.accent : Theme.muted }
                        Label { x: 44; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.name; width: parent.width - 150 }
                        Small { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: parent.modelData.connected ? "Connected" : ""; color: Theme.accent }
                        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                const n = parent.modelData;
                                if (n.connected) return;
                                // a secured network we do not know yet: ask for its password
                                if (!n.known && n.security !== undefined && n.security !== WifiSecurityType.Open) {
                                    const p = Shell.anchorX;
                                    Shell.panelData = n;
                                    Shell.open("wifi", Shell.screenName, p, Shell.anchorWidth);
                                } else n.connect();
                            }
                        }
                    }
                }
            }
        }

        // ---- volume
        Item {
            width: parent.width; height: 44
            visible: st.sink !== null
            Sym { id: volSym; anchors.verticalCenter: parent.verticalCenter; code: st.sink && st.sink.audio && st.sink.audio.muted ? 0xf075f : 0xf057e; width: 24 }
            Slider {
                anchors { left: volSym.right; leftMargin: 12; right: volPct.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                value: st.sink && st.sink.audio ? st.sink.audio.volume : 0
                muted: st.sink && st.sink.audio ? st.sink.audio.muted : false
                onMoved: v => { if (st.sink && st.sink.audio) { st.sink.audio.muted = false; st.sink.audio.volume = v; } }
            }
            Small { id: volPct; anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 40; horizontalAlignment: Text.AlignRight; text: Math.round((st.sink && st.sink.audio ? st.sink.audio.volume : 0) * 100) + "%" }
            TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: { if (st.sink && st.sink.audio) st.sink.audio.muted = !st.sink.audio.muted; } }
        }

        // ---- per-app volume (any app playing sound)
        Column {
            width: parent.width
            spacing: 4
            visible: st.streams.length > 0
            Repeater {
                model: st.streams
                delegate: Item {
                    required property var modelData
                    width: parent.width; height: 34
                    Small { id: an; width: 96; anchors.verticalCenter: parent.verticalCenter; text: (modelData.properties && modelData.properties["application.name"]) || modelData.description || modelData.name }
                    Slider {
                        anchors { left: an.right; leftMargin: 8; right: ap.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        value: modelData.audio ? modelData.audio.volume : 0
                        muted: modelData.audio ? modelData.audio.muted : false
                        onMoved: v => { if (modelData.audio) modelData.audio.volume = v; }
                    }
                    Small { id: ap; anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 40; horizontalAlignment: Text.AlignRight; text: Math.round((modelData.audio ? modelData.audio.volume : 0) * 100) + "%" }
                }
            }
        }

        // ---- microphone: device, live level meter, noise suppression
        Item {
            width: parent.width; height: 40
            visible: st.source !== null
            Sym { id: micSym; anchors.verticalCenter: parent.verticalCenter; code: st.source && st.source.audio && st.source.audio.muted ? Icons.microphoneOff : Icons.microphone; width: 24
                TapHandler { onTapped: if (st.source && st.source.audio) st.source.audio.muted = !st.source.audio.muted } }
            Rectangle {
                id: meter
                anchors { left: micSym.right; leftMargin: 12; right: micName.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                height: 6; radius: 3
                color: Theme.ink(0.10)
                Rectangle { width: parent.width * Math.min(1, peak.peak * 1.6); height: 6; radius: 3; color: Theme.accent; Behavior on width { NumberAnimation { duration: 80 } } }
            }
            PwNodePeakMonitor { id: peak; node: st.source; enabled: Shell.panel === "status" && st.source !== null }
            Small { id: micName; anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 120; horizontalAlignment: Text.AlignRight; text: st.source ? (st.source.description || "Microphone") : "" }
        }

        // ---- quick toggles: VPN, private DNS, noise suppression, keyboard light, Wi-Fi QR
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: NetExtras.vpns
                delegate: Chip { required property var modelData; label: modelData.name; icon: Icons.shieldLockOutline; on: modelData.active; onHit: NetExtras.toggleVpn(modelData) }
            }
            Chip { label: Tr.t("Private DNS"); icon: Icons.shield; on: NetExtras.privateDns; visible: NetExtras.activeConn !== ""; onHit: NetExtras.togglePrivateDns() }
            Chip { label: Tr.t("Noise filter"); icon: Icons.microphone; on: st.noiseOn; visible: st.source !== null; onHit: { st.noiseOn = !st.noiseOn; Quickshell.execDetached(["tuxos-audio", "noise", st.noiseOn ? "on" : "off"]); } }
            Chip { label: Tr.t("Keyboard light"); icon: Icons.keyboard; on: st.kbdLight > 0; visible: st.kbdLight >= 0
                   onHit: { st.kbdLight = st.kbdLight > 0 ? 0 : 100; Quickshell.execDetached(["brightnessctl", "-d", "*::kbd_backlight", "set", st.kbdLight + "%"]); } }
            Chip { label: Tr.t("Share Wi-Fi"); icon: Icons.qrcode; visible: st.wifi !== null && st.wifi.connected; onHit: { Shell.close(); Shell.showOverlay("wifiqr"); } }
        }

        // ---- brightness (only with a backlight)
        Item {
            width: parent.width; height: 44
            visible: Brightness.available
            Sym { id: briSym; anchors.verticalCenter: parent.verticalCenter; code: 0xf00e0; width: 24 }
            Slider {
                anchors { left: briSym.right; leftMargin: 12; right: briPct.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                value: Brightness.value
                onMoved: v => Brightness.set(v)
            }
            Small { id: briPct; anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 40; horizontalAlignment: Text.AlignRight; text: Math.round(Brightness.value * 100) + "%" }
        }

        // ---- power profile
        Segmented {
            width: parent.width
            options: PowerProfiles.hasPerformanceProfile ? ["Power saver", "Balanced", "Performance"] : ["Power saver", "Balanced"]
            current: PowerProfiles.profile === PowerProfile.PowerSaver ? 0 : (PowerProfiles.profile === PowerProfile.Performance ? 2 : 1)
            onPicked: i => PowerProfiles.profile = [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance][i]
        }
    }
}
