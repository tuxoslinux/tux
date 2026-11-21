import QtQuick
import Quickshell
import qs.theme
import qs.components

// Startup apps: what starts with the desktop (~/.config/autostart).
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Startup apps"); description: Tr.t("Apps that start when you log in. Fewer means a faster start.") }
    property var list: []
    Cmd { id: ls; command: ["sh", "-c", "for f in \"$HOME\"/.config/autostart/*.desktop /etc/xdg/autostart/*.desktop; do [ -e \"$f\" ] || continue; n=$(sed -n 's/^Name=//p' \"$f\" | head -1); h=$(grep -c -i '^Hidden=true' \"$HOME/.config/autostart/$(basename \"$f\")\" 2>/dev/null); echo \"$(basename \"$f\")|$n|${h:-0}\"; done | sort -u -t'|' -k1,1"]
          Component.onCompleted: run(); onDone: out => page.list = out.split("\n").filter(x => x).map(l => { const p = l.split("|"); return { file: p[0], name: p[1] || p[0], off: p[2] !== "0" }; }) }
    function toggle(e, on) {
        Quickshell.execDetached(["sh", "-c", on ? "rm -f \"$HOME/.config/autostart/$1\".off; f=\"$HOME/.config/autostart/$1\"; [ -e \"$f\" ] && sed -i '/^Hidden=/d' \"$f\"" :
            "mkdir -p \"$HOME/.config/autostart\"; f=\"$HOME/.config/autostart/$1\"; [ -e \"$f\" ] || cp \"/etc/xdg/autostart/$1\" \"$f\"; sed -i '/^Hidden=/d' \"$f\"; echo Hidden=true >> \"$f\"", "sh", e.file]);
        again.restart();
    }
    Timer { id: again; interval: 600; onTriggered: ls.run() }
    SettingCard {
        SettingRow { visible: page.list.length === 0; title: Tr.t("Nothing starts by itself"); last: true }
        Repeater {
            model: page.list
            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.name; description: modelData.file; last: index === page.list.length - 1
                Toggle { checked: !modelData.off; onToggled: v => page.toggle(modelData, v) }
            }
        }
    }
}
