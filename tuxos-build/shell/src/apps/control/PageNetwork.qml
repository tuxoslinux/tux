import QtQuick
import Quickshell
import Quickshell.Networking
import QtQuick.Dialogs
import qs.theme
import qs.components
import qs.services

// Wi-Fi & network: Wi-Fi on / off and networks, wired, VPN (import
// WireGuard / OpenVPN files), private DNS with ad blocking.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Wi-Fi & network"); description: Tr.t("Wi-Fi, cable, VPN and private DNS.") }
    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired) || null
    Component.onCompleted: NetExtras.refresh()

    SettingCard {
        header: Tr.t("Wi-Fi")
        visible: page.wifi !== null
        SettingRow { title: Tr.t("Wi-Fi"); description: Networking.wifiEnabled ? "On" : "Off"; last: !Networking.wifiEnabled; Toggle { checked: Networking.wifiEnabled; onToggled: v => Networking.wifiEnabled = v } }
        Repeater {
            model: page.wifi && Networking.wifiEnabled ? page.wifi.networks.values.slice().sort((a, b) => b.signalStrength - a.signalStrength).slice(0, 12) : []
            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.name
                description: (modelData.connected ? "Connected · " : modelData.known ? "Saved · " : "") + Math.round(modelData.signalStrength * 100) + " % signal"
                Row {
                    spacing: 8
                    Btn { visible: modelData.known && !modelData.connected; text: Tr.t("Forget"); onClicked: modelData.forget() }
                    Btn { text: modelData.connected ? "Disconnect" : "Connect"; primary: !modelData.connected; onClicked: modelData.connected ? modelData.disconnect() : modelData.connect() }
                }
            }
        }
    }
    SettingCard {
        header: Tr.t("Cable")
        visible: page.wired !== null
        SettingRow {
            title: Tr.t("Ethernet"); last: true
            description: page.wired && page.wired.connected ? "Connected" + (page.wired.address ? " · " + page.wired.address : "") : "Cable unplugged"
        }
    }
    SettingCard {
        header: Tr.t("Privacy")
        SettingRow {
            title: Tr.t("Private DNS with ad blocking"); description: Tr.t("AdGuard DNS instead of the network's: blocks ads and trackers for every app")
            Toggle { checked: NetExtras.privateDns; onToggled: v => NetExtras.togglePrivateDns() }
        }
        SettingRow {
            title: Tr.t("Connection check"); description: Tr.t("Asks NetworkManager whether the internet is reachable (no-internet symbol in the bar)"); last: true
            Toggle { checked: Networking.connectivityCheckEnabled; onToggled: v => Networking.connectivityCheckEnabled = v }
        }
    }
    SettingCard {
        header: Tr.t("VPN")
        Repeater {
            model: NetExtras.vpns
            delegate: SettingRow {
                required property var modelData
                title: modelData.name; description: modelData.active ? "Connected" : "Off"
                Toggle { checked: modelData.active; onToggled: v => NetExtras.toggleVpn(modelData) }
            }
        }
        SettingRow {
            title: NetExtras.vpns.length ? "Add another VPN" : "No VPN yet"; description: Tr.t("Import a WireGuard (.conf) or OpenVPN (.ovpn) file from your VPN provider"); last: true
            Btn { text: Tr.t("Import file"); icon: 0xf0415; onClicked: picker.open() }
        }
    }
    FileDialog {
        id: picker
        title: Tr.t("Import a VPN")
        nameFilters: ["VPN files (*.conf *.ovpn)"]
        onAccepted: {
            const f = selectedFile.toString().replace("file://", "");
            const type = f.endsWith(".ovpn") ? "openvpn" : "wireguard";
            Quickshell.execDetached(["sh", "-c", "nmcli connection import type \"$1\" file \"$2\" && notify-send 'VPN added' \"$(basename \"$2\")\" || notify-send 'Could not add the VPN' \"$2\"", "sh", type, decodeURIComponent(f)]);
            refresh.restart();
        }
    }
    Timer { id: refresh; interval: 2500; onTriggered: NetExtras.refresh() }
}
