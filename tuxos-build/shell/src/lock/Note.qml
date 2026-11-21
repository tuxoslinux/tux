import QtQuick
import qs.theme
import qs.components
import qs.services

// The motivational note on the lock screen (lock-v4): 340 x 220, lightning
// symbol, a big bold message, "Welcome back, <name>"; a new message each time
// the screen locks.
Rectangle {
    id: note
    width: 340; height: 220
    radius: 22
    color: Theme.ink(0.045)
    border.width: 1; border.color: Theme.glassLine

    readonly property string name: Prefs.firstName
    readonly property var messages: {
        const h = new Date().getHours();
        const part = h < 5 ? "Late night" : h < 12 ? "Good morning" : h < 18 ? "Good day" : "Good evening";
        return [
            "Lock in!\nYou got this.",
            `${part},\n${name}.`,
            "Back at it.\nLet's go.",
            "Deep breath.\nYou've got this.",
            "Small steps.\nBig wins.",
            `Stay curious,\n${name}.`,
            "Ship it.\nThen rest.",
            "Focus mode:\nengaged.",
            "Make today\ncount.",
            "One more\nround. Win it."
        ];
    }
    property int pick: 0
    function shuffle() {
        let n = Math.floor(Math.random() * messages.length);
        if (n === pick) n = (n + 1) % messages.length;
        pick = n;
    }

    Rectangle {
        x: 24; y: 24
        width: 46; height: 46; radius: 12
        color: Qt.rgba(143 / 255, 184 / 255, 1, 0.14)
        border.width: 1; border.color: Theme.accentLine
        Sym { anchors.centerIn: parent; code: Icons.lightningBolt; color: Theme.accent; font.pixelSize: Theme.px(22) }
    }
    Column {
        anchors { left: parent.left; leftMargin: 24; right: parent.right; rightMargin: 24; bottom: parent.bottom; bottomMargin: 24 }
        spacing: 8
        Text {
            width: parent.width
            text: note.messages[note.pick]
            font.family: Theme.font; font.pixelSize: Theme.px(28); font.weight: Font.Bold
            lineHeight: 1.05
            color: Theme.text
            wrapMode: Text.Wrap
        }
        Text {
            text: `Welcome back, ${note.name}`
            font.family: Theme.font; font.pixelSize: Theme.px(15)
            color: Theme.muted
        }
    }
}
