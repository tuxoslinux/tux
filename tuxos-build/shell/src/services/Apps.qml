pragma Singleton

import QtQuick
import Quickshell

// Opening the user's default apps (SPEC shortcuts: terminal, browser,
// music, messaging, files, settings - all choosable in Settings). If the
// chosen app is missing, the next installed one of its kind opens.
Singleton {
    id: apps

    readonly property var fallbacks: ({
        terminal: ["kitty", "foot", "alacritty", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "org.kde.konsole", "xfce4-terminal"],
        browser: ["helium-browser", "helium", "firefox", "chromium", "google-chrome", "librewolf", "brave-browser", "zen"],
        music: ["spotify", "com.spotify.client", "tidal-hifi", "youtube-music", "strawberry", "org.strawberrymusicplayer.strawberry", "rhythmbox", "org.kde.elisa", "io.bassi.amberol", "audacious", "tuxos-music"],
        messaging: ["discord", "vesktop", "org.telegram.desktop", "telegramdesktop", "signal-desktop", "viber", "element"],
        files: ["tuxos-files", "thunar", "org.gnome.Nautilus", "org.kde.dolphin", "nemo", "pcmanfm"],
        settings: ["tuxos-control", "xfce-settings-manager", "systemsettings"],
        monitor: ["tuxos-monitor", "btop", "htop"]
    })

    function entry(id) {
        if (!id) return null;
        return DesktopEntries.byId(id) || DesktopEntries.byId(id.replace(/\.desktop$/, ""));
    }

    // the installed app of a kind (the chosen one first), or null
    function find(kind, preferred) {
        for (const id of [preferred].concat(fallbacks[kind] || [])) { const e = entry(id); if (e) return e; }
        return null;
    }

    // kind: "terminal" | "browser" | ...; preferred: the id from Prefs
    function openKind(kind, preferred) {
        const list = [preferred].concat(fallbacks[kind] || []);
        for (const id of list) {
            const e = entry(id);
            if (e) { Usage.launch(e); return true; }
        }
        // no desktop file: try the command itself (e.g. kitty without one)
        if (preferred) { Quickshell.execDetached([preferred]); return true; }
        return false;
    }

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    // uninstall an app (launcher / dock right-click): asks first in a card;
    // the package that owns its .desktop file, or its Flatpak
    function uninstall(e) {
        if (!e) return;
        Toasts.show(Tr.f("Uninstall {n}?", { n: e.name }), Tr.t("Its settings in your home folder stay; the Store can put it back"), Icons.deleteOutline, null, [
            { text: Tr.t("Uninstall"), primary: true, run: () => Quickshell.execDetached(["sh", "-c",
                "id=\"$1\"; for d in \"$HOME/.local/share/flatpak/exports/share/applications\" /var/lib/flatpak/exports/share/applications; do [ -e \"$d/$id.desktop\" ] && { flatpak uninstall --user -y \"$id\" 2>/dev/null || flatpak uninstall -y \"$id\"; notify-send 'Uninstalled' \"$2\"; exit; }; done; "
                + "for f in /usr/share/applications/\"$id\".desktop /usr/local/share/applications/\"$id\".desktop; do [ -e \"$f\" ] && p=$(pacman -Qoq \"$f\" 2>/dev/null) && { pkexec tuxos-pkg remove \"$p\" && notify-send 'Uninstalled' \"$2\"; exit; }; done; notify-send 'Not uninstalled' \"TuxOS could not find which package $2 came from\"",
                "sh", e.id, e.name]) },
            { text: Tr.t("Keep it"), run: () => {} }
        ], 0);
    }
}
