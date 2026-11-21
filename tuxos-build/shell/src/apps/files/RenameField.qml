import QtQuick
import qs.theme

// Inline rename (F2 / menu): Enter renames, Esc or clicking away cancels.
Rectangle {
    id: rf
    property var view
    property string path
    height: 30; radius: 8
    color: Theme.ink(0.06); border.width: 1; border.color: Theme.accentLine
    onVisibleChanged: if (visible) {
        const n = path.substring(path.lastIndexOf("/") + 1);
        input.text = n;
        input.forceActiveFocus();
        const dot = n.lastIndexOf(".");
        input.select(0, dot > 0 ? dot : n.length);
    }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text
        selectByMouse: true
        clip: true
        // Enter renames and stops here (it must not also open the item)
        Keys.onReturnPressed: event => { event.accepted = true; rf.view.rename(rf.path, text); }
        Keys.onEnterPressed: event => { event.accepted = true; rf.view.rename(rf.path, text); }
        Keys.onEscapePressed: event => { event.accepted = true; rf.view.renaming = ""; }
        onActiveFocusChanged: if (!activeFocus && rf.visible) rf.view.renaming = ""
    }
}
