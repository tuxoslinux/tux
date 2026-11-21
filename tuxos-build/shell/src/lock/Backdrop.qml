import QtQuick
import QtQuick.Effects
import Quickshell
import qs.theme
import qs.services

// The blurred, dimmed wallpaper behind the login and lock card. `amount`
// (1 -> 0) clears the blur and dim as the screen unlocks. Lite mode: no
// blur, only the dim.
Item {
    id: bd
    property real amount: 1
    property string source: "file://" + Quickshell.env("HOME") + "/.local/share/tuxos/wallpaper.png"
    property bool lite: false
    property real blurScale: 1           // less blur (lock screen depth effect)

    Rectangle { anchors.fill: parent; color: "#0b0d11" }
    Image {
        id: wp
        anchors.fill: parent
        source: bd.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        sourceSize: Qt.size(Math.min(1920, bd.width), Math.min(1920, bd.width) * bd.height / Math.max(1, bd.width))
        visible: bd.lite
        cache: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wp
        visible: !bd.lite
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: bd.amount * bd.blurScale
        saturation: -0.15 * bd.amount
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.38 * bd.amount) }
}
