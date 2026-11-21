import QtQuick
import qs.theme
import qs.components
import qs.services

// One app as a rounded square in the shell's one style (light glass tile,
// white symbol), used by the dock, launcher and switcher.
Rectangle {
    id: tile
    property var entry: null
    property string appId: ""
    property int size: 58
    property bool running: false
    Accessible.role: Accessible.Button
    Accessible.name: entry ? entry.name : appId
    property bool focused: false
    property bool glow: false
    readonly property var symbol: AppSymbols.forEntry(entry, appId)

    width: size; height: size
    radius: Math.round(size * 0.29)
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, tileHover.hovered ? 0.24 : 0.17) }
        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, tileHover.hovered ? 0.10 : 0.06) }
    }
    border.width: 1
    border.color: glow ? Theme.accent : Theme.ink(0.06)

    Text {
        anchors.centerIn: parent
        text: tile.symbol.code !== undefined ? String.fromCodePoint(tile.symbol.code) : tile.symbol.letter
        font.family: tile.symbol.code !== undefined ? Theme.symbols : Theme.font
        font.pixelSize: tile.symbol.code !== undefined ? Math.round(tile.size * 0.47) : Math.round(tile.size * 0.42)
        font.weight: Font.DemiBold
        color: Theme.text
    }

    // running dot / focused line under the tile
    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 4 }
        visible: tile.running || tile.focused
        width: tile.focused ? 16 : 5
        height: 5; radius: 2.5
        color: tile.focused ? Theme.accent : Qt.rgba(244 / 255, 247 / 255, 251 / 255, 0.7)
        Behavior on width { enabled: !Theme.reduceMotion; Spring {} }
    }
    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
}
