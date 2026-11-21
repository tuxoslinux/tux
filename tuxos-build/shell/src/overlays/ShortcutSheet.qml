import QtQuick
import qs.theme
import qs.components
import qs.services

// Shortcut sheet (Super + /): every TuxOS shortcut on one glass card,
// grouped; type to filter.
OverlayWindow {
    id: ov
    name: "sheet"

    readonly property var groups: [
        ["Apps", [["Super", "App launcher"], ["Super + W", "Terminal"], ["Super + B", "Browser"], ["Super + F", "Files"], ["Super + S", "Settings"],
                  ["Super + M", "Messaging app"], ["Super + V", "Music app"], ["Super + G", "Steam Big Picture"], ["Ctrl + Shift + Esc", "System manager"], ["F12", "Drop-down terminal"]]],
        ["Windows", [["Super + Q", "Close the app"], ["Super + Shift + Q", "Force-quit"], ["Super + Up / Down", "Maximize / restore / minimize"], ["Super + Left / Right", "Snap to a half"],
                     ["Super + Enter", "Full screen"], ["Super + T", "Float / tile"], ["Alt + Tab", "Switch windows"], ["Super + Space / Tab", "Mission Control"],
                     ["Super + Alt + P", "Pin as picture in picture"], ["Super + Z", "Snap layouts"], ["Super + Alt + T", "Window tabs"], ["Super + Alt + ← / →", "Previous / next tab"], ["Super + drag", "Move / resize (right button)"]]],
        ["Desktops", [["Super + 1 ... 9", "Go to a desktop"], ["Super + Shift + 1 ... 9", "Move the window there"], ["Super + Ctrl + Left / Right", "Previous / next desktop"],
                      ["Super + Shift + Left / Right", "Window to the other monitor"]]],
        ["Shell", [["Super + N", "Notifications"], ["Super + A", "Quick settings"], ["Super + D", "Do not disturb"], ["Super + C", "Clipboard history"], ["Super + .", "Emoji"],
                   ["Super + Shift + N", "Quick notes"], ["Super + /", "This sheet"], ["Super + R", "Reload the shell"], ["Super + P", "Displays"]]],
        ["Capture", [["Super + Shift + S", "Screenshot (click: screen, drag: area)"], ["Print", "Whole screen"], ["Super + Shift + R", "Record the screen"],
                     ["Super + Alt + R", "Instant replay"], ["Super + Shift + C", "Colour picker"], ["Super + scroll", "Zoom (Super + Esc resets)"]]],
        ["Session", [["Super + L", "Lock"], ["Super + X", "Power menu"], ["Ctrl + Alt + Del", "Power menu"], ["Super + `", "Restart (10 s countdown)"],
                     ["Super + Shift + G", "Game HUD"], ["Alt + Shift", "Keyboard layout"]]]
    ]
    property string q: ""
    onOpened: { q = ""; keyCatcher.forceActiveFocus(); }
    Item {
        id: keyCatcher
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { ov.close(); event.accepted = true; }
            else if (event.key === Qt.Key_Backspace) { ov.q = ov.q.slice(0, -1); event.accepted = true; }
            else if (event.text && event.text.length === 1 && event.text >= " ") { ov.q += event.text; event.accepted = true; }
        }
    }

    Card {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 1100)
        height: Math.min(parent.height - 80, flow.implicitHeight + 100)
        Text {
            x: 28; y: 20
            text: ov.q ? `Shortcuts matching "${ov.q}"` : "Keyboard shortcuts"
            font.family: Theme.font; font.pixelSize: Theme.px(21); font.weight: Font.DemiBold; color: Theme.text
        }
        Text {
            anchors { right: parent.right; rightMargin: 28; top: parent.top; topMargin: 28 }
            text: Tr.t("Type to filter · Esc closes · change them in TuxOS Control > Keyboard")
            font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted
        }
        Flickable {
            anchors { fill: parent; topMargin: 68; margins: 28 }
            contentHeight: flow.implicitHeight
            clip: true
            Flow {
                id: flow
                width: parent.width
                spacing: 28
                Repeater {
                    model: ov.groups
                    delegate: Column {
                        required property var modelData
                        readonly property var rows: modelData[1].filter(r => !ov.q || (r[0] + " " + r[1] + " " + Tr.t(r[1])).toLowerCase().indexOf(ov.q.toLowerCase()) !== -1)
                        visible: rows.length > 0
                        width: (flow.width - 56) / 3
                        spacing: 8
                        Text { text: Tr.t(modelData[0]).toUpperCase(); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.accent; bottomPadding: 4 }
                        Repeater {
                            model: parent.rows
                            delegate: Item {
                                required property var modelData
                                width: parent.width; height: 24
                                Rectangle {
                                    width: kt.implicitWidth + 14; height: 22; radius: 7
                                    color: Theme.ink(0.07); border.width: 1; border.color: Theme.glassLine
                                    Text { id: kt; anchors.centerIn: parent; text: modelData[0]; font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; color: Theme.text }
                                }
                                Text {
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    width: parent.width - kt.implicitWidth - 30; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                                    text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
