import QtQuick
import qs.theme

// A button: glass by default, blue when primary, red when danger.
Rectangle {
    id: b
    property string text: ""
    property int icon: 0
    property bool primary: false
    property bool danger: false
    property bool enabled2: true
    signal clicked()
    // screen readers (Orca over AT-SPI)
    Accessible.role: Accessible.Button
    Accessible.name: Tr.t(text)
    Accessible.onPressAction: if (enabled2) clicked()
    width: row.implicitWidth + 28; height: 36; radius: 11
    opacity: enabled2 ? 1 : 0.45
    color: primary ? Theme.accent : danger ? Qt.rgba(1, 0.48, 0.54, h.hovered ? 0.30 : 0.18) : (h.hovered ? Theme.fillHover : Theme.ink(0.06))
    // keyboard: Tab reaches it (a blue ring), Space / Enter presses it
    activeFocusOnTab: true
    border.width: activeFocus ? 2 : (primary ? 0 : 1); border.color: activeFocus ? Theme.accent : Theme.glassLine
    Keys.onPressed: e => { if ((e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && b.enabled2) { b.clicked(); e.accepted = true; } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text { visible: b.icon !== 0; anchors.verticalCenter: parent.verticalCenter; text: String.fromCodePoint(b.icon || 32); font.family: Theme.symbols; font.pixelSize: Theme.px(14); color: b.primary ? Theme.accentInk : b.danger ? Theme.danger : Theme.text }
        Text { anchors.verticalCenter: parent.verticalCenter; text: Tr.t(b.text); font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: b.primary ? Theme.accentInk : b.danger ? Theme.danger : Theme.text }
    }
    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: if (b.enabled2) b.clicked() }
}
