import QtQuick
import qs.theme
import qs.components
import qs.services

// Generic flyout content (brightness, Caps Lock / Num Lock, microphone
// mute): symbol, title, what it is, a level in % and a bar (when there is a
// level) or an on / off word.
Item {
    id: f
    implicitWidth: 360
    implicitHeight: Shell.flyoutData && Shell.flyoutData.value >= 0 ? 100 : 82
    readonly property var d: Shell.flyoutData || ({})

    Row {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; topMargin: 16 }
        spacing: 12
        Rectangle {
            width: 42; height: 42; radius: 13
            color: f.d.off ? Theme.ink(0.10) : Theme.accent
            Sym { anchors.centerIn: parent; code: f.d.icon || 0; font.pixelSize: Theme.px(20); color: f.d.off ? Theme.muted : Theme.accentInk }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: head.width - 42 - 14 - 90 - 14
            Text { width: parent.width; text: f.d.title || ""; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
            Text { width: parent.width; text: f.d.sub || ""; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        }
        Text {
            width: 90
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: f.d.text !== undefined ? f.d.text : Math.round((f.d.value || 0) * 100) + "%"
            font.family: Theme.font; font.pixelSize: f.d.text !== undefined ? 16 : 22; font.weight: Font.Bold
            color: f.d.off ? Theme.muted : Theme.text
        }
    }
    Rectangle {
        visible: (f.d.value !== undefined ? f.d.value : -1) >= 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20; bottomMargin: 20 }
        height: 8; radius: 4
        color: Theme.ink(0.10)
        Rectangle {
            width: parent.width * Math.min(1, Math.max(0, f.d.value || 0))
            height: parent.height; radius: 4
            color: Theme.accent
            Behavior on width { enabled: !Theme.reduceMotion; Spring {} }
        }
    }
}
