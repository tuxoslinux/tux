import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Next to the Game HUD (Super + Shift + G; MangoHud draws the numbers inside
// the game): a small glass panel over the game with the frame limiter
// (off, 30 ... 144 or "Screen" = a few frames under the refresh rate),
// saved into this game's profile and applied at once (MangoHud re-reads its
// config), and the VRR / tearing state. ← / → change the limit, Esc closes;
// it leaves by itself after a few seconds without the pointer on it.
PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === Shell.focusedScreen) || Quickshell.screens[0]
    // top centre: the HUD sits top left, toasts top right
    anchors { top: true }
    margins { top: 24 }
    implicitWidth: 460; implicitHeight: col.implicitHeight + 32
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "tuxos-gamecontrols"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property var steps: [0, 30, 60, 90, 120, 144, 999]
    readonly property var p: Games.profileOf(Games.current)
    // the limit in effect: the game's own, else the global one
    readonly property int limit: p.fps >= 0 ? p.fps : Prefs.fpsLimit
    function pick(v) {
        if (Games.current) Games.setProfile(Games.current, "fps", v);
        else { Prefs.fpsLimit = v === 999 ? 0 : v; Games.mangoSet("fps_limit", Prefs.fpsLimit); }
        hideLater.restart();
    }
    Connections {
        target: Shell
        function onPad(w) {
            const i = Math.max(0, win.steps.indexOf(win.limit));
            if (w === "b") Games.controlsShown = false;
            else if (w === "left" && i > 0) win.pick(win.steps[i - 1]);
            else if (w === "right" && i < win.steps.length - 1) win.pick(win.steps[i + 1]);
        }
    }
    Timer { id: hideLater; interval: 6000; running: true; onTriggered: if (!hov.hovered) Games.controlsShown = false }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.glassPanel
        border.width: 1; border.color: Theme.glassLine
        HoverHandler { id: hov; onHoveredChanged: if (!hovered) hideLater.restart() }
        Item {
            focus: true
            Keys.onPressed: e => {
                const i = Math.max(0, win.steps.indexOf(win.limit));
                if (e.key === Qt.Key_Escape) Games.controlsShown = false;
                else if (e.key === Qt.Key_Left && i > 0) win.pick(win.steps[i - 1]);
                else if (e.key === Qt.Key_Right && i < win.steps.length - 1) win.pick(win.steps[i + 1]);
                e.accepted = true;
            }
        }
        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 12
            Row {
                spacing: 10
                Sym { code: Icons.gamepadVariant; font.pixelSize: Theme.px(18); color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Games.currentName || Tr.t("Game HUD")
                    font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text
                }
            }
            Text { text: Tr.t("Frame limit") + (Games.current ? "  ·  " + Tr.t("saved for this game") : ""); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
            Segmented {
                width: parent.width
                options: ["Off", "30", "60", "90", "120", "144", "Screen"]
                current: Math.max(0, win.steps.indexOf(win.limit))
                onPicked: i => win.pick(win.steps[i])
            }
            Text {
                text: Games.hudLine(win.p)
                font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted
            }
        }
    }
}
