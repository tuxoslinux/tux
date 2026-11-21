import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// What to share (SPEC: TuxOS' own screen-share picker): a whole screen or
// one window, each with a picture of it, and "allow again without asking".
// The choice goes back to the portal as "[SELECTION]<r>/screen:NAME" or
// "/window:ID" (through the file in TUXOS_PICK_OUT; tuxos-sharepicker
// prints it). Closing it shares nothing.
AppWindow {
    id: app
    appName: Tr.t("Share your screen")
    appIcon: Icons.monitorScreenshot
    implicitWidth: 900; implicitHeight: 620

    // the windows the portal offers: "id[HC>]class[HT>]title[HE>]address[HA>]..."
    readonly property var wins: {
        const raw = Quickshell.env("XDPH_WINDOW_SHARING_LIST") || "";
        return raw.split("[HA>]").filter(x => x.indexOf("[HC>]") > 0).map(x => {
            const id = x.split("[HC>]")[0], rest = x.split("[HC>]")[1] || "";
            const cls = rest.split("[HT>]")[0], rest2 = rest.split("[HT>]")[1] || "";
            const title = rest2.split("[HE>]")[0], addr = (rest2.split("[HE>]")[1] || "").trim();
            return { id: id, cls: cls, title: title, addr: addr };
        });
    }
    function toplevelFor(w) {
        const a = w.addr.replace(/^0x/, "").toLowerCase();
        const h = Hyprland.toplevels.values.find(t => String(t.address).replace(/^0x/, "").toLowerCase() === a);
        return h ? h.wayland : null;
    }
    property string pick: ""                // "screen:NAME" / "window:ID"
    property bool again: false
    function done(sel) {
        const out = Quickshell.env("TUXOS_PICK_OUT");
        if (sel && out) outFile.setText(`[SELECTION]${again ? "r" : ""}/${sel}\n`);
        quitLater.restart();
    }
    FileView { id: outFile; path: Quickshell.env("TUXOS_PICK_OUT") || "/dev/null"; printErrors: false }
    Timer { id: quitLater; interval: 150; onTriggered: Qt.quit() }

    Flickable {
        anchors { fill: parent; margins: 24; bottomMargin: 84 }
        contentHeight: col.implicitHeight
        clip: true
        Column {
            id: col
            width: parent.width
            spacing: 16
            Text { text: Tr.t("SCREENS"); font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold; letterSpacing: 1.2 } color: Theme.muted }
            Flow {
                width: parent.width; spacing: 16
                Repeater {
                    model: Quickshell.screens
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string key: "screen:" + modelData.name
                        width: 260; height: 190; radius: 16
                        color: app.pick === key ? Theme.accentFill : Theme.ink(0.05)
                        border.width: app.pick === key ? 2 : 1; border.color: app.pick === key ? Theme.accent : Theme.glassLine
                        ScreencopyView {
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                            height: 140
                            captureSource: modelData
                            live: false
                        }
                        Text { anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
                               text: Tr.f("Screen {n}", { n: modelData.name }) + "  ·  " + modelData.width + " × " + modelData.height
                               font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text }
                        TapHandler { onTapped: app.pick = parent.key; onDoubleTapped: app.done(parent.key) }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
            Text { visible: app.wins.length > 0; text: Tr.t("WINDOWS"); font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold; letterSpacing: 1.2 } color: Theme.muted }
            Flow {
                width: parent.width; spacing: 16
                Repeater {
                    model: app.wins
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string key: "window:" + modelData.id
                        width: 200; height: 160; radius: 16
                        color: app.pick === key ? Theme.accentFill : Theme.ink(0.05)
                        border.width: app.pick === key ? 2 : 1; border.color: app.pick === key ? Theme.accent : Theme.glassLine
                        WindowThumb {
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                            height: 110
                            toplevel: app.toplevelFor(modelData)
                            live: false
                            radius: 10
                        }
                        Row {
                            anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
                            spacing: 6
                            AppTile { size: 18; appId: modelData.cls; entry: DesktopEntries.heuristicLookup(modelData.cls) }
                            Text { width: Math.min(implicitWidth, 150); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                   text: modelData.title || modelData.cls; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.text }
                        }
                        TapHandler { onTapped: app.pick = parent.key; onDoubleTapped: app.done(parent.key) }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
    Row {
        anchors { left: parent.left; leftMargin: 24; bottom: parent.bottom; bottomMargin: 24 }
        spacing: 10
        Toggle { anchors.verticalCenter: parent.verticalCenter; checked: app.again; onToggled: v => app.again = v }
        Text { anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Let this app share it again without asking"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
    }
    Row {
        anchors { right: parent.right; rightMargin: 24; bottom: parent.bottom; bottomMargin: 20 }
        spacing: 8
        Btn { text: Tr.t("Cancel"); onClicked: app.done("") }
        Btn { text: Tr.t("Share"); primary: true; enabled2: app.pick !== ""; onClicked: app.done(app.pick) }
    }
    Keys.onEscapePressed: app.done("")
}
