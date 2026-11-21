import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.theme
import qs.components

// Bluetooth: on / off, search, paired and nearby devices (connect, pair,
// forget) with their batteries.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Bluetooth"); description: Tr.t("Headphones, controllers, mice and phones.") }
    readonly property var adapter: Bluetooth.defaultAdapter
    Text { visible: page.adapter === null; text: Tr.t("This PC has no Bluetooth."); font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.muted }
    SettingCard {
        visible: page.adapter !== null
        SettingRow { title: Tr.t("Bluetooth"); description: page.adapter && page.adapter.enabled ? "On · visible as \"" + page.adapter.name + "\"" : "Off"; Toggle { checked: page.adapter !== null && page.adapter.enabled; onToggled: v => page.adapter.enabled = v } }
        SettingRow { title: Tr.t("Search for devices"); description: page.adapter && page.adapter.discovering ? "Searching..." : "Put the device in pairing mode first"; last: true
            Toggle { checked: page.adapter !== null && page.adapter.discovering; onToggled: v => page.adapter.discovering = v } }
    }
    SettingCard {
        header: Tr.t("Devices")
        visible: page.adapter !== null && page.adapter.enabled
        Repeater {
            model: page.adapter ? page.adapter.devices.values.slice().sort((a, b) => (b.paired - a.paired) || (b.connected - a.connected)) : []
            delegate: SettingRow {
                required property var modelData
                title: modelData.name || modelData.address
                description: (modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Nearby") + (modelData.batteryAvailable ? " · battery " + Math.round(modelData.battery * 100) + " %" : "")
                Row {
                    spacing: 8
                    Btn { visible: modelData.paired; text: Tr.t("Forget"); onClicked: modelData.forget() }
                    Btn {
                        text: modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"
                        primary: !modelData.connected
                        onClicked: modelData.connected ? modelData.disconnect() : (modelData.paired ? modelData.connect() : modelData.pair())
                    }
                }
            }
        }
    }

    // ---- phone link (KDE Connect over Wi-Fi): pair the phone here; the
    // notification centre then sends files, the clipboard and rings it
    property bool hasKdc: false
    property var phones: []                 // [{ id, name, paired, reachable }]
    Cmd {
        id: phoneCmd
        command: ["sh", "-c", "command -v kdeconnect-cli >/dev/null || exit 3; kdeconnect-cli --refresh >/dev/null 2>&1; sleep 2; kdeconnect-cli -l 2>/dev/null"]
        Component.onCompleted: run()
        onDone: (out, code) => {
            page.hasKdc = code !== 3;
            // "- Pixel 8: 1a2b3c... (paired and reachable)"
            page.phones = out.split("\n").map(l => /^- (.*): ([0-9a-zA-Z_]+) \((.*)\)/.exec(l.trim())).filter(m => m)
                .map(m => ({ name: m[1], id: m[2], paired: /paired/.test(m[3]) && !/not paired/.test(m[3]), reachable: /reachable/.test(m[3]) && !/not reachable/.test(m[3]) }));
        }
    }
    Timer { id: phoneLater; interval: 3000; onTriggered: phoneCmd.run() }
    SettingCard {
        header: Tr.t("Phone link")
        SettingRow {
            title: Tr.t("Your phone, linked over Wi-Fi")
            description: page.hasKdc ? Tr.t("Install KDE Connect on the phone (Android: Play Store / F-Droid; iPhone: App Store), same Wi-Fi, then pair it here") : Tr.t("Needs KDE Connect (from the TuxOS repositories)")
            last: page.hasKdc && page.phones.length === 0
            Row { spacing: 8
                Btn { visible: !page.hasKdc; text: Tr.t("Install"); primary: true; onClicked: Quickshell.execDetached(["sh", "-c", "pkexec tuxos-pkg install kdeconnect && (kdeconnectd >/dev/null 2>&1 &) && notify-send 'KDE Connect is installed' 'Pair your phone in Settings > Bluetooth'"]) }
                Btn { visible: page.hasKdc; text: Tr.t("Look for phones"); onClicked: phoneCmd.run() }
            }
        }
        Repeater {
            model: page.phones
            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.name
                description: modelData.paired ? (modelData.reachable ? Tr.t("Linked · files, clipboard and ring in the notification centre") : Tr.t("Paired · not on this Wi-Fi now")) : Tr.t("Not paired")
                last: index === page.phones.length - 1
                Btn { text: modelData.paired ? Tr.t("Unpair") : Tr.t("Pair"); primary: !modelData.paired
                      onClicked: { Quickshell.execDetached(["kdeconnect-cli", "-d", modelData.id, modelData.paired ? "--unpair" : "--pair"]); phoneLater.restart(); } }
            }
        }
    }
}
