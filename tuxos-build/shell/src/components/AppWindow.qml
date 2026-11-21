import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.theme

// The window of a TuxOS app (mockups apps/*): one glass sheet (Hyprland
// blurs behind it), a title bar with the app's symbol and name, an optional
// search field, and minimize (flies into the dock) / maximize / close.
FloatingWindow {
    id: w
    property string appName: ""
    property int appIcon: 0
    property bool searchable: false
    property string searchHint: "Search all settings"
    property string subtitle: ""                 // e.g. the open file's path
    property Component headerAction: null        // e.g. a Save button, left of the search
    // return false to keep the window open (unsaved work)
    property var canClose: null
    function closeWindow() { if (!canClose || canClose()) Qt.quit(); }
    // closed from outside (Super + Q, the dock, the compositor): the app ends
    // too, so it can be opened again (unless it has to ask first)
    onVisibleChanged: if (!visible) { if (!canClose || canClose()) Qt.quit(); else visible = true; }
    property alias search: searchField.text
    // the app's own key handling item: a click in the window or Esc in the
    // search field gives the keys back to it (else shortcuts land in search)
    property Item keyTarget: null
    function giveKeysBack() { if (keyTarget) keyTarget.forceActiveFocus(); }
    default property alias content: body.data
    signal searchAccepted()

    implicitWidth: 1180
    implicitHeight: 760
    color: "transparent"
    title: appName

    Rectangle {
        id: sheet
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(Theme.glassBase.r, Theme.glassBase.g, Theme.glassBase.b, Theme.lite ? 1.0 : (Theme.light ? 0.9 : 0.84))
        border.width: 1
        border.color: Theme.glassLine

        // ---- title bar
        Item {
            id: bar
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 54
            Row {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 12
                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: Theme.ink(0.10)
                    Text { anchors.centerIn: parent; text: String.fromCodePoint(w.appIcon); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: Theme.text }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: Tr.t(w.appName); font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
                Text { visible: w.subtitle !== ""; anchors.verticalCenter: parent.verticalCenter; text: w.subtitle; width: Math.min(implicitWidth, w.width - 640); elide: Text.ElideLeft; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
            }
            Row {
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 8
                Loader { active: w.headerAction !== null; sourceComponent: w.headerAction; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    visible: w.searchable
                    width: 320; height: 34; radius: 11
                    color: Theme.ink(0.05); border.width: 1; border.color: searchField.activeFocus ? Theme.accentLine : Theme.glassLine
                    Text { id: mg; anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: String.fromCodePoint(0xf0349); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: Theme.muted }
                    TextInput {
                        id: searchField
                        anchors { left: mg.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; clip: true
                        onAccepted: w.searchAccepted()
                        Keys.onEscapePressed: { text = ""; w.giveKeysBack(); }
                        Text { visible: searchField.text === ""; text: Tr.t(w.searchHint); font: searchField.font; color: Theme.muted }
                    }
                }
                Repeater {
                    model: [[0xf0374, "min", "Minimize", "Super + Down"], [0xf05af, "max", "Maximize", "Super + Up"], [0xf0156, "close", "Close", "Super + Q"]]
                    delegate: Rectangle {
                        required property var modelData
                        width: 30; height: 30; radius: 15
                        Tip { text: modelData[2]; keys: modelData[3]; shown: bh.hovered }
                        color: bh.hovered ? (modelData[1] === "close" ? Qt.rgba(1, 0.48, 0.54, 0.35) : Theme.fillHover) : Theme.fill
                        Text { anchors.centerIn: parent; text: String.fromCodePoint(modelData[0]); font.family: Theme.symbols; font.pixelSize: Theme.px(14); color: Theme.text }
                        HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (modelData[1] === "close") w.closeWindow();
                                else if (modelData[1] === "min") Hyprland.dispatch('hl.dsp.global("tuxos:minimize")');
                                else Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized" })');   // the config turns it into the gapped maximize
                            }
                        }
                    }
                }
            }
            // drag the window by its title bar (Hyprland moves floating windows)
            TapHandler { acceptedButtons: Qt.LeftButton; onDoubleTapped: Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized" })') }
        }
        Rectangle { anchors { left: parent.left; right: parent.right; top: bar.bottom } height: 1; color: Theme.glassLine }
        Item {
            id: body
            anchors { left: parent.left; right: parent.right; top: bar.bottom; topMargin: 1; bottom: parent.bottom }
        }
        // on top of the body: sees every press first, then lets it through
        MouseArea {
            anchors.fill: body
            z: 1000
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            propagateComposedEvents: true
            onPressed: m => { if (searchField.activeFocus) w.giveKeysBack(); m.accepted = false; }
        }
        // type to search (SPEC polish): letters typed anywhere go into the
        // search field (when nothing else takes text); Ctrl + F jumps there
        focus: true
        Keys.onPressed: e => {
            if (!w.searchable) return;
            if (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier)) { searchField.forceActiveFocus(); searchField.selectAll(); e.accepted = true; return; }
            if (searchField.activeFocus || e.text.length !== 1 || e.text < " " || (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) return;
            searchField.forceActiveFocus();
            searchField.text += e.text;
            e.accepted = true;
        }
    }
}
