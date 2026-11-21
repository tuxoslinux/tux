import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Share Wi-Fi (status droplet): the current network's name, password and a
// QR code phones can scan (NetworkManager draws the code). Esc closes.
OverlayWindow {
    id: ov
    name: "wifiqr"
    property string out: ""
    onOpened: { out = ""; proc.running = true; keyCatcher.forceActiveFocus(); }
    Item { id: keyCatcher; focus: true; Keys.onEscapePressed: ov.close() }
    Process {
        id: proc
        command: ["nmcli", "device", "wifi", "show-password"]
        stdout: StdioCollector { onStreamFinished: ov.out = text }
    }
    readonly property var lines: out.split("\n")
    readonly property string ssid: (lines.find(l => l.startsWith("SSID:")) || "").replace("SSID:", "").trim()
    readonly property string pass: (lines.find(l => l.startsWith("Password:")) || "").replace("Password:", "").trim()
    readonly property string qr: lines.filter(l => /[█▀▄]/.test(l)).join("\n")

    Card {
        anchors.centerIn: parent
        width: 380; height: col.implicitHeight + 48
        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
            spacing: 12
            Text { text: Tr.t("Share Wi-Fi"); font.family: Theme.font; font.pixelSize: Theme.px(19); font.weight: Font.DemiBold; color: Theme.text }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: qrText.implicitWidth + 24; height: qrText.implicitHeight + 24; radius: 14
                color: "white"
                visible: ov.qr !== ""
                Text { id: qrText; anchors.centerIn: parent; text: ov.qr; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Theme.px(9); lineHeight: 0.8; color: "black" }
            }
            Text { width: parent.width; text: ov.ssid ? `Network: ${ov.ssid}` : (ov.out ? "" : "Reading the network..."); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
            Text { width: parent.width; visible: ov.pass !== ""; text: `Password: ${ov.pass}`; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
            Text { width: parent.width; text: Tr.t("Scan the code with a phone's camera to join."); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim; wrapMode: Text.Wrap }
        }
    }
}
