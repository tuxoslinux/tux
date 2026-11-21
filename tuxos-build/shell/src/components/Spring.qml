import QtQuick
import qs.theme

// TuxOS' one motion (SPEC "One motion system"): every movement and size
// change in the shell and its apps is this spring - interruptible (a new
// target keeps the current speed), about 220 ms to settle (measured: 16 /
// 0.9 reaches 1 % in ~222 ms; "unit" values settle in ~210 ms without
// overshoot). Hyprland's windows use a spring with the same feel
// (tuxSpring). Reduce motion turns the Behaviors off (instant moves).
SpringAnimation {
    property bool unit: false          // 0..1 values (scale, progress): no overshoot, fine epsilon
    spring: unit ? 20 : Theme.springStiffness
    damping: unit ? 1.0 : Theme.springDamping
    epsilon: unit ? 0.002 : 0.2
}
