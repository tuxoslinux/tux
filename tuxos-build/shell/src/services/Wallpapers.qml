pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

// Wallpapers (SPEC round 4 #14-16, round 8 #13): the shell draws them
// (desktop/Background.qml), one per screen. Rules in Prefs.wallpapers:
//   "default"  every screen and desktop (a file, else ~/.local/share/tuxos/wallpaper.png)
//   "mon:NAME" one monitor
//   "ws:N"     one desktop (wins over the monitor's)
// A wallpaper is a picture, a video (.mp4 / .webm / .mkv / .mov: a live
// wallpaper) or "shader:NAME" (a live shader). Live ones pause while a
// game or any full-screen app runs, on battery and while locked.
// Accent from wallpaper / from album art: Background.qml picks the colour.
Singleton {
    id: wp

    readonly property string defaultFile: Quickshell.env("HOME") + "/.local/share/tuxos/wallpaper.png"
    property int stamp: 0                   // bumps when a file changed in place
    readonly property var rules: Prefs.wallpapers || ({})

    function pathFor(screenName, wsId) {
        return rules["ws:" + wsId] || rules["mon:" + screenName] || rules["default"] || defaultFile;
    }
    function isVideo(p) { return /\.(mp4|webm|mkv|mov)$/i.test(p || ""); }
    function isShader(p) { return (p || "").startsWith("shader:"); }
    function isLive(p) { return isVideo(p) || isShader(p); }
    // live wallpapers stop moving while they would cost power or frames
    readonly property bool paused: Notifs.gameRunning || Shell.fullscreenFocused || SmartPower.onBattery || Power.locked

    // set from Settings, Welcome, the Image viewer ("Set as wallpaper")
    function set(path, scope) {
        const r = Object.assign({}, rules);
        if (!scope || scope === "default") {
            delete r["default"];
            if (isLive(path)) r["default"] = path;
            else Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && cp -f \"$1\" \"$2\"", "sh", path, defaultFile]);
        } else if (path) r[scope] = path;
        else delete r[scope];
        Prefs.wallpapers = r;
        later.restart();
    }
    Timer { id: later; interval: 400; onTriggered: wp.stamp++ }

    // the shaders TuxOS ships (shell/shaders, compiled to assets/shaders)
    readonly property var shaders: [["shader:aurora", "Aurora"], ["shader:nebula", "Nebula"], ["shader:waves", "Night waves"]]

    // depth effect (lock screen): one mask per wallpaper picture, made once
    // (desktop/Background.qml runs components/DepthMask.qml) and kept in
    // ~/.local/share/tuxos/depth/<md5 of the picture>.png
    readonly property string depthDir: Quickshell.env("HOME") + "/.local/share/tuxos/depth"
    property string depthKey: ""
    property bool depthMaskExists: false
    property bool depthNone: false          // looked: this picture has no depth (<key>.none)
    readonly property string depthMask: depthKey && depthMaskExists ? depthDir + "/" + depthKey + ".png" : ""
    readonly property string depthWanted: Prefs.depthEffect && depthKey && !depthMaskExists && !depthNone ? depthDir + "/" + depthKey + ".png" : ""
    Process {
        id: keyProc
        // a mask (made or touched up) wins over an earlier "no depth"
        command: ["sh", "-c", "mkdir -p \"$2\"; k=$(md5sum < \"$1\" | cut -c1-16); echo \"$k\"; if [ -s \"$2/$k.png\" ]; then echo yes; elif [ -e \"$2/$k.none\" ]; then echo none; fi", "sh", wp.defaultFile, wp.depthDir]
        stdout: StdioCollector { onStreamFinished: { const l = text.split("\n"); wp.depthKey = l[0].trim(); const v = (l[1] || "").trim(); wp.depthMaskExists = v === "yes"; wp.depthNone = v === "none"; } }
    }
    // the picture was looked at and has no subject: remembered, so the lock
    // screen keeps its usual layout (with the note) without looking again
    function depthNotFound() { if (depthKey) { Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && : > \"$1/$2.none\"", "sh", depthDir, depthKey]); depthNone = true; } }
    function checkDepth() { if (Prefs.depthEffect) { keyProc.running = false; keyProc.running = true; } }
    onStampChanged: { checkDepth(); syncLogin(); }
    Connections { target: Prefs; function onDepthEffectChanged() { wp.checkDepth(); wp.syncLogin(); } }
    Component.onCompleted: { checkDepth(); syncLogin(); }

    // the login screen shows this user's wallpaper too (and its depth effect):
    // a copy in the shared, sticky /var/lib/tuxos-login-wallpapers
    // (<user>.wallpaper; <user>.nodepth while the depth effect is off)
    function syncLogin() {
        if (Shell.live || Quickshell.env("TUXOS_GREETER")) return;
        Quickshell.execDetached(["sh", "-c",
            "d=/var/lib/tuxos-login-wallpapers; [ -d \"$d\" ] && [ -w \"$d\" ] || exit 0; u=$(id -un); f=\"$d/$u.wallpaper\"; "
            + "if [ -f \"$1\" ] && ! cmp -s \"$1\" \"$f\"; then cp -f \"$1\" \"$f.new\" && chmod 644 \"$f.new\" && mv -f \"$f.new\" \"$f\"; fi; "
            + "if [ \"$2\" = on ]; then rm -f \"$d/$u.nodepth\"; else : > \"$d/$u.nodepth\"; fi",
            "sh", defaultFile, Prefs.depthEffect ? "on" : "off"]);
    }
    function depthSaved() { depthMaskExists = true; }

    IpcHandler {
        target: "wallpaper"
        function set(path: string, scope: string): void { wp.set(path, scope); }
        function reload(): void { wp.stamp++; }
        // Settings saved a touched-up depth mask
        function depthChanged(): void { wp.depthMaskExists = false; wp.checkDepth(); }
        // why live wallpapers are paused (tests, troubleshooting)
        function state(): string {
            return JSON.stringify({ paused: wp.paused, game: Notifs.gameRunning, fullscreen: Shell.fullscreenFocused, battery: SmartPower.onBattery, locked: Power.locked });
        }
    }
}
