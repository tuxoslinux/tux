import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// Convert tab: category chips, From (value + unit), swap, To, and three
// other units under "Also".
Item {
    id: cv
    readonly property var cats: [
        ["Currency", "currency"], ["Length", "length"], ["Area", "area"], ["Volume", "volume"], ["Mass", "mass"], ["Temperature", "temp"],
        ["Speed", "speed"], ["Data", "data"], ["Energy", "energy"], ["Pressure", "pressure"], ["Time", "time"], ["Angle", "angle"], ["Fuel", "fuel"], ["Power", "power"]
    ]
    readonly property var names: ({
        length: [["m", "metres (m)"], ["km", "kilometres (km)"], ["cm", "centimetres (cm)"], ["mm", "millimetres (mm)"], ["mi", "miles"], ["yd", "yards"], ["ft", "feet"], ["in", "inches"], ["nmi", "nautical miles"]],
        area: [["m2", "square metres (m²)"], ["km2", "square km (km²)"], ["ha", "hectares"], ["acre", "acres"], ["ft2", "square feet"], ["cm2", "square cm"], ["mi2", "square miles"]],
        volume: [["m3", "cubic metres (m³)"], ["l", "litres (L)"], ["ml", "millilitres (mL)"], ["ft3", "cubic feet"], ["gal", "US gallons"], ["cm3", "cubic cm"], ["cup", "cups"], ["floz", "fluid ounces"]],
        mass: [["kg", "kilograms (kg)"], ["g", "grams (g)"], ["t", "tonnes"], ["lb", "pounds (lb)"], ["oz", "ounces (oz)"], ["st", "stone"], ["mg", "milligrams"]],
        temp: [["c", "Celsius (°C)"], ["f", "Fahrenheit (°F)"], ["k", "Kelvin (K)"]],
        speed: [["km/h", "km/h"], ["m/s", "m/s"], ["mph", "mph"], ["kn", "knots"]],
        data: [["gb", "gigabytes (GB)"], ["mb", "megabytes (MB)"], ["kb", "kilobytes (kB)"], ["tb", "terabytes (TB)"], ["gib", "gibibytes (GiB)"], ["mib", "mebibytes (MiB)"], ["mbit", "megabits"], ["gbit", "gigabits"], ["b", "bytes"]],
        energy: [["kwh", "kilowatt-hours"], ["j", "joules"], ["kj", "kilojoules"], ["kcal", "kilocalories"], ["cal", "calories"], ["wh", "watt-hours"], ["btu", "BTU"]],
        pressure: [["bar", "bar"], ["pa", "pascals"], ["kpa", "kilopascals"], ["psi", "psi"], ["atm", "atmospheres"], ["mmhg", "mmHg"]],
        time: [["h", "hours"], ["min", "minutes"], ["s", "seconds"], ["ms", "milliseconds"], ["day", "days"], ["week", "weeks"], ["month", "months"], ["year", "years"]],
        angle: [["deg", "degrees"], ["rad", "radians"], ["grad", "gradians"], ["turn", "turns"]],
        fuel: [["l/100km", "L/100 km"], ["mpg", "mpg (US)"], ["km/l", "km/L"]],
        power: [["kw", "kilowatts"], ["w", "watts"], ["hp", "horsepower"], ["mw", "megawatts"]]
    })
    property string cat: "volume"
    readonly property var units: cat === "currency" ? Object.keys(Calc.rates).sort().map(c => [c, c]) : names[cat]
    property string from: "m3"
    property string to: "l"
    property string value: "2.5"
    function setCat(c) {
        cat = c;
        if (c === "currency") { from = "EUR"; to = "BGN"; Calc.refreshRates(); }
        else { from = names[c][0][0]; to = names[c][1][0]; }
    }
    function conv(v, a, b) {
        if (cat === "currency") return v / Calc.rates[a] * Calc.rates[b];
        return Calc.convertUnits(v, a, b);
    }
    readonly property real num: { const v = parseFloat(value.replace(",", ".")); return isNaN(v) ? 0 : v; }
    readonly property real out: { void Calc.rates; return conv(num, from, to); }
    function label(u) { const x = units.find(z => z[0] === u); return x ? x[1] : u; }
    function show(v) { return Calc.fmt(Math.round(v * (cat === "currency" ? 100 : 1e6)) / (cat === "currency" ? 100 : 1e6)); }

    Flow {
        id: chips
        width: parent.width
        spacing: 8
        Repeater {
            model: cv.cats
            delegate: Rectangle {
                required property var modelData
                width: ct.implicitWidth + 26; height: 34; radius: 11
                color: cv.cat === modelData[1] ? Theme.accent : (ch.hovered ? Theme.fillHover : Theme.fill)
                Text { id: ct; anchors.centerIn: parent; text: modelData[0]; font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: cv.cat === modelData[1] ? Font.DemiBold : Font.Normal; color: cv.cat === modelData[1] ? Theme.accentInk : Theme.text }
                HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: cv.setCat(modelData[1]) }
            }
        }
    }
    Column {
        anchors { left: parent.left; right: parent.right; top: chips.bottom; topMargin: 20 }
        spacing: 8
        // From
        Rectangle {
            width: parent.width; height: 120; radius: 20
            color: Theme.ink(0.04); border.width: 1; border.color: inp.activeFocus ? Theme.accentLine : Theme.glassLine
            Text { x: 20; y: 16; text: Tr.t("From"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
            TextInput {
                id: inp
                x: 20; y: 40; width: parent.width - 300
                text: cv.value; onTextChanged: cv.value = text
                font.family: Theme.font; font.pixelSize: Theme.px(44); color: Theme.text; clip: true
                validator: RegularExpressionValidator { regularExpression: /-?[0-9]*[.,]?[0-9]*/ }
            }
            ChoiceList { anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 40 } width: 240; options: cv.units.map(u => ({ value: u[0], label: u[1] })); current: cv.from; onPicked: v => cv.from = v; z: 5 }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 42; height: 42; radius: 21; color: Theme.accent; z: 2
            Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf04e1); font.family: Theme.symbols; font.pixelSize: Theme.px(20); color: Theme.accentInk }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { const f = cv.from; cv.from = cv.to; cv.to = f; } }
        }
        // To
        Rectangle {
            width: parent.width; height: 120; radius: 20
            color: Theme.ink(0.04); border.width: 1; border.color: Theme.glassLine
            Text { x: 20; y: 16; text: Tr.t("To"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
            Text {
                x: 20; y: 40; width: parent.width - 300; elide: Text.ElideRight
                text: cv.show(cv.out)
                font.family: Theme.font; font.pixelSize: Theme.px(44); color: Theme.accent
                TapHandler { onTapped: Quickshell.clipboardText = String(Math.round(cv.out * 1e6) / 1e6) }
            }
            ChoiceList { anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 40 } width: 240; options: cv.units.map(u => ({ value: u[0], label: u[1] })); current: cv.to; onPicked: v => cv.to = v; z: 5 }
        }
        Text { text: cv.cat === "currency" ? "ALSO · rates " + Calc.ratesDate : "ALSO"; topPadding: 4; font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
        Row {
            spacing: 8
            Repeater {
                model: cv.units.filter(u => u[0] !== cv.from && u[0] !== cv.to).slice(0, 3)
                delegate: Rectangle {
                    required property var modelData
                    width: (cv.width - 20) / 3; height: 62; radius: 14
                    color: Theme.ink(0.04); border.width: 1; border.color: Theme.glassLine
                    Column {
                        x: 16; anchors.verticalCenter: parent.verticalCenter
                        Text { text: cv.show(cv.conv(cv.num, cv.from, modelData[0])); font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text }
                        Text { text: modelData[1]; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted }
                    }
                }
            }
        }
    }
}
