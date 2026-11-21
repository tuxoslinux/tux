import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// Snap layouts (Super + Z, SPEC "Window management"): six layouts as small
// screens; hovering a zone shows where the window will go on the real
// screen (zone preview), a click puts the window there (floating, exact
// size, 12 px gaps, under the bar). Esc closes.
OverlayWindow {
    id: ov
    name: "snap"
    dimAlpha: 0.22

    readonly property string addr: Shell.overlayArg && Shell.overlayArg.addr ? Shell.overlayArg.addr : ""
    readonly property string title: Shell.overlayArg && Shell.overlayArg.title ? Shell.overlayArg.title : ""
    property var hoverZone: null

    readonly property var layouts: [
        [[0, 0, 1 / 2, 1], [1 / 2, 0, 1 / 2, 1]],
        [[0, 0, 1 / 3, 1], [1 / 3, 0, 1 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
        [[0, 0, 2 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
        [[0, 0, 1 / 3, 1], [1 / 3, 0, 2 / 3, 1]],
        [[0, 0, 1 / 2, 1], [1 / 2, 0, 1 / 2, 1 / 2], [1 / 2, 1 / 2, 1 / 2, 1 / 2]],
        [[0, 0, 1 / 2, 1 / 2], [1 / 2, 0, 1 / 2, 1 / 2], [0, 1 / 2, 1 / 2, 1 / 2], [1 / 2, 1 / 2, 1 / 2, 1 / 2]]
    ]

    // the usable area: under the bar, 12 px from the edges; 12 px between zones
    readonly property int gap: 12
    readonly property real areaX: gap
    readonly property real areaY: Theme.barTop + Theme.barHeight + gap
    readonly property real areaW: width - 2 * gap
    readonly property real areaH: height - areaY - gap
    function rect(z) {
        const l = z[0] > 0.001, r = z[0] + z[2] < 0.999, t = z[1] > 0.001, b = z[1] + z[3] < 0.999;
        const x = areaX + z[0] * areaW + (l ? gap / 2 : 0);
        const y = areaY + z[1] * areaH + (t ? gap / 2 : 0);
        return Qt.rect(Math.round(x), Math.round(y),
                       Math.round(z[2] * areaW - (l ? gap / 2 : 0) - (r ? gap / 2 : 0)),
                       Math.round(z[3] * areaH - (t ? gap / 2 : 0) - (b ? gap / 2 : 0)));
    }
    function place(z) {
        if (!addr) { ov.close(); return; }
        const r = rect(z);
        const sx = ov.screen ? ov.screen.x : 0, sy = ov.screen ? ov.screen.y : 0;
        const w = `window = "address:${addr}"`;
        ov.close();
        Shell.dispatch(`(function()
            tux_float("address:${addr}")
            hl.dispatch(hl.dsp.window.resize({ x = ${r.width}, y = ${r.height}, exact = true, ${w} }))
            hl.dispatch(hl.dsp.window.move({ x = ${sx + r.x}, y = ${sy + r.y}, exact = true, ${w} }))
            return hl.dsp.no_op() end)()`, "");
    }

    onOpened: { hoverZone = null; keyCatcher.forceActiveFocus(); }
    Item { id: keyCatcher; focus: true; Keys.onEscapePressed: ov.close() }

    // zone preview on the real screen
    Rectangle {
        visible: ov.hoverZone !== null
        readonly property rect r: ov.hoverZone ? ov.rect(ov.hoverZone) : Qt.rect(0, 0, 0, 0)
        x: r.x; y: r.y; width: r.width; height: r.height
        radius: 18
        color: Theme.accentFill
        border.width: 2
        border.color: Theme.accentLine
        Behavior on x { enabled: !Theme.reduceMotion; Spring {} }
        Behavior on y { enabled: !Theme.reduceMotion; Spring {} }
        Behavior on width { enabled: !Theme.reduceMotion; Spring {} }
        Behavior on height { enabled: !Theme.reduceMotion; Spring {} }
    }

    Card {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barTop + Theme.barHeight + 24
        width: grid.implicitWidth + 40
        height: col.implicitHeight + 36
        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; topMargin: 16 }
            spacing: 12
            Text {
                text: ov.addr ? "Snap " + (ov.title || "the window") : "Open a window first"
                width: parent.width
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text
            }
            Grid {
                id: grid
                columns: 3
                spacing: 12
                Repeater {
                    model: ov.layouts
                    delegate: Rectangle {
                        id: mini
                        required property var modelData
                        width: 168; height: 105; radius: 12
                        color: Theme.fill
                        border.width: 1; border.color: Theme.glassLine
                        Repeater {
                            model: mini.modelData
                            delegate: Rectangle {
                                required property var modelData
                                x: 6 + modelData[0] * (mini.width - 12) + (modelData[0] > 0.001 ? 2 : 0)
                                y: 6 + modelData[1] * (mini.height - 12) + (modelData[1] > 0.001 ? 2 : 0)
                                width: modelData[2] * (mini.width - 12) - (modelData[0] > 0.001 ? 2 : 0) - (modelData[0] + modelData[2] < 0.999 ? 2 : 0)
                                height: modelData[3] * (mini.height - 12) - (modelData[1] > 0.001 ? 2 : 0) - (modelData[1] + modelData[3] < 0.999 ? 2 : 0)
                                radius: 7
                                color: zh.hovered ? Theme.accent : Theme.ink(0.10)
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                HoverHandler { id: zh; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) ov.hoverZone = modelData; else if (ov.hoverZone === modelData) ov.hoverZone = null }
                                TapHandler { onTapped: ov.place(modelData) }
                            }
                        }
                    }
                }
            }
            Text {
                text: Tr.t("Hover a zone to see it · click to snap · Esc closes")
                font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted
            }
        }
    }
}
