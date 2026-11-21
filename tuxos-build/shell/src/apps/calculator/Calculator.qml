import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// Calculator (mockup apps/06-calc): Basic, Scientific and Convert
// (currency online with an offline cache, length, area, volume, mass,
// temperature, speed, data, energy, pressure, time, angle, fuel, power).
// The keyboard works everywhere: digits, + - * / ^ ( ), Enter, Backspace, Esc.
AppWindow {
    id: app
    appName: "Calculator"
    appIcon: 0xf00ec
    implicitWidth: widths[mode]
    implicitHeight: 660

    property int mode: 0                   // 0 basic, 1 scientific, 2 convert
    // Hyprland keeps a floating window's size: ask it for the new one
    readonly property var widths: [420, 760, 780]
    onModeChanged: Hyprland.dispatch(`hl.dsp.window.resize({ x = ${widths[mode]}, y = 660, exact = true, window = "class:tuxos-calculator" })`)
    property string expr: ""
    property string shownExpr: ""
    property string result: "0"
    property bool justDone: false

    function press(k) {
        if (k === "C") { expr = ""; shownExpr = ""; result = "0"; return; }
        if (k === "⌫") { expr = expr.slice(0, -1); preview(); return; }
        if (k === "=") { equals(); return; }
        if (k === "±") { expr = expr.startsWith("-(") && expr.endsWith(")") ? expr.slice(2, -1) : (expr ? "-(" + expr + ")" : "-"); preview(); return; }
        if (justDone && /[0-9.(a-zπ√]/.test(k)) expr = "";
        justDone = false;
        const map = { "×": "*", "÷": "/", "−": "-", "x²": "^2", "xʸ": "^", "√": "sqrt(", "sin": "sin(", "cos": "cos(", "tan": "tan(",
                      "ln": "ln(", "log": "log(", "π": "pi", "e": "e", "n!": "!", "1/x": "1/(" };
        expr += map[k] !== undefined ? map[k] : k;
        preview();
    }
    function nice(e) { return e.replace(/\*/g, " × ").replace(/\//g, " ÷ ").replace(/(\d)-/g, "$1 − ").replace(/\+/g, " + ").replace(/pi/g, "π").replace(/sqrt\(/g, "√("); }
    function preview() {
        shownExpr = nice(expr);
        try { if (/[-+*/^%!)]|\(/.test(expr)) result = Calc.fmt(Calc.evaluate(expr)); else if (expr) result = Calc.fmt(parseFloat(expr) || 0); } catch (e) {}
        if (!expr) result = "0";
    }
    function equals() {
        try {
            const v = Calc.evaluate(expr);
            shownExpr = nice(expr) + " =";
            result = Calc.fmt(v);
            expr = String(Math.round(v * 1e10) / 1e10);
            justDone = true;
        } catch (e) { shownExpr = nice(expr); result = "Not a number"; }
    }

    Item {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => {
            if (app.mode === 2) return;
            const t = event.text;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || t === "=") app.press("=");
            else if (event.key === Qt.Key_Backspace) app.press("⌫");
            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Delete) app.press("C");
            else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C) Quickshell.clipboardText = app.result.replace(/ /g, "");
            else if (/^[0-9.+\-*/^()%!,a-z]$/.test(t)) app.press(t === "," ? "." : t);
            else return;
            event.accepted = true;
        }

        Segmented {
            id: tabs
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 16 }
            width: 260
            options: ["Basic", "Scientific", "Convert"]
            current: app.mode
            onPicked: i => app.mode = i
        }

        // ---- display
        Column {
            visible: app.mode !== 2
            anchors { left: parent.left; right: parent.right; top: tabs.bottom; topMargin: 28; leftMargin: 24; rightMargin: 24 }
            spacing: 4
            Text { width: parent.width; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; text: app.shownExpr || " "; font.family: Theme.font; font.pixelSize: Theme.px(20); color: Theme.muted }
            Text {
                width: parent.width; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                text: app.result
                font.family: Theme.font; font.pixelSize: app.result.length > 12 ? 40 : 64; font.weight: Font.Light; color: Theme.text
                TapHandler { onTapped: Quickshell.clipboardText = app.result.replace(/ /g, "") }
            }
        }

        // ---- keys
        Row {
            visible: app.mode !== 2
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }
            spacing: 8
            Grid {
                visible: app.mode === 1
                columns: 3; spacing: 8
                Repeater {
                    model: ["sin", "cos", "tan", "ln", "log", "√", "x²", "xʸ", "n!", "(", ")", "π", "e", "1/x", "%"]
                    delegate: CalcKey { required property string modelData; label: modelData; small: true; onHit: app.press(modelData) }
                }
            }
            Column {
                spacing: 8
                Repeater {
                    model: [["C", "±", "%", "÷"], ["7", "8", "9", "×"], ["4", "5", "6", "−"], ["1", "2", "3", "+"], ["0", ".", "="]]
                    delegate: Row {
                        required property var modelData
                        spacing: 8
                        Repeater {
                            model: modelData
                            delegate: CalcKey {
                                required property string modelData
                                label: modelData
                                wide: modelData === "0"
                                op: "÷×−+".indexOf(modelData) !== -1
                                primary: modelData === "="
                                onHit: app.press(modelData)
                            }
                        }
                    }
                }
            }
        }

        // ---- convert
        Converter { visible: app.mode === 2; anchors { left: parent.left; right: parent.right; top: tabs.bottom; bottom: parent.bottom; margins: 24; topMargin: 24 } }
    }
}
