import QtQuick
import qs.theme
import qs.components

// One calculator key: 90 x 64 (wide 0 spans two), operators tinted blue,
// "=" solid blue.
Rectangle {
    id: k
    property string label: ""
    property bool wide: false
    property bool op: false
    property bool primary: false
    property bool small: false
    signal hit()
    width: wide ? 190 : 90; height: small ? 56 : 64; radius: 18
    color: primary ? Theme.accent : op ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, h.hovered ? 0.24 : 0.16) : (h.hovered ? Theme.ink(0.12) : Theme.ink(0.07))
    scale: tap.pressed ? 0.95 : 1
    Behavior on scale { enabled: !Theme.reduceMotion; Spring { unit: true } }
    Text {
        anchors.centerIn: parent
        text: k.label
        font.family: Theme.font; font.pixelSize: k.small ? 17 : 24; font.weight: k.primary ? Font.DemiBold : Font.Normal
        color: k.primary ? Theme.accentInk : k.op ? Theme.accent : Theme.text
    }
    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: k.hit() }
}
