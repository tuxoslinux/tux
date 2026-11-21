import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.components

// Password field of the lock and login screens (SPEC "Password feedback"):
// wrong: shakes ~400 ms (damped), red outline, "Try again", cleared, keeps
// focus. Right: shrinks into a glowing blue round lock whose shackle lifts
// and swings open while two rings pulse out (unlocking(): ~600 ms, then
// unlocked()).
Item {
    id: bar

    property string placeholder: Tr.t("Password")
    property bool busy: false
    property string message: ""             // PAM / fingerprint info under the field
    readonly property alias text: input.text
    signal submitted(string password)
    signal unlocked()

    width: 340
    height: 52 + 28

    function focusField() { input.forceActiveFocus(); }
    function wrong() {
        input.text = "";
        busy = false;
        red.restart();
        shake.restart();
        input.forceActiveFocus();
    }
    property bool opening: false
    function success() { busy = false; opening = true; openAnim.restart(); }

    // ---- the field
    Rectangle {
        id: field
        width: bar.opening ? 56 : parent.width
        height: bar.opening ? 56 : 52
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.opening ? -2 : 0
        radius: height / 2
        color: bar.opening ? Theme.accent : Qt.rgba(Theme.glassBase.r, Theme.glassBase.g, Theme.glassBase.b, Theme.lite ? 0.95 : (Theme.light ? 0.7 : 0.55))
        border.width: bar.opening ? 0 : 1
        border.color: redFlash > 0 ? Qt.rgba(1, 0.48, 0.54, redFlash) : (input.activeFocus ? Theme.accentLine : Theme.glassLine)
        property real redFlash: 0
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }
        Behavior on color { ColorAnimation { duration: 220 } }
        transform: Translate { id: shakeX; x: 0 }

        // glow while opening
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 28; height: parent.height + 28; radius: width / 2
            color: "transparent"
            border.width: 10
            border.color: Qt.rgba(143 / 255, 184 / 255, 1, 0.18)
            visible: bar.opening
        }

        TextInput {
            id: input
            anchors { left: parent.left; leftMargin: 20; right: go.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            visible: !bar.opening
            echoMode: TextInput.Password
            passwordCharacter: "●"
            font.family: Theme.font
            font.pixelSize: Theme.px(15)
            font.letterSpacing: 5
            color: Theme.text
            clip: true
            enabled: !bar.busy && !bar.opening
            focus: true
            onAccepted: if (text.length > 0) { bar.busy = true; bar.submitted(text); }
            Text {
                visible: input.text.length === 0
                text: bar.placeholder
                font.family: Theme.font; font.pixelSize: Theme.px(15); font.letterSpacing: 0
                color: Theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Rectangle {
            id: go
            visible: !bar.opening
            width: 40; height: 40; radius: 20
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            color: Theme.accent
            opacity: bar.busy ? 0.6 : 1
            Sym { anchors.centerIn: parent; code: Icons.arrowRight; color: Theme.accentInk; font.pixelSize: Theme.px(19) }
            SequentialAnimation on scale {
                running: bar.busy
                loops: Animation.Infinite
                NumberAnimation { to: 0.86; duration: 380; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 380; easing.type: Easing.InOutSine }
                onStopped: go.scale = 1
            }
            TapHandler { onTapped: input.accepted() }
        }

        // the lock drawn in the round button
        Item {
            id: lock
            visible: bar.opening
            anchors.centerIn: parent
            width: 22; height: 26
            Rectangle {
                id: body
                anchors.bottom: parent.bottom
                width: 22; height: 16; radius: 4
                color: Theme.accentInk
                Rectangle { anchors.centerIn: parent; width: 4; height: 6; radius: 2; color: Theme.accent }
            }
            Shape {
                id: shackle
                width: 16; height: 14
                x: 4; y: 0
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.accentInk
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: "M 1.5 14 L 1.5 7 A 6.5 6.5 0 0 1 14.5 7 L 14.5 14" }
                }
                transform: [
                    Translate { id: lift; y: 0 },
                    Rotation { id: swing; origin.x: 14.5; origin.y: 12; angle: 0 }
                ]
            }
        }
        // two rings pulse out
        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                id: ring
                anchors.centerIn: parent
                width: 56; height: 56; radius: 28
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                opacity: 0
                visible: bar.opening
                ParallelAnimation {
                    id: pulse
                    NumberAnimation { target: ring; property: "scale"; from: 1; to: 2.6; duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier }
                    NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier }
                }
                Connections {
                    target: bar
                    function onRingsGo() { ringDelay.interval = ring.index * 140; ringDelay.restart(); }
                }
                Timer { id: ringDelay; onTriggered: pulse.restart() }
            }
        }
    }
    signal ringsGo()

    // "Try again" / PAM messages
    Text {
        anchors { top: field.bottom; topMargin: 8; horizontalCenter: field.horizontalCenter }
        visible: !bar.opening
        text: field.redFlash > 0.01 ? "Try again" : bar.message
        font.family: Theme.font; font.pixelSize: Theme.px(13)
        color: field.redFlash > 0.01 ? Theme.danger : Theme.muted
    }

    // ---- animations
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: 12; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: -9; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: 6; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: -3; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 70; easing.type: Easing.OutQuad }
    }
    SequentialAnimation {
        id: red
        NumberAnimation { target: field; property: "redFlash"; to: 1; duration: 80 }
        PauseAnimation { duration: 1600 }
        NumberAnimation { target: field; property: "redFlash"; to: 0; duration: 400 }
    }
    SequentialAnimation {
        id: openAnim
        PauseAnimation { duration: 230 }                       // bar becomes the lock
        NumberAnimation { target: lift; property: "y"; to: -5; duration: 140; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier }   // shackle lifts
        ScriptAction { script: bar.ringsGo() }
        NumberAnimation { target: swing; property: "angle"; to: 38; duration: 180; easing.type: Easing.OutBack }  // swings open
        PauseAnimation { duration: 80 }
        ScriptAction { script: bar.unlocked() }
    }
    function reset() {
        opening = false; busy = false; lift.y = 0; swing.angle = 0; input.text = ""; field.redFlash = 0;
    }
}
