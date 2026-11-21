import QtQuick
import qs.theme
import qs.components

// One launcher result: the top result is big (tile, name, description,
// "Enter to open"), the rest are compact rows with a tag on the right.
Rectangle {
    id: row
    property var item: ({})
    property bool big: false
    property bool selected: false
    signal clicked()

    height: big ? 92 : 56
    radius: big ? 20 : 14
    color: selected ? Theme.accentFill : (hover.hovered ? Theme.fill : "transparent")
    border.width: selected ? 1 : 0
    border.color: Theme.accentLine

    Item {
        id: lead
        width: row.big ? 64 : 40; height: width
        anchors { left: parent.left; leftMargin: row.big ? 14 : 14; verticalCenter: parent.verticalCenter }
        // a game: its cover art (2:3)
        Rectangle {
            visible: !!row.item.cover
            anchors.centerIn: parent
            height: parent.height; width: Math.round(height * 2 / 3)
            radius: 8; clip: true
            color: Theme.ink(0.08)
            Image { anchors.fill: parent; source: row.item.cover ? "file://" + row.item.cover : ""; sourceSize.height: 128; fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
        AppTile {
            visible: row.item.entry !== undefined && typeof row.item.icon !== "number" && !row.item.cover
            anchors.fill: parent
            size: parent.width
            entry: row.item.entry || null
            appId: row.item.entry ? row.item.entry.id : ""
        }
        Rectangle {
            visible: typeof row.item.icon === "number"
            anchors.fill: parent
            radius: Math.round(width * 0.29)
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.ink(0.17) }
                GradientStop { position: 1; color: Theme.ink(0.06) }
            }
            border.width: 1; border.color: Theme.ink(0.06)
            Sym { anchors.centerIn: parent; code: typeof row.item.icon === "number" ? row.item.icon : 0; font.pixelSize: Math.round(parent.width * 0.47) }
        }
    }

    Column {
        anchors { left: lead.right; leftMargin: 12; right: tag.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 4
        Text {
            width: parent.width
            text: Tr.t(row.item.title || "")
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: row.big ? 20 : 15
            font.weight: row.big ? Font.DemiBold : Font.Normal
            color: Theme.text
        }
        Text {
            width: parent.width
            visible: text.length > 0 && (row.big || row.item.tag === "Event" || row.item.tag === "Command" && false)
            text: Tr.t(row.item.subtitle || "")
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: row.big ? 14 : 12
            color: Theme.muted
        }
    }
    // "Will it run?" dot for games
    Rectangle {
        visible: row.item.badgeColor !== undefined
        anchors { right: tag.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        width: 8; height: 8; radius: 4
        color: row.item.badgeColor || "transparent"
    }
    Text {
        id: tag
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        text: Tr.t(row.big ? (row.item.hint || "Enter to open") : (row.item.tag || ""))
        font.family: Theme.font
        font.pixelSize: Theme.px(13)
        color: row.big ? Theme.accent : Theme.muted
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: row.clicked() }
}
