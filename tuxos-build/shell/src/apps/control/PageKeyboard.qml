import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Keyboard & shortcuts: layouts (Alt + Shift switches), repeat, and every
// shortcut (the same list as Super + /).
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Keyboard & shortcuts"); description: Tr.t("Layouts (Alt + Shift switches between them) and TuxOS' shortcuts.") }
    readonly property var known: [["us", "", "English (US)"], ["bg", "phonetic", "Bulgarian (phonetic)"], ["bg", "", "Bulgarian (BDS)"], ["gb", "", "English (UK)"],
                                  ["de", "", "German"], ["fr", "", "French"], ["es", "", "Spanish"], ["it", "", "Italian"], ["ru", "phonetic", "Russian (phonetic)"],
                                  ["ua", "", "Ukrainian"], ["gr", "", "Greek"], ["tr", "", "Turkish"], ["pl", "", "Polish"], ["ro", "", "Romanian"]]
    property var layouts: [["us", ""], ["bg", "phonetic"]]
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/hypr/keyboard.lua"
        printErrors: false
        onLoaded: {
            const l = /kb_layout = "([^"]*)"/.exec(text()), v = /kb_variant = "([^"]*)"/.exec(text());
            if (l) { const ls = l[1].split(","), vs = (v ? v[1] : "").split(","); page.layouts = ls.map((x, i) => [x, vs[i] || ""]); }
        }
    }
    function save() {
        const l = layouts.map(x => x[0]).join(","), v = layouts.map(x => x[1]).join(",");
        file.setText(`-- written by TuxOS Control > Keyboard\nhl.config({ input = { kb_layout = "${l}", kb_variant = "${v}", kb_options = "grp:alt_shift_toggle" } })\n`);
        Hyprland.dispatch(`(function() hl.config({ input = { kb_layout = "${l}", kb_variant = "${v}" } }); return hl.dsp.no_op() end)()`);
    }
    function name(x) { const k = known.find(k => k[0] === x[0] && k[1] === x[1]); return k ? k[2] : x[0] + (x[1] ? " (" + x[1] + ")" : ""); }

    SettingCard {
        header: Tr.t("Layouts")
        Repeater {
            model: page.layouts
            delegate: SettingRow {
                required property var modelData
                required property int index
                title: page.name(modelData); description: index === 0 ? "First layout" : "Alt + Shift"
                Btn { visible: page.layouts.length > 1; text: Tr.t("Remove"); onClicked: { const l = page.layouts.slice(); l.splice(index, 1); page.layouts = l; page.save(); } }
            }
        }
        SettingRow {
            title: Tr.t("Add a layout"); last: true
            ChoiceList {
                width: 260
                options: page.known.filter(k => !page.layouts.some(x => x[0] === k[0] && x[1] === k[1])).map(k => ({ value: k[0] + ":" + k[1], label: k[2] }))
                onPicked: v => { const p = v.split(":"); page.layouts = page.layouts.concat([[p[0], p[1]]]); page.save(); }
            }
        }
    }
    // ---- the shortcut editor (SPEC round 7 #5): every shortcut, its keys;
    // "Change" waits for the new keys, warns when another one uses them
    property string capturing: ""          // the shortcut waiting for keys
    property string pending: ""            // keys pressed, when they clash
    property string clashWith: ""
    Item {
        id: catcher
        focus: page.capturing !== ""
        Keys.onPressed: e => {
            e.accepted = true;
            if (e.key === Qt.Key_Escape && !(e.modifiers & (Qt.MetaModifier | Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier))) { page.capturing = ""; return; }
            const k = Shortcuts.fromEvent(e);
            if (!k) return;
            const c = Shortcuts.clash(page.capturing, k);
            if (c) { page.pending = k; page.clashWith = c; return; }
            Shortcuts.set(page.capturing, k);
            page.capturing = "";
        }
    }
    Repeater {
        model: ["Apps", "Windows", "Desktops", "Shell", "Capture", "Gaming"]
        delegate: SettingCard {
            required property string modelData
            readonly property var binds: Shortcuts.all.filter(b => b[1] === modelData)
            header: Tr.t("Shortcuts: ") + Tr.t(modelData)
            Repeater {
                model: binds
                delegate: SettingRow {
                    required property var modelData
                    required property int index
                    readonly property string id_: modelData[0]
                    readonly property bool waiting: page.capturing === id_
                    readonly property bool changed: Shortcuts.mine[id_] !== undefined
                    title: Tr.t(modelData[2])
                    description: waiting ? (page.clashWith ? (page.clashWith.startsWith("reserved:") ? Tr.f("{k} is taken by: {n}", { k: Shortcuts.pretty(page.pending), n: Tr.t(page.clashWith.slice(9)) })
                                                                                                      : Tr.f("{k} already does: {n}", { k: Shortcuts.pretty(page.pending), n: Tr.t(Shortcuts.nameOf(page.clashWith)) }))
                                                         : Tr.t("Press the new keys (Esc: cancel)"))
                                         : changed ? Tr.f("Default: {k}", { k: Shortcuts.pretty(modelData[3]) }) : ""
                    last: index === binds.length - 1
                    Row {
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: kt.implicitWidth + 16; height: 28; radius: 8
                            color: waiting ? Theme.accentFill : Theme.ink(0.07); border.width: 1; border.color: waiting ? Theme.accent : Theme.glassLine
                            Text { id: kt; anchors.centerIn: parent; text: waiting ? "..." : Shortcuts.pretty(Shortcuts.keysOf(id_)); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; color: Theme.text }
                        }
                        // a clash: take the keys anyway (the other one is turned off) or not
                        Btn { visible: waiting && page.clashWith !== "" && !page.clashWith.startsWith("reserved:"); text: Tr.t("Use anyway"); danger: true
                              onClicked: { Shortcuts.set(page.clashWith, ""); Shortcuts.set(id_, page.pending); page.capturing = ""; page.clashWith = ""; } }
                        Btn { visible: !waiting && modelData[4] !== ""; text: Tr.t("Change"); onClicked: { page.clashWith = ""; page.pending = ""; page.capturing = id_; catcher.forceActiveFocus(); } }
                        Btn { visible: waiting; text: Tr.t("Cancel"); onClicked: { page.capturing = ""; page.clashWith = ""; } }
                        Btn { visible: !waiting && changed; text: Tr.t("Reset"); onClicked: Shortcuts.set(id_, modelData[3]) }
                    }
                }
            }
        }
    }
    // ---- text snippets: type the trigger anywhere, it becomes the text
    SettingCard {
        header: Tr.t("Text snippets")
        SettingRow {
            visible: Snippets.list.length === 0
            title: Tr.t("No snippets yet"); description: Tr.t("For example ;mail for your e-mail address: type it in any app and it becomes the text. {date} and {time} work in the text.")
        }
        Repeater {
            model: Snippets.list
            delegate: SettingRow {
                required property var modelData
                title: modelData.trigger; description: modelData.text
                Btn { text: Tr.t("Remove"); onClicked: Snippets.remove(modelData.trigger) }
            }
        }
        SettingRow {
            title: Tr.t("Add a snippet"); last: true
            Row {
                spacing: 8
                Rectangle {
                    width: 110; height: 34; radius: 10; color: Theme.ink(0.05); border.width: 1; border.color: trigIn.activeFocus ? Theme.accentLine : Theme.glassLine
                    TextInput { id: trigIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; clip: true
                                font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text; text: ";"
                                KeyNavigation.tab: textIn }
                }
                Rectangle {
                    width: 240; height: 34; radius: 10; color: Theme.ink(0.05); border.width: 1; border.color: textIn.activeFocus ? Theme.accentLine : Theme.glassLine
                    TextInput { id: textIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; clip: true
                                font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text
                                onAccepted: addBtn.clicked()
                                Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: Tr.t("It becomes this text"); font: parent.font; color: Theme.muted } }
                }
                Btn { id: addBtn; text: Tr.t("Add"); primary: true; enabled2: trigIn.text.length >= 3 && textIn.text.length > 0
                      onClicked: { if (Snippets.add(trigIn.text, textIn.text)) { trigIn.text = ";"; textIn.text = ""; } } }
            }
        }
    }
    SettingCard {
        SettingRow {
            title: Tr.t("All shortcuts back to TuxOS' keys"); last: true
            Btn { text: Tr.t("Reset all"); enabled2: Object.keys(Shortcuts.mine).length > 0; onClicked: Shortcuts.resetAll() }
        }
    }
}
