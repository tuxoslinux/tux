pragma Singleton

import QtQuick
import Quickshell

// Smart app symbols (SPEC "Dock"): never an app's stock icon. Order:
// 1. TuxOS table of known apps (desktop-file id / Wayland app id),
// 2. the app's own Categories, then Keywords / GenericName,
// 3. the first letter of its name. User overrides come from Settings.
Singleton {
    id: sym

    readonly property int globe: 0xf059f
    readonly property int robot: 0xf06a9
    readonly property int gamepad: 0xf0297
    readonly property int chat: 0xf0b79
    readonly property int music: 0xf075a
    readonly property int play: 0xf040a
    readonly property int terminal: 0xf018d
    readonly property int folder: 0xf024b
    readonly property int pencil: 0xf03eb
    readonly property int code: 0xf0169
    readonly property int cog: 0xf0493
    readonly property int image: 0xf02e9
    readonly property int document: 0xf0219
    readonly property int calculator: 0xf00ec
    readonly property int mail: 0xf01ee
    readonly property int trash: 0xf0a7a

    // user overrides: id -> symbol code (Settings > Appearance > App symbols)
    readonly property var overrides: Prefs.symbolOverrides || ({})

    readonly property var known: ({
        // browsers
        "firefox": globe, "org.mozilla.firefox": globe, "google-chrome": globe, "chromium": globe,
        "librewolf": globe, "io.gitlab.librewolf-community": globe, "brave-browser": globe, "com.brave.browser": globe,
        "helium": globe, "helium-browser": globe, "net.imput.helium": globe, "zen": globe, "zen-browser": globe,
        "app.zen_browser.zen": globe, "vivaldi-stable": globe, "microsoft-edge": globe, "opera": globe,
        // AI
        "claude": robot, "com.anthropic.claude": robot, "claude-desktop": robot, "chatgpt": robot,
        "com.openai.chatgpt": robot, "codex": robot,
        // games
        "steam": gamepad, "com.valvesoftware.steam": gamepad, "lutris": gamepad, "net.lutris.lutris": gamepad,
        "heroic": gamepad, "com.heroicgameslauncher.hgl": gamepad, "protonplus": gamepad, "com.vysp3r.protonplus": gamepad,
        // chat
        "discord": chat, "com.discordapp.discord": chat, "vesktop": chat, "telegram": chat, "org.telegram.desktop": chat,
        "telegramdesktop": chat, "signal": chat, "org.signal.signal": chat, "signal-desktop": chat, "viber": chat,
        "element": chat, "im.riot.riot": chat,
        // music
        "spotify": music, "com.spotify.client": music, "tidal-hifi": music, "deezer": music, "youtube-music": music,
        "strawberry": music, "org.strawberrymusicplayer.strawberry": music, "rhythmbox": music, "org.gnome.rhythmbox3": music,
        "elisa": music, "org.kde.elisa": music, "lollypop": music, "org.gnome.lollypop": music, "amberol": music,
        "io.bassi.amberol": music, "audacious": music, "clementine": music, "cider": music, "nuclear": music, "soundcloud": music,
        // video
        "mpv": play, "io.mpv.mpv": play, "vlc": play, "org.videolan.vlc": play, "celluloid": play, "org.kde.haruna": play,
        // terminals
        "kitty": terminal, "foot": terminal, "footclient": terminal, "alacritty": terminal, "org.wezfurlong.wezterm": terminal,
        "org.kde.konsole": terminal, "org.gnome.terminal": terminal, "com.mitchellh.ghostty": terminal,
        // files
        "thunar": folder, "org.gnome.nautilus": folder, "org.kde.dolphin": folder, "nemo": folder, "pcmanfm": folder,
        "tuxos-files": folder,
        // editors
        "org.xfce.mousepad": pencil, "org.gnome.texteditor": pencil, "org.kde.kate": pencil, "code": code,
        "code-oss": code, "codium": code, "dev.zed.zed": code,
        // TuxOS' own apps
        "tuxos-control": cog, "tuxos-calculator": calculator, "tuxos-clock": 0xf0150, "tuxos-monitor": 0xf04c5, "tuxos-calendar": 0xf00ed
    })

    function norm(s) { return (s || "").toLowerCase().replace(/\.desktop$/, ""); }

    // returns { code: int } or { letter: string }
    function forEntry(entry, appId) {
        const ids = [norm(entry ? entry.id : ""), norm(appId), norm(entry ? entry.startupClass : "")];
        for (const id of ids) {
            if (!id) continue;
            if (overrides[id] !== undefined) return { code: overrides[id] };
            if (known[id] !== undefined) return { code: known[id] };
        }
        if (entry) {
            const cats = entry.categories ? Array.from(entry.categories) : [];
            const has = c => cats.indexOf(c) !== -1;
            if (has("WebBrowser")) return { code: globe };
            if (has("TerminalEmulator")) return { code: terminal };
            if (has("FileManager")) return { code: folder };
            if (has("Game")) return { code: gamepad };
            if (has("Chat") || has("InstantMessaging")) return { code: chat };
            if (has("Calculator")) return { code: calculator };
            if (has("Email")) return { code: mail };
            if ((has("Audio") || has("Music")) && (has("Player") || has("Music"))) return { code: music };
            if (has("Video") || has("Player")) return { code: play };
            if (has("TextEditor")) return { code: pencil };
            if (has("IDE") || has("Development")) return { code: code };
            if (has("Settings") || has("System")) return { code: cog };
            if (has("Graphics") || has("Photography") || has("Viewer")) return { code: image };
            if (has("Office")) return { code: document };
            const words = ((entry.keywords ? Array.from(entry.keywords) : []).join(" ") + " " + (entry.genericName || "")).toLowerCase();
            if (/\b(ai|assistant|chatbot|llm)\b/.test(words)) return { code: robot };
            if (/music player/.test(words)) return { code: music };
        }
        const name = entry ? entry.name : appId;
        return { letter: (name || "?").charAt(0).toUpperCase() };
    }
}
