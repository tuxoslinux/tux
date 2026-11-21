import QtQuick
import Quickshell
import qs.theme
import qs.services

// Time and date in the middle of the bar (the calendar droplet opens on
// hover; added with the droplet component).
Item {
    id: root
    property string screenName: ""
    property alias hovered: hover.hovered
    implicitWidth: label.implicitWidth + 28
    implicitHeight: Theme.itemHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: hover.hovered || (Shell.panel === "calendar" && Shell.screenName === root.screenName) ? Theme.accentFill : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    Row {
        id: label
        anchors.centerIn: parent
        spacing: 8
        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Theme.font
            font.pixelSize: Theme.px(15)
            font.weight: Font.DemiBold
            color: Theme.text
        }
        Text {
            text: Tr.date(clock.date, "ddd d MMM")
            font.family: Theme.font
            font.pixelSize: Theme.px(15)
            font.weight: Font.Medium
            color: Theme.muted
        }
    }
    // wheel over the clock = previous / next desktop
    WheelHandler {
        acceptedDevices: PointerDevice.AllDevices
        onWheel: event => {
            const d = event.angleDelta.y > 0 ? "e-1" : "e+1";
            Shell.dispatch(`hl.dsp.focus({ workspace = "${d}" })`, `workspace ${d}`);
        }
    }
    // where the clock is: droplets that open by themselves hang from it
    onXChanged: Qt.callLater(() => { const p = root.mapToItem(null, root.width / 2, 0); Shell.clockX = Theme.edge + p.x; })
    Component.onCompleted: Qt.callLater(() => { const p = root.mapToItem(null, root.width / 2, 0); Shell.clockX = Theme.edge + p.x; })
    HoverHandler {
        id: hover
        onHoveredChanged: {
            Shell.clockHovered = hovered;
            if (hovered) {
                const p = root.mapToItem(null, root.width / 2, 0);
                Shell.open("calendar", root.screenName, Theme.edge + p.x, root.width);
            }
        }
    }
}
