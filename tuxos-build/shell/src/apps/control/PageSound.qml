import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme
import qs.components

// Sound: output and input device, volumes, microphone test, noise filter,
// per-app volume.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Sound"); description: Tr.t("Speakers, headsets, microphones and each app's volume.") }
    readonly property var nodes: Pipewire.nodes.values
    // every device and every playback stream is tracked (a node's class and
    // volume only arrive once it is), then sorted by class
    function cls(n) { return (n.properties || {})["media.class"] || ""; }
    PwObjectTracker { objects: page.nodes.filter(n => !n.isStream || n.isSink) }
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream && cls(n).indexOf("Audio/Source") === 0)
    readonly property var apps: nodes.filter(n => n.isStream && n.isSink && !/^playback\.tuxos-/.test(n.name || ""))
    property bool noise: false
    // equalizer: "off", "bands g1 .. g10" or "autoeq NAME" (tuxos-audio eq status)
    property string eq: "off"
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var matches: []            // AutoEq headphones matching the output's name
    Cmd {
        id: stateCmd
        command: ["sh", "-c", "tuxos-audio noise status; tuxos-audio eq status; cat \"$HOME/.config/tuxos/audio/bands\" 2>/dev/null"]
        Component.onCompleted: run()
        onDone: out => {
            const l = out.split("\n");
            page.noise = l[0] === "on";
            page.eq = l[1] || "off";
            const b = (l[2] || "").trim().split(/\s+/).map(Number);
            if (b.length === 10 && b.every(x => !isNaN(x))) page.bands = b;
        }
    }
    // the headphones' name, from the output in use (USB / Bluetooth headsets)
    readonly property string outName: Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.description || "") : ""
    Cmd {
        id: findCmd
        onDone: out => page.matches = out.split("\n").filter(x => x)
    }
    function findPhones(words) {
        findCmd.command = ["tuxos-audio", "eq", "find", words.replace(/\b(analog|stereo|digital|output|headset|headphones|wireless|usb|audio|lightspeed)\b/gi, " ").trim()];
        Qt.callLater(findCmd.run);     // run() right after a change would run the old command
    }
    function setBand(i, v) {
        const b = bands.slice(); b[i] = Math.round(v * 2) / 2; bands = b;
        bandLater.restart();
    }
    Timer {
        id: bandLater; interval: 400
        onTriggered: {
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config/tuxos/audio\"; echo \"$1\" > \"$HOME/.config/tuxos/audio/bands\"; tuxos-audio eq bands $1", "sh", page.bands.join(" ")]);
            page.eq = "bands " + page.bands.join(" ");
        }
    }

    SettingCard {
        header: Tr.t("Output")
        Repeater {
            model: page.outputs
            delegate: SettingRow {
                required property var modelData
                title: modelData.description || modelData.name
                description: modelData === Pipewire.defaultAudioSink && modelData.audio ? "In use · " + Math.round(modelData.audio.volume * 100) + " %" : ""
                Row {
                    spacing: 12
                    Slider { width: 200; visible: modelData === Pipewire.defaultAudioSink && modelData.audio !== null; anchors.verticalCenter: parent.verticalCenter; value: modelData.audio ? modelData.audio.volume : 0; onMoved: v => modelData.audio.volume = v }
                    Btn { visible: modelData !== Pipewire.defaultAudioSink; text: Tr.t("Use"); onClicked: Pipewire.preferredDefaultAudioSink = modelData }
                }
            }
        }
    }
    SettingCard {
        header: Tr.t("Input")
        visible: page.inputs.length > 0
        Repeater {
            model: page.inputs
            delegate: SettingRow {
                required property var modelData
                title: modelData.description || modelData.name
                description: modelData === Pipewire.defaultAudioSource ? "In use · speak to test" : ""
                Row {
                    spacing: 12
                    Rectangle {
                        visible: modelData === Pipewire.defaultAudioSource
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200; height: 8; radius: 4; color: Theme.ink(0.1)
                        Rectangle { width: parent.width * Math.min(1, pk.peak * 1.6); height: 8; radius: 4; color: Theme.accent }
                        PwNodePeakMonitor { id: pk; node: modelData; enabled: parent.visible }
                    }
                    Btn { visible: modelData !== Pipewire.defaultAudioSource; text: Tr.t("Use"); onClicked: Pipewire.preferredDefaultAudioSource = modelData }
                }
            }
        }
        SettingRow {
            title: Tr.t("Noise filter"); description: Tr.t("Removes keyboard, fan and room noise from your microphone (RNNoise)"); last: true
            Toggle { checked: page.noise; onToggled: v => { page.noise = v; Quickshell.execDetached(["tuxos-audio", "noise", v ? "on" : "off"]); } }
        }
    }
    SettingCard {
        header: Tr.t("Equalizer")
        SettingRow {
            title: Tr.t("Sound shaping"); description: Tr.t("AutoEq corrects your headphones from measurements; Custom is a 10-band equalizer")
            Segmented {
                width: 300; options: ["Off", "AutoEq", "Custom"]
                current: page.eq.startsWith("autoeq") ? 1 : page.eq.startsWith("bands") ? 2 : 0
                onPicked: i => {
                    if (i === 0) { Quickshell.execDetached(["tuxos-audio", "eq", "off"]); page.eq = "off"; }
                    else if (i === 1) { page.eq = "autoeq"; page.findPhones(page.outName); }
                    else bandLater.restart();
                }
            }
        }
        SettingRow {
            visible: page.eq.startsWith("autoeq")
            title: Tr.t("Headphones")
            description: page.eq.length > 7 ? Tr.f("Corrected for {n}", { n: page.eq.slice(7) }) : page.matches.length ? Tr.t("Pick yours (found from the output's name)") : Tr.f("No AutoEq match for \"{n}\" yet: type the model", { n: page.outName })
            Row {
                spacing: 8
                Rectangle {
                    width: 180; height: 34; radius: 10
                    color: Theme.ink(0.05); border.width: 1; border.color: Theme.glassLine
                    TextInput {
                        id: phoneQuery
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text
                        clip: true
                        onAccepted: page.findPhones(text)
                        Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Model, then Enter"); font: parent.font; color: Theme.muted }
                    }
                }
                ChoiceList {
                    visible: page.matches.length > 0
                    options: page.matches.map(m => ({ value: m, label: m }))
                    current: page.eq.slice(7)
                    onPicked: v => { Quickshell.execDetached(["tuxos-audio", "eq", "autoeq", v]); page.eq = "autoeq " + v; }
                }
            }
        }
        Repeater {
            model: page.eq.startsWith("bands") ? ["31 Hz", "62 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"] : []
            delegate: SettingRow {
                required property string modelData
                required property int index
                title: modelData
                description: (page.bands[index] > 0 ? "+" : "") + page.bands[index] + " dB"
                last: index === 9
                Slider { width: 260; value: (page.bands[index] + 12) / 24; onMoved: v => page.setBand(index, v * 24 - 12) }
            }
        }
    }
    SettingCard {
        header: Tr.t("Apps")
        visible: page.apps.length > 0
        Repeater {
            model: page.apps
            delegate: SettingRow {
                required property var modelData
                title: (modelData.properties || {})["application.name"] || modelData.description || modelData.name
                Slider { width: 200; value: modelData.audio ? modelData.audio.volume : 0; onMoved: v => { if (modelData.audio) modelData.audio.volume = v; } }
            }
        }
    }
}
