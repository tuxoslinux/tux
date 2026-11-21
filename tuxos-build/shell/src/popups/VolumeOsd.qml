import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme
import qs.components

// Volume flyout content (SPEC): device symbol, name and kind, level, bar,
// "Muted". Shown by Popups whenever PipeWire reports a volume / mute change
// on the default output, whoever made it (keys, a headset's wheel, apps).
Item {
    id: osd
    implicitWidth: 360
    implicitHeight: 100

    property var sink: null
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string formFactor: sink && sink.properties ? (sink.properties["device.form-factor"] || "") : ""

    function kind() {
        switch (formFactor) {
        case "headset": return "Headset";
        case "headphone": return "Headphones";
        case "hands-free": return "Headset";
        case "tv": return "TV";
        case "hdmi": return "Display";
        default: return "Speakers";
        }
    }
    function symbol() {
        if (formFactor === "headset" || formFactor === "headphone" || formFactor === "hands-free") return 0xf02cb;
        if (muted || volume <= 0.001) return 0xf075f;
        return 0xf057e;
    }

    Row {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; topMargin: 16 }
        spacing: 12
        Rectangle {
            width: 42; height: 42; radius: 13
            color: osd.muted ? Theme.ink(0.10) : Theme.accent
            Sym { anchors.centerIn: parent; code: osd.symbol(); font.pixelSize: Theme.px(20); color: osd.muted ? Theme.muted : Theme.accentInk }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: head.width - 42 - 14 - 70 - 14
            Text {
                width: parent.width
                text: osd.sink ? (osd.sink.description || osd.sink.nickname || osd.sink.name) : ""
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text
            }
            Text {
                text: osd.kind() + " · volume"
                font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted
            }
        }
        Text {
            width: 70
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: osd.muted ? "Muted" : Math.round(osd.volume * 100) + "%"
            font.family: Theme.font; font.pixelSize: osd.muted ? 16 : 22; font.weight: Font.Bold
            color: osd.muted ? Theme.muted : Theme.text
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20; bottomMargin: 20 }
        height: 8; radius: 4
        color: Theme.ink(0.10)
        Rectangle {
            width: parent.width * Math.min(1, osd.volume)
            height: parent.height; radius: 4
            color: osd.muted ? Theme.dim : Theme.accent
            Behavior on width { enabled: !Theme.reduceMotion; Spring {} }
        }
    }
}
