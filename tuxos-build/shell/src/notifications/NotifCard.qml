import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.theme
import qs.components
import qs.services

// One notification / shell toast card (mockup shell2/01-toast): app symbol,
// app name, time, close; summary bold, body; picture; reply field for chat
// apps; action buttons (the first one blue). Hover pauses the timer.
Rectangle {
    id: card

    property var notif: null            // Quickshell Notification, or
    property var toast: null            // a shell toast from Toasts
    property bool popup: true           // false inside the centre
    signal done()

    readonly property bool isNotif: notif !== null
    readonly property string appName: isNotif ? (notif.appName || "App") : "TuxOS"
    // kitty's "command finished" (> 30 s, unfocused): ✓ / ✗ with the command
    readonly property var kittyDone: isNotif && notif.appName === "kitty" ? /^Command (.*) finished with status: (\d+)/.exec(notif.body) : null
    readonly property string summary: kittyDone ? (kittyDone[2] === "0" ? "✓ " : "✗ ") + kittyDone[1] : (isNotif ? notif.summary : Tr.t(toast.title))
    readonly property string body: kittyDone ? (kittyDone[2] === "0" ? Tr.t("Finished") : Tr.f("Failed with status {n}", { n: kittyDone[2] })) + " · " + Tr.t("click to go there") : (isNotif ? notif.body : Tr.t(toast.body))
    readonly property var entry: isNotif && notif.desktopEntry ? DesktopEntries.heuristicLookup(notif.desktopEntry) : (isNotif ? DesktopEntries.heuristicLookup(notif.appName) : null)
    readonly property var actions: isNotif ? notif.actions.filter(a => a.identifier !== "default") : toast.buttons
    readonly property var defaultAction: isNotif ? notif.actions.find(a => a.identifier === "default") : null
    readonly property bool critical: isNotif && notif.urgency === NotificationUrgency.Critical
    readonly property int timeout: {
        if (!popup) return 0;
        if (isNotif) return critical ? 0 : (notif.expireTimeout > 0 ? notif.expireTimeout : 6000);
        return toast.timeout;
    }

    width: 400
    implicitHeight: content.implicitHeight + 32
    height: implicitHeight
    radius: 22
    color: popup ? Theme.glassPanel : Theme.fill
    border.width: 1
    border.color: critical ? Theme.warn : Theme.glassLine

    // enter: slide in from the right
    x: popup ? (shown ? 0 : 40) : 0
    opacity: shown ? 1 : 0
    property bool shown: !popup
    Component.onCompleted: shown = true
    Behavior on x { enabled: !Theme.reduceMotion; Spring {} }
    Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier } }

    Timer {
        id: life
        interval: card.timeout
        running: card.timeout > 0 && !hover.hovered && !reply.activeFocus && !card.menuOpen
        onTriggered: card.done()
    }

    HoverHandler { id: hover }
    // right-click: mute this app (no pop-ups or sounds; still in the centre)
    // or its settings, as a row of buttons inside the card
    property bool menuOpen: false
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: if (card.isNotif) card.menuOpen = !card.menuOpen
    }
    TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: if (card.isNotif) card.menuOpen = !card.menuOpen }
    // the card itself; buttons inside take their taps exclusively (else a
    // button press also ran the default action and closed the card first)
    TapHandler {
        enabled: !card.menuOpen
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            if (card.isNotif) { if (card.defaultAction) card.defaultAction.invoke(); }
            else if (card.toast.onClick) card.toast.onClick();
            card.done();
        }
    }

    Column {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16; leftMargin: 16; rightMargin: 16 }
        spacing: 8

        Row {
            width: parent.width
            spacing: 8
            Rectangle {
                width: 24; height: 24; radius: 7
                color: Theme.ink(0.10)
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    readonly property var sym: card.isNotif ? AppSymbols.forEntry(card.entry, card.notif.desktopEntry || card.notif.appName) : ({ code: card.toast.icon })
                    text: sym.code !== undefined ? String.fromCodePoint(sym.code) : sym.letter
                    font.family: sym.code !== undefined ? Theme.symbols : Theme.font
                    font.pixelSize: Theme.px(13)
                    color: Theme.text
                }
            }
            Text {
                text: card.appName
                font.family: Theme.font; font.pixelSize: Theme.px(13)
                color: Theme.muted
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 - 10 - timeText.width - closeBtn.width - 30
                elide: Text.ElideRight
            }
            Text {
                id: timeText
                text: card.isNotif ? Notifs.ago(Notifs.timeOf(card.notif)) : "now"
                font.family: Theme.font; font.pixelSize: Theme.px(12)
                color: Theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }
            Sym {
                id: closeBtn
                code: Icons.close
                font.pixelSize: Theme.px(15)
                color: closeHover.hovered ? Theme.text : Theme.muted
                anchors.verticalCenter: parent.verticalCenter
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: { if (card.isNotif) card.notif.dismiss(); card.done(); } }
            }
        }

        Row {
            width: parent.width
            spacing: 12
            Image {
                id: pic
                // a notification's picture, or a toast's (achievement icons)
                readonly property string src: card.isNotif ? card.notif.image : (card.toast && card.toast.image ? card.toast.image : "")
                visible: src !== ""
                source: src
                width: visible ? 48 : 0; height: 48
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(96, 96)
                asynchronous: true
            }
            Column {
                width: parent.width - (pic.visible ? pic.width + 12 : 0)
                spacing: 4
                Text {
                    width: parent.width
                    text: card.summary
                    font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold
                    color: Theme.text
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
                Text {
                    width: parent.width
                    text: card.body
                    textFormat: card.isNotif ? Text.StyledText : Text.PlainText
                    font.family: Theme.font; font.pixelSize: Theme.px(14)
                    color: Theme.muted
                    wrapMode: Text.Wrap
                    maximumLineCount: card.popup ? 4 : 3
                    elide: Text.ElideRight
                    visible: text.length > 0
                    linkColor: Theme.accent
                    onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
                }
                // a toast's extra lines, shown while the pointer is on it
                // (the boot-time card: the last few starts)
                Text {
                    width: parent.width
                    visible: !card.isNotif && card.toast && (card.toast.more || "") !== "" && hover.hovered
                    text: card.toast ? (card.toast.more || "") : ""
                    font.family: Theme.font; font.pixelSize: Theme.px(13)
                    color: Theme.dim
                    wrapMode: Text.Wrap
                }
            }
        }

        // reply field for chat apps
        Row {
            visible: card.isNotif && card.notif.hasInlineReply
            width: parent.width
            spacing: 8
            topPadding: 4
            Rectangle {
                width: parent.width - 48; height: 38; radius: 11
                color: Theme.ink(0.05); border.width: 1; border.color: reply.activeFocus ? Theme.accentLine : Theme.glassLine
                TextInput {
                    id: reply
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.font; font.pixelSize: Theme.px(14)
                    color: Theme.text
                    clip: true
                    onAccepted: send()
                    function send() { if (text.length) { card.notif.sendInlineReply(text); card.done(); } }
                    Text {
                        visible: reply.text.length === 0
                        text: card.isNotif && card.notif.inlineReplyPlaceholder ? card.notif.inlineReplyPlaceholder : "Reply..."
                        font: reply.font; color: Theme.dim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            Rectangle {
                width: 40; height: 38; radius: 11
                color: Theme.accent
                Sym { anchors.centerIn: parent; code: Icons.send; color: Theme.accentInk; font.pixelSize: Theme.px(17) }
                TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: reply.send() }
            }
        }

        // the right-click row: mute the app / its settings
        Flow {
            visible: card.menuOpen
            width: parent.width
            spacing: 8
            topPadding: 4
            Repeater {
                model: card.menuOpen ? [[Tr.f("Mute {app}", { app: card.appName }), "mute"], [Tr.t("Settings"), "settings"], [Tr.t("Cancel"), "cancel"]] : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ml.implicitWidth + 32; height: 36; radius: 11
                    color: index === 0 ? Theme.accent : (mh.hovered ? Theme.fillHover : Theme.ink(0.07))
                    border.width: index === 0 ? 0 : 1; border.color: Theme.glassLine
                    Text { id: ml; anchors.centerIn: parent; text: modelData[0]; font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: index === 0 ? Theme.accentInk : Theme.text }
                    HoverHandler { id: mh; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            // act first: closing the row destroys this button
                            const what = modelData[1], c = card;
                            if (what === "mute") { Notifs.mute(c.appName); if (c.popup) c.done(); }
                            else if (what === "settings") Apps.run(`${Prefs.settingsApp} --page notifications`);
                            c.menuOpen = false;
                        }
                    }
                }
            }
        }

        // action buttons
        Flow {
            visible: card.actions.length > 0 && !card.menuOpen
            width: parent.width
            spacing: 8
            topPadding: 4
            Repeater {
                model: card.actions
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool primary: index === 0
                    width: lbl.implicitWidth + 32; height: 36; radius: 11
                    color: primary ? Theme.accent : (bh.hovered ? Theme.fillHover : Theme.ink(0.07))
                    border.width: primary ? 0 : 1; border.color: Theme.glassLine
                    Text {
                        id: lbl
                        anchors.centerIn: parent
                        text: card.isNotif ? modelData.text : Tr.t(modelData.text)
                        font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold
                        color: parent.primary ? Theme.accentInk : Theme.text
                    }
                    HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            if (card.isNotif) modelData.invoke(); else if (modelData.run) modelData.run();
                            card.done();
                        }
                    }
                }
            }
        }
    }
}
