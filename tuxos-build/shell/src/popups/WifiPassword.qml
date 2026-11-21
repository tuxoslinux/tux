import QtQuick
import Quickshell
import Quickshell.Networking
import qs.theme
import qs.components
import qs.services

// Wi-Fi password droplet (mockup shell2/07-wifipass): which network and its
// security, the password (eye shows it), "Connect automatically", Cancel /
// Connect. Wrong password: the field shakes like the lock screen's.
Column {
    id: wp
    readonly property var net: Shell.panelData
    property bool show: false
    property bool busy: false
    padding: 20
    spacing: 12
    function focus() { field.text = ""; busy = false; field.forceActiveFocus(); }

    Connections {
        target: wp.net
        function onConnectionFailed() { wp.busy = false; shake.restart(); field.text = ""; err.visible = true; }
        function onConnectedChanged() {
            if (!wp.net || !wp.net.connected) return;
            wp.busy = false;
            if (!auto.checked) Quickshell.execDetached(["nmcli", "connection", "modify", wp.net.name, "connection.autoconnect", "no"]);
            Shell.close();
        }
    }

    Row {
        spacing: 12
        Rectangle {
            width: 40; height: 40; radius: 12; color: Theme.accent
            Sym { anchors.centerIn: parent; code: Icons.wifi; color: Theme.accentInk; font.pixelSize: Theme.px(19) }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: `Connect to "${wp.net ? wp.net.name : ""}"`; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
            Text {
                text: wp.net ? (wp.net.signalStrength > 0.66 ? "Strong signal" : wp.net.signalStrength > 0.33 ? "Good signal" : "Weak signal") + " · secured" : ""
                font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted
            }
        }
    }
    Text { text: Tr.t("Password"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
    Rectangle {
        id: box
        width: wp.width - 40; height: 44; radius: 13
        color: Theme.ink(0.05)
        border.width: 1; border.color: err.visible ? Theme.danger : (field.activeFocus ? Theme.accentLine : Theme.glassLine)
        transform: Translate { id: sx }
        TextInput {
            id: field
            anchors { left: parent.left; leftMargin: 12; right: eye.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            echoMode: wp.show ? TextInput.Normal : TextInput.Password
            passwordCharacter: "●"
            font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.text
            clip: true
            onTextChanged: err.visible = false
            onAccepted: connectBtn.go()
            Keys.onEscapePressed: Shell.close()
        }
        Sym {
            id: eye
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            code: wp.show ? Icons.eyeOff : Icons.eye; font.pixelSize: Theme.px(16); color: Theme.muted
            TapHandler { onTapped: wp.show = !wp.show }
        }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: sx; property: "x"; to: -12; duration: 50 }
            NumberAnimation { target: sx; property: "x"; to: 10; duration: 70 }
            NumberAnimation { target: sx; property: "x"; to: -6; duration: 70 }
            NumberAnimation { target: sx; property: "x"; to: 3; duration: 70 }
            NumberAnimation { target: sx; property: "x"; to: 0; duration: 60 }
        }
    }
    Text { id: err; visible: false; text: Tr.t("Wrong password - try again"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.danger }
    Row {
        spacing: 8
        Toggle { id: auto; checked: true; onToggled: v => checked = v }
        Text { anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Connect automatically"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text }
    }
    Row {
        spacing: 8
        Rectangle {
            width: (wp.width - 50) / 2; height: 40; radius: 12
            color: cH.hovered ? Theme.fillHover : Theme.fill; border.width: 1; border.color: Theme.glassLine
            Text { anchors.centerIn: parent; text: Tr.t("Cancel"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
            HoverHandler { id: cH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Shell.close() }
        }
        Rectangle {
            id: connectBtn
            width: (wp.width - 50) / 2; height: 40; radius: 12
            color: Theme.accent
            opacity: wp.busy ? 0.6 : 1
            function go() {
                if (!wp.net || field.text.length < 8) { shake.restart(); return; }
                wp.busy = true;
                wp.net.connectWithPsk(field.text);
            }
            Text { anchors.centerIn: parent; text: wp.busy ? "Connecting..." : "Connect"; font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.accentInk }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: connectBtn.go() }
        }
    }
}
