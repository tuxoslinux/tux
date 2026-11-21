import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services

// Optional rounded screen corners (Settings > Desktop & dock): four small
// black curves above everything; they never take input.
Variants {
    model: Prefs.screenCorners ? Quickshell.screens : []
    delegate: Component {
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "tuxos-corners"
            WlrLayershell.layer: WlrLayer.Overlay
            Repeater {
                model: 4
                delegate: Shape {
                    required property int index
                    readonly property int r: 14
                    width: r; height: r
                    x: index % 2 === 0 ? 0 : parent.width - r
                    y: index < 2 ? 0 : parent.height - r
                    rotation: [0, 90, 270, 180][index]
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath { fillColor: "black"; strokeColor: "transparent"
                        PathSvg { path: "M 0 0 L 14 0 A 14 14 0 0 0 0 14 Z" } }
                }
            }
        }
    }
}
