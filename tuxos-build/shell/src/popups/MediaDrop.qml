import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.theme
import qs.components
import qs.services

// Hover droplet of the live-activity chip (mockups desktop-v6-live-*-hover):
// music: cover, title, artist, app, seek slider, elapsed / remaining,
// shuffle / previous / play-pause / next / repeat. Video: preview (click =
// picture in picture), title, site · app, slider, times, pop-out / previous /
// play-pause / next / volume. Other activities are listed under it.
Column {
    id: root
    readonly property var item: Activities.list.length ? Activities.list[0] : null
    readonly property var player: item && item.player ? item.player : null
    readonly property bool video: item !== null && item.kind === "video"
    padding: 20
    spacing: 16

    component Ctl: Item {
        property int code
        property bool on: false
        property bool enabled2: true
        signal hit()
        width: 36; height: 48
        opacity: enabled2 ? 1 : 0.35
        Sym { anchors.centerIn: parent; code: parent.code; font.pixelSize: Theme.px(19); color: parent.on ? Theme.accent : (ch.hovered ? Theme.text : Theme.muted) }
        HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (parent.enabled2) parent.hit() }
    }

    // ---------------------------------------------------------- music
    Row {
        visible: root.player !== null && !root.video
        width: root.width - 44
        spacing: 20
        ClippingRectangle {
            width: 128; height: 128; radius: 18
            color: Theme.ink(0.06)
            Image {
                id: cover
                anchors.fill: parent
                source: root.player && !root.video ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(256, 256)
                asynchronous: true
                visible: status === Image.Ready
                layer.enabled: true
            }
            Sym { anchors.centerIn: parent; visible: cover.status !== Image.Ready; code: Icons.musicNote; font.pixelSize: Theme.px(46); color: Theme.muted }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 148
            spacing: 4
            Text { width: parent.width; text: Media.title(root.player); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(24); font.weight: Font.DemiBold; color: Theme.text }
            Text { width: parent.width; text: Media.artist(root.player); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(16); color: Theme.muted }
            Row {
                spacing: 4; topPadding: 4
                Sym { code: Icons.musicNote; font.pixelSize: Theme.px(13); color: Theme.muted }
                Text { text: Media.appName(root.player); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
            }
        }
    }

    // ---------------------------------------------------------- video
    Column {
        visible: root.player !== null && root.video
        width: root.width - 44
        spacing: 12
        ClippingRectangle {
            width: parent.width; height: Math.round(width * 9 / 16)
            radius: 16
            color: Qt.rgba(0, 0, 0, 0.35)
            Image {
                id: thumb
                anchors.fill: parent
                source: root.video && root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(640, 360)
                visible: status === Image.Ready
            }
            // the player's window, captured as the droplet opens (a live
            // capture would film the droplet itself)
            Loader {
                anchors.fill: parent
                active: thumb.status !== Image.Ready && Shell.panel === "media" && root.player !== null
                sourceComponent: WindowThumb {
                    live: false
                    radius: 16
                    toplevel: {
                        const want = AppSymbols.norm(root.player.desktopEntry || root.player.identity);
                        return ToplevelManager.toplevels.values.find(t => AppSymbols.norm(t.appId) === want || AppSymbols.norm(t.appId).indexOf(want) !== -1) || null;
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: pipRow.implicitWidth + 32; height: 44; radius: 14
                color: Qt.rgba(10 / 255, 12 / 255, 16 / 255, pipHover.hovered ? 0.85 : 0.65)
                border.width: 1; border.color: Theme.glassLine
                Row {
                    id: pipRow
                    anchors.centerIn: parent; spacing: 8
                    Sym { code: Icons.openInNew; font.pixelSize: Theme.px(16) }
                    Text { text: Tr.t("Pop out (picture in picture)"); font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
                }
            }
            HoverHandler { id: pipHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { Media.pictureInPicture(root.player); Shell.close(); } }
        }
        Text { width: parent.width; text: Media.title(root.player); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(19); font.weight: Font.DemiBold; color: Theme.text }
        Row {
            spacing: 4
            Sym { code: Icons.web; font.pixelSize: Theme.px(13); color: Theme.muted }
            Text { text: [Media.site(root.player), Media.appName(root.player)].filter(x => x).join(" · "); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        }
    }

    // ---------------------------------------------------------- seek + controls
    Column {
        visible: root.player !== null
        width: root.width - 44
        spacing: 4
        Slider {
            width: parent.width
            value: Media.progress(root.player)
            onMoved: v => { if (root.player && root.player.canSeek) root.player.position = v * root.player.length; }
        }
        Item {
            width: parent.width; height: 16
            Text { text: Media.time(root.player ? root.player.position : 0); font.family: Theme.font; font.pixelSize: Theme.px(12); font.features: { "tnum": 1 }; color: Theme.muted }
            Text {
                anchors.right: parent.right
                text: root.player && root.player.length > 0 ? "-" + Media.time(root.player.length - root.player.position) : ""
                font.family: Theme.font; font.pixelSize: Theme.px(12); font.features: { "tnum": 1 }; color: Theme.muted
            }
        }
    }
    Row {
        visible: root.player !== null
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 20
        Ctl {
            visible: !root.video
            code: Icons.shuffle
            enabled2: root.player !== null && root.player.shuffleSupported
            on: root.player !== null && root.player.shuffle
            onHit: root.player.shuffle = !root.player.shuffle
        }
        Ctl {
            visible: root.video
            code: Icons.openInNew
            onHit: { Media.pictureInPicture(root.player); Shell.close(); }
        }
        Ctl { code: Icons.skipPrevious; enabled2: root.player !== null && root.player.canGoPrevious; onHit: root.player.previous() }
        Rectangle {
            width: 48; height: 48; radius: 24
            color: Theme.accent
            Sym { anchors.centerIn: parent; code: root.player && root.player.isPlaying ? Icons.pause : Icons.play; font.pixelSize: Theme.px(22); color: Theme.accentInk }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.player.togglePlaying() }
        }
        Ctl { code: Icons.skipNext; enabled2: root.player !== null && root.player.canGoNext; onHit: root.player.next() }
        Ctl {
            visible: !root.video
            code: root.player && root.player.loopState === MprisLoopState.Track ? Icons.repeatOnce : Icons.repeat
            enabled2: root.player !== null && root.player.loopSupported
            on: root.player !== null && root.player.loopState !== MprisLoopState.None
            onHit: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                 : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
        }
        Ctl {
            visible: root.video
            code: root.player && root.player.volume < 0.01 ? Icons.volumeOff : Icons.volumeHigh
            enabled2: root.player !== null && root.player.volumeSupported
            onHit: root.player.volume = root.player.volume > 0.01 ? 0 : 1
        }
    }

    // ---------------------------------------------------------- everything else
    Rectangle {
        visible: root.player !== null && Activities.list.length > 1
        width: root.width - 44; height: 1
        color: Theme.glassLine
    }
    Repeater {
        model: root.player !== null ? Activities.list.slice(1) : Activities.list
        delegate: Item {
            required property var modelData
            width: root.width - 44
            height: 52
            Rectangle {
                width: 36; height: 36; radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink(0.08)
                Sym { anchors.centerIn: parent; code: modelData.icon; color: modelData.color; font.pixelSize: Theme.px(17) }
            }
            Column {
                x: 50; width: parent.width - 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Item {
                    width: parent.width; height: 18
                    Text { width: parent.width - 90; text: modelData.title + (modelData.sub ? "  ·  " + modelData.sub : ""); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                    Text { anchors.right: parent.right; text: modelData.right; font.family: Theme.font; font.pixelSize: Theme.px(13); font.features: { "tnum": 1 }; color: Theme.muted }
                }
                Rectangle {
                    visible: modelData.progress >= 0
                    width: parent.width; height: 4; radius: 2
                    color: Theme.ink(0.10)
                    Rectangle { width: parent.width * Math.max(0, modelData.progress); height: 4; radius: 2; color: modelData.color }
                }
            }
            TapHandler { onTapped: if (modelData.player && modelData.player.canRaise) modelData.player.raise() }
        }
    }
}
