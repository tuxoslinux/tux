import QtQuick
import QtQuick.Shapes
import qs.theme

// A panel that "drops out" of the bar like a droplet (SPEC): a rounded
// glass panel hanging from the bar on a liquid, hourglass-shaped neck.
// neckX is the neck's centre in this item's coordinates; progress (0..1)
// grows the panel downwards. Children go into the panel's content area.
Item {
    id: drop

    property real neckX: width / 2
    property real neckWidth: 110
    property real panelHeight: 400
    property real progress: 0
    property real radius: Theme.panelRadius
    // grows upwards from something below it (the dock) instead of hanging from the bar
    property bool up: false
    readonly property real neckHeight: 32
    default property alias content: body.data

    implicitHeight: panelHeight
    height: neckHeight + (panelHeight - neckHeight) * progress
    opacity: Math.min(1, progress * 2.5)

    // outline: the same path as the approved mockup (dev/../mockups)
    readonly property string path: {
        const W = width, H = Math.max(height, neckHeight + 2 * radius + 1), r = radius, t = neckHeight;
        const cx = neckX, n = neckWidth / 2, nt = n + 22, fl = n + 30;
        return `M ${cx - nt} -1 C ${cx - n} -1 ${cx - n} ${t * 0.3} ${cx - n} ${t * 0.5} `
            + `C ${cx - n} ${t * 0.75} ${cx - n - 12} ${t} ${cx - fl} ${t} `
            + `L ${r} ${t} A ${r} ${r} 0 0 0 0 ${t + r} L 0 ${H - r} A ${r} ${r} 0 0 0 ${r} ${H} `
            + `L ${W - r} ${H} A ${r} ${r} 0 0 0 ${W} ${H - r} L ${W} ${t + r} A ${r} ${r} 0 0 0 ${W - r} ${t} `
            + `L ${cx + fl} ${t} C ${cx + n + 12} ${t} ${cx + n} ${t * 0.75} ${cx + n} ${t * 0.5} `
            + `C ${cx + n} ${t * 0.3} ${cx + n} -1 ${cx + nt} -1 Z`;
    }

    Shape {
        anchors.fill: parent
        transform: Scale { origin.y: drop.height / 2; yScale: drop.up ? -1 : 1 }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.glassPanel
            strokeColor: Theme.glassLine
            strokeWidth: 1
            PathSvg { path: drop.path }
        }
    }

    Item {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: drop.up ? 0 : drop.neckHeight; bottom: parent.bottom; bottomMargin: drop.up ? drop.neckHeight : 0 }
        clip: true
        opacity: Math.max(0, (drop.progress - 0.45) / 0.55)
    }
}
