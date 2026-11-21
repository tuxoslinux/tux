import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// "Now playing" for the depth-effect lock screen: a slim glass tab above the
// compact card (the big card's NowPlaying would cover the wallpaper's
// subject): cover, title, artist, progress, previous / play-pause / next.
// Only on the lock screen (not the login screen); hidden when nothing plays.
Rectangle {
    id: tab
    readonly property var player: Media.player
    property bool shown: true
    visible: shown && player !== null && Media.title(player) !== ""
    width: 560; height: 84
    radius: 28
    color: Qt.rgba(Theme.glassBase.r, Theme.glassBase.g, Theme.glassBase.b, Theme.lite ? 0.92 : (Theme.light ? 0.62 : 0.42))
    border.width: 1; border.color: Theme.glassLine
    clip: true

    ClippingRectangle {
        id: cover
        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
        width: 52; height: 52; radius: 12
        color: Theme.ink(0.08)
        Image { anchors.fill: parent; source: tab.player ? tab.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(104, 104); asynchronous: true }
        Sym { anchors.centerIn: parent; visible: !(tab.player && tab.player.trackArtUrl); code: Icons.musicNote; font.pixelSize: Theme.px(22); color: Theme.muted }
    }
    Column {
        anchors { left: cover.right; leftMargin: 14; right: controls.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 4
        Text { width: parent.width; text: Media.title(tab.player); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
        Text { width: parent.width; text: Media.artist(tab.player); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        Rectangle {
            width: parent.width; height: 3; radius: 2
            color: Theme.ink(0.12)
            Rectangle { width: parent.width * Media.progress(tab.player); height: 3; radius: 2; color: Theme.accent }
        }
    }
    Row {
        id: controls
        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
        spacing: 16
        Sym {
            code: Icons.skipPrevious; font.pixelSize: Theme.px(20); anchors.verticalCenter: parent.verticalCenter
            color: pv.hovered ? Theme.text : Theme.muted
            HoverHandler { id: pv; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (tab.player.canGoPrevious) tab.player.previous() }
        }
        Rectangle {
            width: 40; height: 40; radius: 20
            color: Theme.accent
            Sym { anchors.centerIn: parent; code: tab.player && tab.player.isPlaying ? Icons.pause : Icons.play; font.pixelSize: Theme.px(19); color: Theme.accentInk }
            TapHandler { onTapped: tab.player.togglePlaying() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        Sym {
            code: Icons.skipNext; font.pixelSize: Theme.px(20); anchors.verticalCenter: parent.verticalCenter
            color: nx.hovered ? Theme.text : Theme.muted
            HoverHandler { id: nx; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (tab.player.canGoNext) tab.player.next() }
        }
    }
}
