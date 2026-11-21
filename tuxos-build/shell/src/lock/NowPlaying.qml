import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// "Now playing" on the lock screen (lock-v4): cover, title, artist,
// progress, previous / play-pause / next, and a music visualizer (cava)
// along the bottom while it plays. Hidden when nothing plays.
Rectangle {
    id: np
    readonly property var player: Media.player
    property bool shown: true
    // hidden when nothing plays (also an idle player with no track)
    visible: shown && player !== null && Media.title(player) !== ""
    width: 360; height: 168
    radius: 22
    color: Theme.ink(0.045)
    border.width: 1; border.color: Theme.glassLine
    clip: true

    // visualizer: 28 bars from cava, only while playing on the lock screen
    property var bars: []
    Process {
        id: cava
        running: np.visible && np.player !== null && np.player.isPlaying
        command: ["sh", "-c", "command -v cava >/dev/null || exit 0; printf '[general]\\nbars = 28\\nframerate = 30\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 100\\n' > \"$XDG_RUNTIME_DIR/tuxos-cava.conf\"; exec cava -p \"$XDG_RUNTIME_DIR/tuxos-cava.conf\""]
        stdout: SplitParser {
            onRead: line => np.bars = line.split(";").filter(x => x !== "").map(x => parseInt(x) / 100)
        }
    }
    Row {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
        height: 34
        spacing: 4
        visible: np.bars.length > 0
        Repeater {
            model: np.bars.length
            delegate: Item {
                required property int index
                width: (np.width - 2 - (np.bars.length - 1) * 2) / np.bars.length
                height: 34
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, 34 * (np.bars[index] || 0))
                    radius: 2
                    color: Qt.rgba(143 / 255, 184 / 255, 1, 0.22)
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }
    }

    ClippingRectangle {
        id: cover
        x: 16; y: 16
        width: 76; height: 76; radius: 14
        color: Theme.ink(0.08)
        Image { anchors.fill: parent; source: np.player ? np.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(152, 152); asynchronous: true }
    }
    Column {
        anchors { left: cover.right; leftMargin: 16; right: parent.right; rightMargin: 16; top: cover.top; topMargin: 8 }
        spacing: 4
        Text { width: parent.width; text: Media.title(np.player); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text }
        Text { width: parent.width; text: Media.artist(np.player); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
        Item { width: 1; height: 8 }
        Rectangle {
            width: parent.width; height: 4; radius: 2
            color: Theme.ink(0.12)
            Rectangle { width: parent.width * Media.progress(np.player); height: 4; radius: 2; color: Theme.accent }
        }
    }
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
        spacing: 24
        Sym {
            code: Icons.skipPrevious; font.pixelSize: Theme.px(20); anchors.verticalCenter: parent.verticalCenter
            color: pv.hovered ? Theme.text : Theme.muted
            HoverHandler { id: pv; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (np.player.canGoPrevious) np.player.previous() }
        }
        Rectangle {
            width: 42; height: 42; radius: 21
            color: Theme.accent
            Sym { anchors.centerIn: parent; code: np.player && np.player.isPlaying ? Icons.pause : Icons.play; font.pixelSize: Theme.px(20); color: Theme.accentInk }
            TapHandler { onTapped: np.player.togglePlaying() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        Sym {
            code: Icons.skipNext; font.pixelSize: Theme.px(20); anchors.verticalCenter: parent.verticalCenter
            color: nx.hovered ? Theme.text : Theme.muted
            HoverHandler { id: nx; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (np.player.canGoNext) np.player.next() }
        }
    }
}
