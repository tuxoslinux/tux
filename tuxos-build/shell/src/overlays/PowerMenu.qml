import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Power menu (Super + X, Ctrl + Alt + Del, the bar's power button; mockup
// shell2/05-power): who is logged in and the uptime, five big buttons with
// one-letter keys (L lock, O log out, S sleep, R restart, P shut down),
// arrows + Enter, then "Restart into the boot menu" and "Switch user".
OverlayWindow {
    id: ov
    name: "power"

    property int sel: 0
    property string uptime: ""
    readonly property var actions: [
        { key: "L", label: Tr.t("Lock"), icon: Icons.lock, run: () => Power.lock() },
        { key: "O", label: Tr.t("Log out"), icon: Icons.logout, run: () => Shell.showOverlay("shutdown", "logout") },
        { key: "S", label: Tr.t("Sleep"), icon: Icons.weatherNight, run: () => Power.suspend() },
        { key: "R", label: Tr.t("Restart"), icon: Icons.restart, run: () => Shell.showOverlay("shutdown", "reboot") },
        { key: "P", label: Tr.t("Shut down"), icon: Icons.power, run: () => Shell.showOverlay("shutdown", "poweroff"), danger: true }
    ]
    function pick(i) {
        const a = actions[i];
        if (["R", "P", "O"].indexOf(a.key) === -1) ov.close();   // these go on to the shutdown screen
        a.run();
    }
    onOpened: { sel = 0; up.running = true; keyCatcher.forceActiveFocus(); }
    Connections {
        target: Shell
        enabled: Shell.overlay === "power"
        function onPad(w) {
            if (w === "left" || w === "up") ov.sel = (ov.sel + 4) % 5;
            else if (w === "right" || w === "down") ov.sel = (ov.sel + 1) % 5;
            else if (w === "a") ov.pick(ov.sel);
            else if (w === "b") ov.close();
        }
    }

    Process {
        id: up
        command: ["awk", "{print int($1)}", "/proc/uptime"]
        // in the shell's language: "up 1 h 17 min" / "работи от 1 ч 17 мин"
        stdout: StdioCollector { onStreamFinished: { const t = parseInt(text) || 0, h = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60); ov.uptime = h > 0 ? Tr.f("up {h} h {m} min", { h: h, m: m }) : Tr.f("up {m} min", { m: m }); } }
    }

    Item {
        id: keyCatcher
        focus: true
        Keys.onPressed: event => {
            const k = event.text.toUpperCase();
            const i = ov.actions.findIndex(a => a.key === k);
            if (i !== -1) { ov.pick(i); event.accepted = true; }
            else if (event.key === Qt.Key_Left) { ov.sel = (ov.sel + 4) % 5; event.accepted = true; }
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { ov.sel = (ov.sel + 1) % 5; event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { ov.pick(ov.sel); event.accepted = true; }
            else if (event.key === Qt.Key_Escape) { ov.close(); event.accepted = true; }
        }
    }

    Card {
        anchors.centerIn: parent
        width: row.implicitWidth + 48
        height: col.implicitHeight + 44
        Column {
            id: col
            anchors.centerIn: parent
            spacing: 16
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `${Prefs.firstName} · ${ov.uptime}`
                font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted
            }
            Row {
                id: row
                spacing: 12
                Repeater {
                    model: ov.actions
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: ov.sel === index || bh.hovered
                        width: 104; height: 112; radius: 20
                        color: modelData.danger ? Qt.rgba(1, 0.48, 0.54, on ? 0.30 : 0.16) : (on ? Theme.accentFill : Theme.fill)
                        border.width: 1
                        border.color: modelData.danger ? Qt.rgba(1, 0.48, 0.54, 0.45) : (on ? Theme.accentLine : Theme.glassLine)
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Sym { anchors.horizontalCenter: parent.horizontalCenter; code: modelData.icon; font.pixelSize: Theme.px(26); color: modelData.danger ? Theme.danger : Theme.text }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.text }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.key; font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.dim }
                        }
                        HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) ov.sel = index }
                        TapHandler { onTapped: ov.pick(index) }
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Repeater {
                    model: [[Icons.restart, "Restart into the boot menu", () => Power.rebootToMenu()],
                            [Icons.accountSwitch, "Switch user", () => { ov.close(); Power.switchUser(); }]]
                    delegate: Rectangle {
                        required property var modelData
                        width: lr.implicitWidth + 24; height: 34; radius: 11
                        color: lh.hovered ? Theme.fillHover : Theme.fill
                        border.width: 1; border.color: Theme.glassLine
                        Row {
                            id: lr
                            anchors.centerIn: parent; spacing: 4
                            Sym { code: modelData[0]; font.pixelSize: Theme.px(14); color: Theme.muted }
                            Text { text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text }
                        }
                        HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: modelData[2]() }
                    }
                }
            }
        }
    }
}
