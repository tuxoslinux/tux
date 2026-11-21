import QtQuick
import QtQuick.Effects
import Quickshell
import qs.theme
import qs.components

// The depth effect (lock and login screen): the date and a big clock sit
// behind the wallpaper's subject. `mask` is the subject's mask (white =
// subject, components/DepthMask.qml); the subject is drawn again from
// `backdrop`, cut out by the mask, in front of the clock.
Item {
    id: dc
    property Item backdrop: null
    property string mask: ""
    property date date: new Date()
    property real contentOpacity: 1
    readonly property bool on: mask !== ""
    visible: on

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: dc.height * 0.25
        opacity: dc.contentOpacity
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.date(dc.date, "dddd, d MMMM")
            font.family: Theme.font; font.pixelSize: Theme.px(22); font.weight: Font.DemiBold; color: "#dce3ee"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.StyledText
            text: Qt.formatTime(dc.date, "HH") + `<font color="${Theme.accent}">:</font>` + Qt.formatTime(dc.date, "mm")
            font.family: Theme.font; font.pixelSize: Math.round(dc.height * 0.28); font.weight: Font.Bold; font.letterSpacing: -6
            color: "#f4f7fb"
        }
    }
    Image {
        id: maskImg
        anchors.fill: parent
        visible: false
        source: dc.on ? "file://" + dc.mask : ""
        fillMode: Image.PreserveAspectCrop
        cache: false
        layer.enabled: dc.on
    }
    // the subject, in front of the clock
    MultiEffect {
        anchors.fill: parent
        visible: dc.on && dc.backdrop !== null
        source: dc.backdrop
        maskEnabled: true
        maskSource: maskImg
        maskThresholdMin: 0.3
        maskSpreadAtMin: 0.3
    }
}
