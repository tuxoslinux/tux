import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.theme
import qs.services

// The Tux at the left of the bar (opens the launcher). Seasonal Tux (SPEC
// polish, can be turned off): a red hat in December, a pumpkin on Halloween.
Item {
    id: tb
    property string screenName: ""
    width: 34; height: Theme.itemHeight
    SystemClock { id: day; precision: SystemClock.Hours }
    readonly property bool december: Prefs.seasonalTux && day.date.getMonth() === 11
    readonly property bool halloween: Prefs.seasonalTux && day.date.getMonth() === 9 && day.date.getDate() >= 30
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: hovered ? Shell.showTip(`${Tr.t("Apps")}  <font color="${Theme.muted}">Super</font>`, tb.screenName, Theme.edge + 25) : Shell.hideTip()
    }
    TapHandler { onTapped: Shell.toggleOverlay("launcher") }
    Image {
        anchors.centerIn: parent
        source: Qt.resolvedUrl("../assets/tux.png")
        sourceSize: Qt.size(128, 128)   // sharp up to 4K scale factors
        width: 22; height: 22
        smooth: true
        mipmap: true
    }
    // Santa hat
    Shape {
        visible: tb.december
        x: 12; y: 4; width: 16; height: 12
        preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "#e5484d"; strokeColor: "transparent"; PathSvg { path: "M 1 10 C 4 2 10 0 14 4 L 12 6 C 9 4 6 6 5 10 Z" } }
        ShapePath { fillColor: "white"; strokeColor: "transparent"; PathSvg { path: "M 0 9 L 7 9 Q 8 11 7 12 L 0 12 Q -1 10.5 0 9 Z" } }
        ShapePath { fillColor: "white"; strokeColor: "transparent"; PathSvg { path: "M 13 3 A 2 2 0 1 1 13.01 3 Z" } }
    }
    // pumpkin
    Rectangle {
        visible: tb.halloween
        x: 20; y: 20; width: 10; height: 8; radius: 4
        color: "#ff8a2a"
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: -2; width: 2; height: 3; color: "#4c7a2a" }
    }
}
