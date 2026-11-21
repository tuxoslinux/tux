import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// Virtual desktops (SPEC: 9 desktops; 1-5 always shown, 6-9 only while in
// use; desktop 6 appears by itself once 1-5 all have windows). The current
// one is a wide blue pill that slides; used ones are white, empty ones dim.
// Hover highlights the group; the mouse wheel moves to the previous / next.
Rectangle {
    id: root

    property string screenName: ""
    // several monitors (SPEC): desktops 1-5 live on the main screen (the one
    // at 0,0), 6-9 on the second; each bar shows its own screen's desktops
    readonly property var monitors: Hyprland.monitors.values
    readonly property bool multi: monitors.length > 1
    readonly property var monitor: monitors.find(m => m.name === screenName) || null
    readonly property var mainMonitor: monitors.find(m => m.x === 0 && m.y === 0) || monitors[0] || null
    readonly property bool isMain: !multi || monitor === mainMonitor
    readonly property int current: multi && monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id
                                   : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
    readonly property var all: Hyprland.workspaces.values

    function wsFor(n) {
        for (let i = 0; i < all.length; i++)
            if (all[i].id === n)
                return all[i];
        return null;
    }
    function used(n) {
        const ws = wsFor(n);
        return ws !== null && ws.toplevels.values.length > 0;
    }
    function onThisScreen(n) {
        const ws = wsFor(n);
        return ws !== null && ws.monitor === root.monitor;
    }
    readonly property var shown: {
        if (multi && !isMain) {
            // second (and further) screens: 6 always, 7-9 while in use, plus
            // any other desktop moved here
            let l = [];
            for (let n = 1; n <= 9; n++)
                if ((n === 6 && monitors.indexOf(monitor) === 1) || onThisScreen(n) || current === n) l.push(n);
            return l.length ? l : [current];
        }
        let list = [1, 2, 3, 4, 5];
        let allUsed = true;
        for (let n = 1; n <= 5; n++)
            if (!used(n)) allUsed = false;
        for (let n = 6; n <= 9; n++)
            if ((multi ? onThisScreen(n) : wsFor(n) !== null) || current === n || (n === 6 && allUsed && !multi))
                list.push(n);
        return list;
    }
    function go(n) {
        if (n < 1 || n > 9 || n === current)
            return;
        // Hyprland 0.57+ with a Lua config takes Lua dispatcher calls
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + n + " })");
        else
            Hyprland.dispatch("workspace " + n);
    }

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.itemHeight
    radius: 12
    color: hover.hovered ? Theme.accentFill : Theme.fill
    border.width: 1
    border.color: hover.hovered ? Qt.rgba(143 / 255, 184 / 255, 1, 0.25) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    // the sliding pill behind the current desktop
    Rectangle {
        id: pill
        property Item target: row.itemFor(root.current)
        x: target ? row.x + target.x : 0
        width: target ? target.width : 0
        y: (root.height - height) / 2
        height: 26
        radius: 9
        color: Theme.accent
        visible: target !== null
        Behavior on x { enabled: !Theme.reduceMotion; Spring {} }
        Behavior on width { enabled: !Theme.reduceMotion; Spring {} }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        function itemFor(n) {
            for (let i = 0; i < children.length; i++)
                if (children[i].num === n)
                    return children[i];
            return null;
        }
        Repeater {
            model: root.shown
            delegate: Item {
                required property int modelData
                readonly property int num: modelData
                readonly property bool isCurrent: num === root.current
                width: isCurrent ? 44 : 30
                height: 26
                Behavior on width { enabled: !Theme.reduceMotion; Spring {} }
                Rectangle {
                    // a window was just dropped here
                    anchors.fill: parent
                    radius: 9
                    color: Theme.accent
                    opacity: root.flash === parent.num ? 0.5 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.fade } }
                }
                Text {
                    anchors.centerIn: parent
                    text: parent.num
                    font.family: Theme.font
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.DemiBold
                    color: parent.isCurrent ? Theme.accentInk : (root.used(parent.num) ? Theme.text : Theme.dim)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                        if (m.button !== Qt.RightButton) { root.go(parent.num); return; }
                        openMenu();
                    }
                    // touch: long press = right click
                    onPressAndHold: m => { if (m.source !== Qt.MouseEventNotSynthesized) openMenu(); }
                    function openMenu() {
                        // right-click: name, wallpaper, bring the window here
                        const n = parent.num, p = mapToItem(null, width / 2, 0);
                        const scr = root.monitor ? root.monitor : Hyprland.focusedMonitor;
                        Shell.menu([
                            { label: Tr.t("Go to this desktop"), icon: Icons.arrowRight, run: () => root.go(n) },
                            { label: Tr.t("Move the window here"), icon: Icons.swapHorizontal, run: () => Shell.dispatch(`hl.dsp.window.move({ workspace = ${n}, follow = false })`, `movetoworkspacesilent ${n}`) },
                            { label: Tr.t("Name this desktop..."), icon: Icons.pencil, run: () => Apps.run(`${Prefs.settingsApp} --page desktop`) },
                            { label: Tr.t("Wallpaper for this desktop..."), icon: Icons.imageOutline, run: () => Apps.run(`${Prefs.settingsApp} --page appearance`) }
                        ], root.screenName, (scr ? scr.x : 0) + Theme.edge + p.x);
                    }
                    onContainsMouseChanged: {
                        if (containsMouse) {
                            const p = mapToItem(null, width / 2, 0);
                            const name = Prefs.desktopNames[String(parent.num)] || ("Desktop " + parent.num);
                            Shell.showTip(`${name}  <font color="${Theme.muted}">Super + ${parent.num}</font>`, root.screenName, Theme.edge + p.x);
                        } else Shell.hideTip();
                    }
                }
            }
        }
    }

    // a window dropped on a desktop number moves there (the pill flashes)
    property int flash: 0
    Timer { id: flashOff; interval: 700; onTriggered: root.flash = 0 }
    Connections {
        target: Shell
        function onWindowDropped(screenName, x, y, address) {
            if (screenName !== root.screenName || !address) return;
            if (y > Theme.barTop + Theme.barHeight + 8) return;
            for (let i = 0; i < row.children.length; i++) {
                const it = row.children[i];
                if (it.num === undefined) continue;
                const p = it.mapToItem(null, 0, 0);
                const x0 = Theme.edge + p.x;
                if (x < x0 - 2 || x > x0 + it.width + 2) continue;
                const a = `window = "address:${address}"`;
                Shell.dispatch(`hl.dsp.window.center({ ${a} })`, "");
                Shell.dispatch(`hl.dsp.window.move({ workspace = ${it.num}, follow = false, ${a} })`, `movetoworkspacesilent ${it.num},address:${address}`);
                root.flash = it.num;
                flashOff.restart();
                Toasts.show(Tr.f("Moved to {name}", { name: Prefs.desktopNames[String(it.num)] || Tr.t("Desktop ") + it.num }), "", Icons.swapHorizontal);
                return;
            }
        }
    }

    HoverHandler { id: hover }
    WheelHandler {
        acceptedDevices: PointerDevice.AllDevices
        onWheel: event => {
            const list = root.shown;
            const i = list.indexOf(root.current);
            if (event.angleDelta.y < 0 && i < list.length - 1) root.go(list[i + 1]);
            else if (event.angleDelta.y > 0 && i > 0) root.go(list[i - 1]);
        }
    }
}
