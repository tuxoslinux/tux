import QtQuick
import Quickshell
import qs.theme
import qs.components

// Performance: what TuxOS' tuning is doing right now (tuxos-tune status).
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Performance"); description: Tr.t("TuxOS' tuning: CPU-optimised packages, scheduler, zram, game mode.") }
    // ---- fans (SPEC system care #14): only where TuxOS can set them
    property var fan: ({ kind: "none", mode: "auto", temp: -1, fans: [], curve: [] })
    Cmd {
        id: fanSt
        command: ["sh", "-c", "command -v tuxos-fan >/dev/null && tuxos-fan status"]
        Component.onCompleted: run()
        onDone: out => {
            const f = { kind: "none", mode: "auto", temp: -1, fans: [], curve: [] };
            for (const l of out.split("\n")) {
                const p = l.split(" ");
                if (p[0] === "kind") f.kind = p[1]; else if (p[0] === "mode") f.mode = p[1];
                else if (p[0] === "temp") f.temp = +p[1]; else if (p[0] === "fan") f.fans.push({ name: p[1], rpm: +p[2] });
                else if (p[0] === "curve") f.curve = p.slice(1).filter(x => x).map(x => +x.split(":")[1]);
            }
            page.fan = f;
            if (f.curve.length === 4) page.custom = f.curve;
        }
    }
    Timer { interval: 3000; repeat: true; running: page.fan.kind !== "none" && page.visible; onTriggered: fanSt.run() }
    readonly property var modes: ["auto", "quiet", "balanced", "max", "custom"]
    property var custom: [20, 35, 60, 100]                   // % at 40, 55, 70, 85 °C
    function setFan(m) {
        const curve = [40, 55, 70, 85].map((t, i) => t + ":" + Math.round(custom[i])).join(" ");
        Quickshell.execDetached(["sh", "-c", "pkexec \"$@\" || exit 1", "sh", "tuxos-fan", "set"].concat(m === "custom" ? ["custom", curve] : [m]));
        fan = Object.assign({}, fan, { mode: m });
        again.restart();
    }
    Timer { id: again; interval: 1500; onTriggered: fanSt.run() }
    Timer { id: customLater; interval: 600; onTriggered: page.setFan("custom") }
    SettingCard {
        visible: page.fan.kind !== "none"
        header: Tr.t("Fans")
        SettingRow {
            title: Tr.t("Fan curve")
            description: (page.fan.temp >= 0 ? Tr.f("CPU {t} °C", { t: page.fan.temp }) : "") + page.fan.fans.filter(f => f.rpm > 0).map(f => " · " + f.rpm + " rpm").join("")
            last: page.fan.mode !== "custom"
            Segmented { width: 420; options: ["Auto", "Quiet", "Balanced", "Max", "Custom"]; current: Math.max(0, page.modes.indexOf(page.fan.mode)); onPicked: i => page.setFan(page.modes[i]) }
        }
        Repeater {
            model: page.fan.mode === "custom" ? [40, 55, 70, 85] : []
            delegate: SettingRow {
                required property int modelData
                required property int index
                title: Tr.f("At {t} °C", { t: modelData }); description: Math.round(page.custom[index]) + " %"; last: index === 3
                Slider {
                    width: 260; value: page.custom[index] / 100
                    onMoved: v => { const c = page.custom.slice(); c[index] = Math.round(v * 100); page.custom = c; customLater.restart(); }
                }
            }
        }
    }
    Cmd { id: st; command: ["sh", "-c", "tuxos-tune status 2>&1 | sed 's/\\x1b\\[[0-9;]*m//g'"]; Component.onCompleted: run() }
    Rectangle {
        width: parent.width; height: out.implicitHeight + 40; radius: 18
        color: Theme.ink(0.035); border.width: 1; border.color: Theme.glassLine
        Text { id: out; x: 20; y: 20; width: parent.width - 40; text: st.out || "Reading..."; wrapMode: Text.Wrap; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Theme.px(13); color: Theme.text; lineHeight: 1.25 }
    }
}
