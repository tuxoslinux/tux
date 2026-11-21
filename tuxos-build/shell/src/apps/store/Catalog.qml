pragma Singleton
import QtQuick
import Quickshell

// The Store's picked apps: name, what it is, category, symbol and where it
// comes from (pkg = TuxOS / Artix / Arch / CachyOS repositories, flatpak =
// Flathub, aur = the AUR through yay). The repositories are preferred.
Singleton {
    readonly property var apps: [
        { name: "Helium", sub: "Web browser", cat: "internet", icon: 0xf059f, pkg: "helium-browser", aur: "helium-browser-bin", popular: true },
        { name: "Firefox", sub: "Web browser", cat: "internet", icon: 0xf059f, pkg: "firefox" },
        { name: "Chromium", sub: "Web browser", cat: "internet", icon: 0xf059f, pkg: "chromium" },
        { name: "Discord", sub: "Chat", cat: "internet", icon: 0xf066f, pkg: "discord", popular: true },
        { name: "Vesktop", sub: "Discord, faster", cat: "internet", icon: 0xf066f, pkg: "vesktop" },
        { name: "Telegram", sub: "Messages", cat: "internet", icon: 0xf066f, pkg: "telegram-desktop" },
        { name: "Signal", sub: "Private messages", cat: "internet", icon: 0xf066f, pkg: "signal-desktop" },
        { name: "Thunderbird", sub: "Email", cat: "internet", icon: 0xf01ee, pkg: "thunderbird" },
        { name: "qBittorrent", sub: "Torrents", cat: "internet", icon: 0xf01da, pkg: "qbittorrent" },
        { name: "Claude", sub: "AI assistant", cat: "internet", icon: 0xf06a9, flatpak: "com.anthropic.Claude", aur: "claude-desktop-bin", popular: true },
        { name: "Steam", sub: "Games", cat: "games", icon: 0xf0297, pkg: "steam", popular: true },
        { name: "Heroic", sub: "Epic, GOG and Amazon games", cat: "games", icon: 0xf0297, flatpak: "com.heroicgameslauncher.hgl", aur: "heroic-games-launcher-bin" },
        { name: "Lutris", sub: "Games from anywhere", cat: "games", icon: 0xf0297, pkg: "lutris" },
        { name: "ProtonPlus", sub: "Proton versions", cat: "games", icon: 0xf0297, pkg: "protonplus" },
        { name: "Prism Launcher", sub: "Minecraft", cat: "games", icon: 0xf0297, pkg: "prismlauncher" },
        { name: "RetroArch", sub: "Classic consoles", cat: "games", icon: 0xf0297, pkg: "retroarch" },
        { name: "Bottles", sub: "Windows apps", cat: "games", icon: 0xf05b3, flatpak: "com.usebottles.bottles" },
        { name: "Spotify", sub: "Music", cat: "media", icon: 0xf0387, flatpak: "com.spotify.Client", aur: "spotify", popular: true },
        { name: "VLC", sub: "Videos", cat: "media", icon: 0xf040a, pkg: "vlc" },
        { name: "OBS Studio", sub: "Recording and streaming", cat: "media", icon: 0xf040a, pkg: "obs-studio", popular: true },
        { name: "Kdenlive", sub: "Video editor", cat: "media", icon: 0xf0567, pkg: "kdenlive" },
        { name: "Audacity", sub: "Audio editor", cat: "media", icon: 0xf036c, pkg: "audacity" },
        { name: "Strawberry", sub: "Music collection", cat: "media", icon: 0xf0387, pkg: "strawberry" },
        { name: "VS Code", sub: "Code editor", cat: "dev", icon: 0xf0a1e, pkg: "visual-studio-code-bin", aur: "visual-studio-code-bin", popular: true },
        { name: "Zed", sub: "Code editor", cat: "dev", icon: 0xf0a1e, pkg: "zed" },
        { name: "Git", sub: "Version control", cat: "dev", icon: 0xf02a2, pkg: "git" },
        { name: "Docker", sub: "Containers", cat: "dev", icon: 0xf0868, pkg: "docker" },
        { name: "Distrobox", sub: "Other Linux systems in a box", cat: "dev", icon: 0xf0868, pkg: "distrobox" },
        { name: "GIMP", sub: "Image editor", cat: "graphics", icon: 0xf021f, pkg: "gimp", popular: true },
        { name: "Krita", sub: "Painting", cat: "graphics", icon: 0xf03d8, pkg: "krita" },
        { name: "Inkscape", sub: "Vector drawing", cat: "graphics", icon: 0xf03d8, pkg: "inkscape" },
        { name: "Blender", sub: "3D", cat: "graphics", icon: 0xf01a7, pkg: "blender" },
        { name: "darktable", sub: "Photos", cat: "graphics", icon: 0xf0100, pkg: "darktable" },
        { name: "LibreOffice", sub: "Documents, sheets, slides", cat: "office", icon: 0xf0219, pkg: "libreoffice-fresh" },
        { name: "OnlyOffice", sub: "Office, Microsoft formats", cat: "office", icon: 0xf0219, flatpak: "org.onlyoffice.desktopeditors" },
        { name: "Obsidian", sub: "Notes", cat: "office", icon: 0xf082e, pkg: "obsidian" },
        { name: "KeePassXC", sub: "Passwords", cat: "office", icon: 0xf0306, pkg: "keepassxc" },
        { name: "Bitwarden", sub: "Passwords", cat: "office", icon: 0xf0306, pkg: "bitwarden" }
    ]
    readonly property var cats: [["discover", "Discover", 0xf02dc], ["games", "Games", 0xf0297], ["internet", "Internet", 0xf059f], ["media", "Music & video", 0xf0387],
                                 ["dev", "Development", 0xf0169], ["graphics", "Graphics", 0xf03d8], ["office", "Office", 0xf0219]]
}
