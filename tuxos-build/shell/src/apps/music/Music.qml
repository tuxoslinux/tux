import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Music (mockup apps/19-music): the songs in ~/Music by album, artist,
// song and genre, Liked and own playlists, search. It plays through a
// background mpv with mpv-mpris, so the bar's media chip, the lock screen
// and the media keys control it too. Super + V opens it when no streaming
// app is installed.
AppWindow {
    id: app
    appName: "Music"
    appIcon: 0xf0387
    searchable: true
    searchHint: "Search your music"

    property var songs: []
    property string view: "albums"            // albums | artists | songs | genres | liked | playlist:NAME | album:KEY | artist:NAME | genre:NAME
    property bool scanning: true
    readonly property string sock: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tuxos-music.sock"
    readonly property string dataFile: Quickshell.env("HOME") + "/.local/share/tuxos/music.json"

    // ---- library
    Process {
        id: scan
        running: true
        command: ["tuxos-music-scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = [];
                for (const line of text.split("\n")) { if (!line) continue; try { const s = JSON.parse(line); if (!s.title) s.title = s.path.substring(s.path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, ""); l.push(s); } catch (e) {} }
                app.songs = l; app.scanning = false;
            }
        }
    }
    function albumKey(s) { return (s.album || Tr.t("Unknown album")) + "\u0001" + (s.artist || ""); }
    readonly property var albums: {
        const m = {};
        for (const s of songs) { const k = albumKey(s); if (!m[k]) m[k] = { key: k, album: s.album || Tr.t("Unknown album"), artist: s.artist || Tr.t("Unknown artist"), cover: s.cover, songs: [] }; m[k].songs.push(s); if (!m[k].cover && s.cover) m[k].cover = s.cover; }
        return Object.values(m).sort((a, b) => a.album.localeCompare(b.album));
    }
    readonly property var artists: [...new Set(songs.map(s => s.artist || Tr.t("Unknown artist")))].sort()
    readonly property var genres: [...new Set(songs.map(s => s.genre).filter(g => g))].sort()

    // liked songs and playlists (~/.local/share/tuxos/music.json)
    property var liked: []
    property var playlists: ({})
    FileView {
        id: data
        path: app.dataFile
        printErrors: false
        onLoaded: { try { const j = JSON.parse(text()); app.liked = j.liked || []; app.playlists = j.playlists || {}; } catch (e) {} }
    }
    function saveData() { Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/share/tuxos"]); data.setText(JSON.stringify({ liked: liked, playlists: playlists }, null, 1)); }
    function toggleLike(p) { liked = liked.indexOf(p) === -1 ? liked.concat([p]) : liked.filter(x => x !== p); saveData(); }
    function addTo(name, p) { const pl = Object.assign({}, playlists); pl[name] = (pl[name] || []).concat([p]); playlists = pl; saveData(); }

    // what the main area lists
    readonly property var shownSongs: {
        const q = app.search.trim().toLowerCase();
        let l = songs;
        if (view.startsWith("album:")) l = songs.filter(s => albumKey(s) === view.slice(6)).sort((a, b) => a.track - b.track);
        else if (view.startsWith("artist:")) l = songs.filter(s => (s.artist || Tr.t("Unknown artist")) === view.slice(7));
        else if (view.startsWith("genre:")) l = songs.filter(s => s.genre === view.slice(6));
        else if (view === "liked") l = liked.map(p => songs.find(s => s.path === p)).filter(s => s);
        else if (view.startsWith("playlist:")) l = (playlists[view.slice(9)] || []).map(p => songs.find(s => s.path === p)).filter(s => s);
        if (q) l = songs.filter(s => (s.title + " " + s.artist + " " + s.album).toLowerCase().indexOf(q) !== -1);
        return l;
    }
    readonly property bool gridView: !app.search.trim() && (view === "albums")
    readonly property bool listNames: !app.search.trim() && (view === "artists" || view === "genres")

    // ---- the player: mpv in the background (mpv-mpris publishes it)
    Process {
        id: mpv
        running: true
        command: ["mpv", "--idle=yes", "--no-video", "--no-terminal", "--audio-display=no", "--title=TuxOS Music", "--input-ipc-server=" + app.sock, "--volume=80", "--gapless-audio=weak"]
        onRunningChanged: if (running) connectLater.restart()
    }
    Timer { id: connectLater; interval: 500; onTriggered: ipc.connected = true }
    Socket {
        id: ipc
        path: app.sock
        onConnectedChanged: if (connected) {
            for (const [i, p] of [["time-pos", 1], ["duration", 2], ["pause", 3], ["playlist-pos", 4], ["volume", 5], ["loop-playlist", 6], ["loop-file", 7]].entries())
                send(["observe_property", p[1], p[0]]);
        }
        parser: SplitParser {
            onRead: line => {
                let j; try { j = JSON.parse(line); } catch (e) { return; }
                if (j.event !== "property-change") return;
                const v = j.data;
                if (j.name === "time-pos") app.pos = v || 0;
                else if (j.name === "duration") app.dur = v || 0;
                else if (j.name === "pause") app.paused = v === true;
                else if (j.name === "playlist-pos") app.index = v === undefined || v === null ? -1 : v;
                else if (j.name === "volume") app.volume = v || 0;
                else if (j.name === "loop-playlist") app.repeat = v === "inf" ? "all" : (app.repeat === "one" ? "one" : "off");
                else if (j.name === "loop-file") { if (v === "inf") app.repeat = "one"; }
            }
        }
        function send(cmd) { if (connected) write(JSON.stringify({ command: cmd }) + "\n"); }
    }
    property real pos: 0
    property real dur: 0
    property bool paused: true
    property int index: -1
    property real volume: 80
    property string repeat: "off"             // off | all | one
    property bool shuffle: false
    property var queue: []
    readonly property var now: index >= 0 && index < queue.length ? queue[index] : null

    function play(list, start) {
        let l = list.slice();
        let first = l[start || 0];
        if (shuffle) { l = l.filter((s, i) => i !== (start || 0)); for (let i = l.length - 1; i > 0; i--) { const k = Math.floor(Math.random() * (i + 1)); [l[i], l[k]] = [l[k], l[i]]; } l = [first].concat(l); start = 0; }
        queue = l;
        ipc.send(["playlist-clear"]);
        ipc.send(["loadfile", l[0].path, "replace"]);
        for (let i = 1; i < l.length; i++) ipc.send(["loadfile", l[i].path, "append"]);
        if (start) ipc.send(["playlist-play-index", start]);
        ipc.send(["set_property", "pause", false]);
    }
    function toggle() { if (index < 0 && shownSongs.length) play(shownSongs, 0); else ipc.send(["cycle", "pause"]); }
    function cycleRepeat() {
        repeat = repeat === "off" ? "all" : repeat === "all" ? "one" : "off";
        ipc.send(["set_property", "loop-playlist", repeat === "all" ? "inf" : "no"]);
        ipc.send(["set_property", "loop-file", repeat === "one" ? "inf" : "no"]);
    }
    function time(s) { s = Math.max(0, Math.round(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    // keys: Ctrl + arrows previous / next
    Shortcut { sequence: "Ctrl+Right"; onActivated: ipc.send(["playlist-next"]) }
    Shortcut { sequence: "Ctrl+Left"; onActivated: ipc.send(["playlist-prev"]) }

    // ---- sidebar
    Column {
        id: side
        x: 12; y: 12; width: 226
        spacing: 4
        Repeater {
            model: [["albums", "Albums", 0xf0025], ["artists", "Artists", 0xf0849], ["songs", "Songs", 0xf0cb9], ["genres", "Genres", 0xf0b9f], ["", "PLAYLISTS", 0], ["liked", "Liked", 0xf02d1]]
                   .concat(Object.keys(app.playlists).map(n => ["playlist:" + n, n, 0xf0cb8]))
            delegate: Item {
                required property var modelData
                width: side.width; height: modelData[0] === "" ? 34 : 38
                Text { visible: modelData[0] === ""; x: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
                Rectangle {
                    visible: modelData[0] !== ""
                    anchors.fill: parent; radius: 11
                    readonly property bool on: app.view === modelData[0] || (modelData[0] === "albums" && app.view.startsWith("album:")) || (modelData[0] === "artists" && app.view.startsWith("artist:")) || (modelData[0] === "genres" && app.view.startsWith("genre:"))
                    color: on ? Theme.accentFill : (sh.hovered ? Theme.fill : "transparent")
                    border.width: on ? 1 : 0; border.color: Theme.accentLine
                    Row { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 12
                        Text { text: String.fromCodePoint(modelData[2] || 32); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: parent.parent.on ? Theme.accent : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; anchors.verticalCenter: parent.verticalCenter } }
                    HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { app.view = modelData[0]; app.search = ""; } }
                }
            }
        }
        Rectangle {
            width: side.width; height: 38; radius: 11
            color: nh.hovered ? Theme.fill : "transparent"
            Row { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 12
                Text { text: "+"; font.family: Theme.font; font.pixelSize: Theme.px(17); color: Theme.muted }
                Text { text: Tr.t("New playlist"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted } }
            HoverHandler { id: nh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { let n = Tr.t("Playlist"), i = 2; while (app.playlists[n]) n = Tr.t("Playlist") + " " + i++; const pl = Object.assign({}, app.playlists); pl[n] = []; app.playlists = pl; app.saveData(); app.view = "playlist:" + n; } }
        }
    }
    Rectangle { x: side.x + side.width + 11; y: 0; width: 1; height: parent.height; color: Theme.glassLine }

    // ---- heading
    Column {
        id: heading
        x: side.x + side.width + 32; y: 16
        spacing: 4
        Text {
            text: app.search.trim() ? Tr.f("Results for \"{q}\"", { q: app.search.trim() })
                : app.view.startsWith("album:") ? app.view.slice(6).split("\u0001")[0] : app.view.startsWith("artist:") ? app.view.slice(7) : app.view.startsWith("genre:") ? app.view.slice(6)
                : app.view.startsWith("playlist:") ? app.view.slice(9) : Tr.t({ albums: "Albums", artists: "Artists", songs: "Songs", genres: "Genres", liked: "Liked" }[app.view] || "")
            font.family: Theme.font; font.pixelSize: Theme.px(28); font.weight: Font.Bold; color: Theme.text
        }
        Text {
            text: app.scanning ? Tr.t("Reading ~/Music...") : (app.songs.length ? Tr.f("{n} songs from ~/Music", { n: app.songs.length }) : Tr.t("Put music files in ~/Music and they show up here"))
            font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted
        }
    }

    Item {
        id: main
        anchors { left: heading.left; right: parent.right; rightMargin: 16; top: heading.bottom; topMargin: 16; bottom: player.top; bottomMargin: 8 }

        // albums grid
        GridView {
            id: grid
            visible: app.gridView
            anchors.fill: parent
            clip: true
            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 210))); cellHeight: cellWidth + 52
            model: app.gridView ? app.albums : []
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                required property var modelData
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    id: art
                    x: 8; y: 8; width: parent.width - 16; height: width; radius: 16
                    color: Theme.ink(0.06)
                    clip: true
                    Image { anchors.fill: parent; source: modelData.cover ? "file://" + modelData.cover : ""; sourceSize: Qt.size(420, 420); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    Text { anchors.centerIn: parent; visible: !modelData.cover; text: String.fromCodePoint(0xf0025); font.family: Theme.symbols; font.pixelSize: Theme.px(48); color: Theme.dim }
                    Rectangle {
                        visible: ah.hovered
                        anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
                        width: 46; height: 46; radius: 23; color: Theme.accent
                        Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf040a); font.family: Theme.symbols; font.pixelSize: Theme.px(22); color: Theme.accentInk }
                        TapHandler { onTapped: app.play(modelData.songs.slice().sort((a, b) => a.track - b.track), 0) }
                    }
                    HoverHandler { id: ah; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: app.view = "album:" + modelData.key }
                }
                Text { anchors { left: art.left; right: art.right; top: art.bottom; topMargin: 8 } text: modelData.album; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.text }
                Text { anchors { left: art.left; right: art.right; top: art.bottom; topMargin: 28 } text: modelData.artist; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
            }
        }
        // artists / genres
        ListView {
            visible: app.listNames
            anchors.fill: parent
            clip: true
            model: app.listNames ? (app.view === "artists" ? app.artists : app.genres) : []
            delegate: Rectangle {
                required property string modelData
                width: ListView.view.width; height: 44; radius: 11
                color: lh.hovered ? Theme.fill : "transparent"
                Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData; font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.text }
                Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: Tr.f("{n} songs", { n: app.songs.filter(s => app.view === "artists" ? (s.artist || Tr.t("Unknown artist")) === modelData : s.genre === modelData).length }); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: app.view = (app.view === "artists" ? "artist:" : "genre:") + modelData }
            }
        }
        // songs
        ListView {
            id: songList
            visible: !app.gridView && !app.listNames
            anchors.fill: parent
            clip: true
            model: visible ? app.shownSongs : []
            boundsBehavior: Flickable.StopAtBounds
            header: Row {
                visible: songList.count > 0
                height: visible ? 52 : 0
                spacing: 8
                Btn { text: "Play"; icon: 0xf040a; primary: true; onClicked: app.play(app.shownSongs, 0) }
                Btn { text: "Shuffle"; icon: 0xf049d; onClicked: { app.shuffle = true; app.play(app.shownSongs, Math.floor(Math.random() * app.shownSongs.length)); } }
            }
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool playing: app.now && app.now.path === modelData.path
                width: songList.width; height: 46; radius: 11
                color: playing ? Theme.accentFill : (rh.hovered ? Theme.fill : "transparent")
                Text { x: 12; width: 26; anchors.verticalCenter: parent.verticalCenter; text: row.playing ? String.fromCodePoint(app.paused ? 0xf03e4 : 0xf0387) : (index + 1); font.family: row.playing ? Theme.symbols : Theme.font; font.pixelSize: Theme.px(13); color: row.playing ? Theme.accent : Theme.dim }
                Text { x: 50; width: parent.width * 0.38; anchors.verticalCenter: parent.verticalCenter; text: modelData.title; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); color: row.playing ? Theme.accent : Theme.text }
                Text { x: parent.width * 0.42; width: parent.width * 0.22; anchors.verticalCenter: parent.verticalCenter; text: modelData.artist; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                Text { x: parent.width * 0.66; width: parent.width * 0.2; anchors.verticalCenter: parent.verticalCenter; text: modelData.album; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                Text {
                    anchors { right: dur.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    readonly property bool on: app.liked.indexOf(modelData.path) !== -1
                    visible: on || rh.hovered
                    text: String.fromCodePoint(on ? 0xf02d1 : 0xf02d5); font.family: Theme.symbols; font.pixelSize: Theme.px(16); color: on ? Theme.danger : Theme.muted
                    TapHandler { onTapped: app.toggleLike(modelData.path) }
                }
                Text { id: dur; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: app.time(modelData.duration); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
                HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onDoubleTapped: app.play(app.shownSongs, index); onTapped: if (!app.now) app.play(app.shownSongs, index) }
                TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: { const names = Object.keys(app.playlists); const n = names.length ? names[0] : Tr.t("Playlist"); app.addTo(n, modelData.path); app.flash(Tr.f("Added to {n}", { n: n })); } }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: {
                        // right click: add to the first playlist (or make one)
                        const names = Object.keys(app.playlists);
                        const n = names.length ? names[0] : Tr.t("Playlist");
                        app.addTo(n, modelData.path);
                        app.flash(Tr.f("Added to {n}", { n: n }));
                    }
                }
            }
        }
        EmptyState {
            anchors.centerIn: parent
            visible: !app.scanning && ((app.gridView && app.albums.length === 0) || (!app.gridView && !app.listNames && app.shownSongs.length === 0))
            title: app.search.trim() ? "Nothing found" : (app.view === "liked" ? "No liked songs yet" : app.view.startsWith("playlist:") ? "This playlist is empty" : "No music yet")
            hint: app.search.trim() ? "Try another word" : (app.view === "liked" ? "Tap the heart on a song to keep it here" : app.view.startsWith("playlist:") ? "Right-click songs to add them here" : "Put music in ~/Music: it shows up by itself")
        }
    }
    property string message: ""
    function flash(t) { message = t; msgT.restart(); }
    Timer { id: msgT; interval: 2500; onTriggered: app.message = "" }

    // ---- player bar
    Rectangle {
        id: player
        anchors { left: side.right; leftMargin: 12; right: parent.right; bottom: parent.bottom }
        height: 88
        color: Theme.ink(0.03)
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.glassLine }
        Rectangle {
            id: cover
            x: 20; anchors.verticalCenter: parent.verticalCenter
            width: 56; height: 56; radius: 10; color: Theme.ink(0.08); clip: true
            Image { anchors.fill: parent; source: app.now && app.now.cover ? "file://" + app.now.cover : ""; sourceSize: Qt.size(112, 112); fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Text { anchors.centerIn: parent; visible: !(app.now && app.now.cover); text: String.fromCodePoint(0xf0387); font.family: Theme.symbols; font.pixelSize: Theme.px(22); color: Theme.dim }
        }
        Column {
            anchors { left: cover.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
            width: 200
            Text { width: parent.width; text: app.message || (app.now ? app.now.title : Tr.t("Nothing playing")); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: app.message ? Theme.accent : Theme.text }
            Text { width: parent.width; text: app.now ? app.now.artist : ""; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
        }
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            width: Math.min(560, parent.width - 560)
            spacing: 4
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Ctl { code: 0xf049d; on: app.shuffle; onTap: app.shuffle = !app.shuffle }
                Ctl { code: 0xf04ae; onTap: ipc.send(["playlist-prev"]) }
                Rectangle {
                    width: 42; height: 42; radius: 21; color: Theme.accent
                    Text { anchors.centerIn: parent; text: String.fromCodePoint(app.paused || app.index < 0 ? 0xf040a : 0xf03e4); font.family: Theme.symbols; font.pixelSize: Theme.px(22); color: Theme.accentInk }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: app.toggle() }
                }
                Ctl { code: 0xf04ad; onTap: ipc.send(["playlist-next"]) }
                Ctl { code: app.repeat === "one" ? 0xf0458 : 0xf0456; on: app.repeat !== "off"; onTap: app.cycleRepeat() }
            }
            Row {
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter
                Text { width: 40; horizontalAlignment: Text.AlignRight; text: app.time(app.pos); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                Slider { width: Math.min(460, player.width - 640); value: app.dur > 0 ? app.pos / app.dur : 0; onMoved: v => ipc.send(["set_property", "time-pos", v * app.dur]) }
                Text { width: 40; text: app.time(app.dur); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text { text: String.fromCodePoint(app.volume > 0 ? 0xf057e : 0xf075f); font.family: Theme.symbols; font.pixelSize: Theme.px(17); color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
            Slider { width: 120; value: app.volume / 100; onMoved: v => ipc.send(["set_property", "volume", Math.round(v * 100)]) }
        }
    }
    component Ctl: Text {
        property int code
        property bool on: false
        signal tap()
        text: String.fromCodePoint(code)
        font.family: Theme.symbols; font.pixelSize: Theme.px(19)
        color: on ? Theme.accent : (ch.hovered ? Theme.text : Theme.muted)
        anchors.verticalCenter: parent.verticalCenter
        HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: parent.tap() }
    }
}
