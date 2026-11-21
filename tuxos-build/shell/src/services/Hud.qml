pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Game HUD (Super + Shift + G; mockup shell2/13-gamehud): MangoHud inside
// the game, styled as a TuxOS glass card (/usr/share/tuxos/MangoHud.conf):
// FPS with 1 % / 0.1 % lows, frame time and graph, CPU / GPU load and
// temperature, VRAM, RAM, power. The shell toggles it through MangoHud's
// control socket (tuxos-hudctl); without a running game it says so.
Singleton {
    Process {
        id: p
        command: ["tuxos-hudctl", "hud"]
        onExited: code => {
            if (code !== 0)
                Toasts.show(Tr.t("Game HUD"), Notifs.gameRunning ? Tr.t("This game does not load MangoHud (Vulkan and OpenGL games do); the frame limit above still applies to games that do")
                                                                 : Tr.t("Start a game: the HUD shows inside it (Super + Shift + G)"), Icons.gamepadVariant);
        }
    }
    function toggle() { if (!p.running) p.running = true; }
    // a game's profile wants the HUD: MangoHud starts hidden, one toggle shows it
    function show() { Quickshell.execDetached(["tuxos-hudctl", "hud"]); }
}
