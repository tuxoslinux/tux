pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import qs.theme

// What is playing (SPEC "Live activities"): any MPRIS player. The one that
// started playing last wins; a paused player stays for a minute, then the
// chip leaves. Video or music is decided from the player and the track.
Singleton {
    id: media

    readonly property var players: Mpris.players.values
    property var startedAt: ({})        // dbusName -> when it last started playing
    property var pausedAt: ({})
    property double now: Date.now()

    function watch() {
        const s = Object.assign({}, startedAt), p = Object.assign({}, pausedAt), t = Date.now(), alive = {};
        for (const pl of players) {
            const n = pl.dbusName;
            alive[n] = true;
            if (pl.isPlaying) { if (!s[n]) s[n] = t; delete p[n]; }
            else if (s[n] && !p[n]) p[n] = t;
            // paused for a minute: forgotten (and the tick below stops)
            else if (s[n] && t - p[n] > 60000) { delete s[n]; delete p[n]; }
        }
        // players that quit
        for (const n in s) if (!alive[n]) delete s[n];
        for (const n in p) if (!alive[n]) delete p[n];
        startedAt = s; pausedAt = p; now = t;
    }
    Variants {
        model: Mpris.players.values
        delegate: Component {
            Connections {
                required property var modelData
                target: modelData
                // (deferred: a player can report its state while the list
                // below is being worked out, which made a binding loop)
                function onIsPlayingChanged() {
                    const pl = modelData;
                    Qt.callLater(() => {
                        if (pl.isPlaying) { const s = Object.assign({}, media.startedAt); s[pl.dbusName] = Date.now(); media.startedAt = s; }
                        media.watch();
                    });
                }
            }
        }
    }
    onPlayersChanged: watch()

    // players worth showing: playing, or paused less than a minute ago
    readonly property var active: {
        void now;
        return players.filter(p => startedAt[p.dbusName] !== undefined && (p.isPlaying || (pausedAt[p.dbusName] && now - pausedAt[p.dbusName] < 60000)))
                      .sort((a, b) => (b.isPlaying - a.isPlaying) || (startedAt[b.dbusName] - startedAt[a.dbusName]));
    }
    readonly property var player: active.length ? active[0] : null

    // tick: position (MPRIS does not push it) and the pause grace period;
    // only runs while something is shown
    Timer {
        interval: 1000
        repeat: true
        running: media.player !== null || Object.keys(media.pausedAt).length > 0
        onTriggered: {
            media.watch();
            for (const p of media.active) p.positionChanged();
        }
    }

    // ---- helpers
    function url(p) { return p && p.metadata ? (p.metadata["xesam:url"] || "") : ""; }
    function isVideo(p) {
        if (!p) return false;
        const u = url(p).toLowerCase();
        const id = ((p.desktopEntry || "") + " " + (p.identity || "")).toLowerCase();
        if (/youtube\.com|youtu\.be|twitch\.tv|vimeo\.com|netflix|primevideo|disneyplus|dailymotion|kick\.com/.test(u)) return true;
        if (/\.(mp4|mkv|webm|mov|avi|m4v|ts)(\?|$)/.test(u)) return true;
        // (Chromium / Helium send no URL: a local file shows its name as the title)
        if (/\.(mp4|mkv|webm|mov|avi|m4v)$/.test((p.trackTitle || "").toLowerCase())) return true;
        if (/ytimg\.com/.test(p.trackArtUrl || "")) return true;
        if (/mpv|vlc|celluloid|haruna|totem|showtime/.test(id)) return !/\.(mp3|flac|ogg|opus|wav|m4a|aac)(\?|$)/.test(u);
        return false;
    }
    function site(p) {
        const u = url(p);
        const m = /^https?:\/\/(?:www\.|m\.)?([^/]+)/.exec(u);
        if (!m) return "";
        const known = { "youtube.com": "YouTube", "youtu.be": "YouTube", "twitch.tv": "Twitch", "vimeo.com": "Vimeo", "netflix.com": "Netflix",
                        "soundcloud.com": "SoundCloud", "open.spotify.com": "Spotify", "music.youtube.com": "YouTube Music", "kick.com": "Kick" };
        return known[m[1]] || m[1];
    }
    function appName(p) {
        if (!p) return "";
        const e = p.desktopEntry ? DesktopEntries.heuristicLookup(p.desktopEntry) : null;
        return e ? e.name : (p.identity || "Player");
    }
    function artist(p) {
        if (!p) return "";
        if (isVideo(p)) return site(p) || p.trackArtist || appName(p);
        return p.trackArtist || p.trackAlbum || appName(p);
    }
    function title(p) { return p ? (p.trackTitle || appName(p)) : ""; }
    function time(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        sec = Math.floor(sec);
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(s).padStart(2, "0");
    }
    // hide the pointer over a playing video (after 2 s still; SPEC "hide the
    // cursor while typing / over video"): only while a video plays
    readonly property bool videoPlaying: player !== null && player.isPlaying && isVideo(player)
    onVideoPlayingChanged: Shell.dispatch(`(function() hl.config({ cursor = { inactive_timeout = ${videoPlaying ? 2 : 0} } }); return hl.dsp.no_op() end)()`, "")

    function progress(p) { return p && p.length > 0 ? Math.max(0, Math.min(1, p.position / p.length)) : 0; }

    Timer {
        id: pipLater
        interval: 300
        onTriggered: {
            Shell.dispatch('(function() tux_float(nil); return hl.dsp.no_op() end)()', "setfloating");
            Shell.dispatch('hl.dsp.window.resize({ x = 480, y = 270, exact = true })', "resizeactive exact 480 270");
            const m = Hyprland.focusedMonitor;
            if (m) Shell.dispatch(`hl.dsp.window.move({ x = ${m.x + m.width / m.scale - 492}, y = ${m.y + m.height / m.scale - 282}, exact = true })`,
                                  `moveactive exact ${m.x + m.width / m.scale - 492} ${m.y + m.height / m.scale - 282}`);
            Shell.dispatch('hl.dsp.window.pin()', "pin");
            media.pipPlayer = media.player;
        }
    }
    property var pipPlayer: null      // the player TuxOS turned into a pinned window
    // picture in picture: the browser's own (Firefox: Ctrl + Shift + ]);
    // other players become a small, pinned, floating window
    function pictureInPicture(p) {
        if (!p) return;
        const id = ((p.desktopEntry || "") + (p.identity || "")).toLowerCase();
        if (p.canRaise) p.raise();
        if (/firefox|librewolf|zen/.test(id))
            Shell.dispatch('hl.dsp.send_shortcut({ mods = "CTRL SHIFT", key = "bracketright" })', "sendshortcut CTRL SHIFT, bracketright, activewindow");
        else pipLater.restart();
    }
}
