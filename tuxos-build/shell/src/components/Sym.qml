import QtQuick
import qs.theme

// A symbol from the Nerd Font, e.g. Sym { code: 0xf05a9 } (Wi-Fi).
Text {
    property int code: 0
    text: String.fromCodePoint(code)
    font.family: Theme.symbols
    font.pixelSize: Theme.px(16)
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
