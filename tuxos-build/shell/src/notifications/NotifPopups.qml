import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// Notification pop-ups and shell toasts: a column of glass cards top right,
// under the bar, on the focused screen (mockup shell2/01-toast).
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Shell.focusedScreen) || Quickshell.screens[0]
    anchors { top: true; right: true }
    margins { top: Theme.barTop + Theme.barHeight + 12; right: Theme.edge }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 400
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"
    visible: Toasts.list.length > 0 || Notifs.popups.length > 0
    WlrLayershell.namespace: "tuxos-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand   // reply fields
    // explicit geometry: a Region bound to an item that starts empty (no
    // pop-ups yet) did not follow it, so the first pop-up took no clicks
    mask: Region { x: column.x; y: column.y; width: column.width; height: column.height }

    Column {
        id: column
        width: 400
        spacing: 8
        move: Transition { NumberAnimation { properties: "y"; duration: Theme.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
        Repeater {
            model: Toasts.list
            delegate: NotifCard {
                required property var modelData
                toast: modelData
                onDone: Toasts.drop(modelData.id)
            }
        }
        Repeater {
            model: Notifs.popups
            delegate: NotifCard {
                required property var modelData
                notif: modelData
                onDone: Notifs.dropPopup(modelData)
                Connections { target: modelData; function onClosed() { Notifs.dropPopup(modelData); } }
            }
        }
    }
}
