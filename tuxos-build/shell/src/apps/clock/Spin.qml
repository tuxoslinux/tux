import QtQuick
import qs.theme

// A two-digit number picker (wheel or click), for alarm times.
Rectangle {
    property int value: 0
    property int max: 59
    signal changed(int v)
    width: 56; height: 36; radius: 10; color: Theme.ink(0.06); border.width: 1; border.color: Theme.glassLine
    Text { anchors.centerIn: parent; text: String(parent.value).padStart(2, "0"); font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text }
    WheelHandler { acceptedDevices: PointerDevice.AllDevices; onWheel: e => parent.changed((parent.value + (e.angleDelta.y > 0 ? 1 : -1) + parent.max + 1) % (parent.max + 1)) }
    TapHandler { onTapped: parent.changed((parent.value + 1) % (parent.max + 1)) }
}
