import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// The live-activity chip next to the clock (mockup desktop-v6-live-music):
// symbol, title – artist / site, elapsed / total, a thin progress line along
// the bottom; "+N" when more is going on. Hover opens the media droplet.
Item {
    id: chip
    property string screenName: ""
    readonly property var item: Activities.list.length ? Activities.list[0] : null
    readonly property int more: Activities.list.length - 1
    visible: item !== null
    implicitWidth: visible ? Math.min(460, row.implicitWidth + 28) : 0
    implicitHeight: Theme.itemHeight
    Behavior on implicitWidth { enabled: !Theme.reduceMotion; Spring {} }
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: hover.hovered || (Shell.panel === "media" && Shell.screenName === chip.screenName) ? Qt.rgba(143 / 255, 184 / 255, 1, 0.16) : Qt.rgba(143 / 255, 184 / 255, 1, 0.07)
        border.width: 1
        border.color: chip.item && chip.item.kind === "record" ? Qt.rgba(1, 0.48, 0.54, 0.5) : Theme.accentLine
    }
    Row {
        id: row
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 8
        Sym {
            code: chip.item ? chip.item.icon : 0
            color: chip.item ? chip.item.color : Theme.accent
            font.pixelSize: Theme.px(15)
            anchors.verticalCenter: parent.verticalCenter
            SequentialAnimation on opacity {
                running: chip.item !== null && chip.item.kind === "record"
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
            }
        }
        Text {
            text: chip.item ? chip.item.title : ""
            font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 200)
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: chip.item !== null && chip.item.sub !== ""
            text: "–"
            font.family: Theme.font; font.pixelSize: Theme.px(14)
            color: Theme.dim
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: chip.item !== null && chip.item.sub !== ""
            text: chip.item ? chip.item.sub : ""
            font.family: Theme.font; font.pixelSize: Theme.px(14)
            color: Theme.muted
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 120)
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: text !== ""
            text: chip.item ? chip.item.right : ""
            font.family: Theme.font; font.pixelSize: Theme.px(13)
            font.features: { "tnum": 1 }
            color: Theme.muted
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            visible: chip.more > 0
            width: plus.implicitWidth + 12; height: 20; radius: 10
            color: Theme.accentFill
            anchors.verticalCenter: parent.verticalCenter
            Text { id: plus; anchors.centerIn: parent; text: "+" + chip.more; font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; color: Theme.accent }
        }
    }
    // progress line along the bottom
    Rectangle {
        visible: chip.item !== null && chip.item.progress >= 0
        anchors { left: parent.left; leftMargin: 8; bottom: parent.bottom; bottomMargin: 4 }
        width: (parent.width - 20) * (chip.item ? Math.max(0, chip.item.progress) : 0)
        height: 2; radius: 1
        color: Theme.accent
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            Shell.mediaHovered = hovered;
            if (hovered) {
                const p = chip.mapToItem(null, chip.width / 2, 0);
                Shell.open("media", chip.screenName, Theme.edge + p.x, chip.width);
            }
        }
    }
}
