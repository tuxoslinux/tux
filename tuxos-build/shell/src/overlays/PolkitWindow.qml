import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.theme
import qs.components
import qs.services
import qs.lock

// Window of the administrator password prompt (polkit) in the shell's style (mockup
// shell2/06-polkit): who asks and for what, the action, the password field
// with the same feedback as the lock screen, Esc cancels. The shell is the
// session's polkit agent (no separate agent process).
OverlayWindow {
    id: ov
    name: "polkit"
    closeOnOutside: false
    property var agent: null
    readonly property var flow: agent ? agent.flow : null
    readonly property bool asking: flow !== null && !flow.isCompleted
    onAskingChanged: if (!asking) Shell.hideOverlay("polkit")
    onOpened: { pwd.reset(); pwd.focusField(); }
    onClosing: if (ov.asking) flow.cancelAuthenticationRequest()

    Connections {
        target: ov.flow
        function onAuthenticationFailed() { pwd.wrong(); }
        function onAuthenticationSucceeded() { pwd.success(); }
    }

    Card {
        anchors.centerIn: parent
        width: 440
        height: col.implicitHeight + 48
        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
            spacing: 12
            Row {
                spacing: 12
                Rectangle {
                    width: 46; height: 46; radius: 13
                    color: Theme.accent
                    Sym { anchors.centerIn: parent; code: Icons.shieldLockOutline; color: Theme.accentInk; font.pixelSize: Theme.px(23) }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text { text: Tr.t("Administrator password"); font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text }
                    Text {
                        width: 320
                        text: ov.flow ? ov.flow.message : ""
                        wrapMode: Text.Wrap
                        font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 36; radius: 11
                color: Theme.fill; border.width: 1; border.color: Theme.glassLine
                Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: Tr.t("Action"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                Text {
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: parent.width - 90; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                    text: ov.flow ? ov.flow.actionId : ""
                    font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.text
                }
            }
            PasswordBar {
                id: pwd
                width: parent.width
                placeholder: ov.flow && ov.flow.inputPrompt ? ov.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                message: ov.flow && ov.flow.supplementaryMessage ? ov.flow.supplementaryMessage : ""
                onSubmitted: pw => { if (ov.flow) ov.flow.submit(pw); }
                onUnlocked: Shell.hideOverlay("polkit")
            }
            Item {
                width: parent.width; height: 16
                Text {
                    text: Tr.t("User: ") + Quickshell.env("USER")
                    font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted
                }
                Text { anchors.right: parent.right; text: Tr.t("Esc to cancel"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.dim }
            }
        }
    }
}
