import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.theme
import qs.components
import qs.services

// Lock screen (SPEC lock-v4): locks after Prefs.lockMinutes (5) without
// input, on Super + L, before sleep (Power.suspend, hypridle's
// before_sleep_cmd for lid / system sleep). The wallpaper drifts and darkens
// for the last 30 s before it locks (screen saver). One card on the screen
// that was focused; the other screens show the blurred wallpaper.
Scope {
    id: root

    property bool unlocking: false
    property string primary: ""
    property string pending: ""
    property string pamMessage: ""
    signal wrongPassword()
    signal rightPassword()

    function lock() {
        if (sessionLock.locked) return;
        primary = Shell.focusedScreen;
        unlocking = false;
        pamMessage = "";
        Shell.hideOverlay();
        Shell.close();
        Power.locked = true;
        Notifs.locked = true;
        sessionLock.locked = true;
        fpCheck.running = true;
    }
    function finishUnlock() {
        Sounds.play("unlock");
        sessionLock.locked = false;
        Power.locked = false;
        Notifs.locked = false;
        unlocking = false;
        fp.abort();
    }

    Connections { target: Power; function onLockRequested() { root.lock(); } }

    // ---- idle: screen saver 30 s before locking, then lock
    // lockMinutes 0 = never (Settings "Never"; the live ISO)
    readonly property bool autoLock: Prefs.lockMinutes > 0 && !Shell.live
    // made again when the setting changes (an IdleMonitor keeps its first timeout)
    property bool saverIdle: false
    Instantiator {
        model: root.autoLock ? [Prefs.lockMinutes] : []
        delegate: QtObject {
            required property int modelData
            readonly property IdleMonitor saver: IdleMonitor {
                timeout: Math.max(30, modelData * 60 - 30)
                respectInhibitors: true
                onIsIdleChanged: root.saverIdle = isIdle
            }
            readonly property IdleMonitor locker: IdleMonitor {
                timeout: Math.max(60, modelData * 60)
                respectInhibitors: true
                onIsIdleChanged: if (isIdle && root.autoLock) root.lock()
            }
            Component.onDestruction: root.saverIdle = false
        }
    }
    Variants {
        // the screen saver's windows exist only while it shows
        model: root.autoLock && root.saverIdle && !sessionLock.locked ? Quickshell.screens : []
        delegate: Component {
            PanelWindow {
                id: saver
                required property var modelData
                screen: modelData
                visible: root.saverIdle && !sessionLock.locked
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "black"
                WlrLayershell.namespace: "tuxos-saver"
                WlrLayershell.layer: WlrLayer.Overlay
                Image {
                    anchors.centerIn: parent
                    width: parent.width; height: parent.height
                    source: "file://" + Quickshell.env("HOME") + "/.local/share/tuxos/wallpaper.png"
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(1920, 1080)
                    NumberAnimation on scale { running: saver.visible; from: 1.0; to: 1.08; duration: 30000 }
                    NumberAnimation on x { running: saver.visible; from: 0; to: -40; duration: 30000 }
                    NumberAnimation on opacity { running: saver.visible; from: 0.9; to: 0.25; duration: 30000 }
                }
            }
        }
    }

    // ---- authentication: password, and the fingerprint at the same time
    PamContext {
        id: pam
        config: "tuxos-lock"
        onResponseRequiredChanged: if (responseRequired) { respond(root.pending); root.pending = ""; }
        onPamMessage: if (!responseRequired && message) root.pamMessage = message
        onCompleted: result => {
            if (result === PamResult.Success) root.rightPassword();
            else root.wrongPassword();
        }
        onError: root.wrongPassword()
    }
    function tryPassword(pw) {
        pending = pw;
        if (pam.active) pam.abort();
        pam.start();
    }
    property bool hasFingerprint: false
    Process {
        id: fpCheck
        command: ["sh", "-c", "[ -e /usr/lib/security/pam_fprintd.so ] && fprintd-list \"$USER\" 2>/dev/null | grep -q '#'"]
        onExited: code => { root.hasFingerprint = code === 0; if (code === 0 && !fp.active) fp.start(); }
    }
    PamContext {
        id: fp
        config: "tuxos-fingerprint"
        onCompleted: result => { if (result === PamResult.Success && sessionLock.locked) root.rightPassword(); }
    }

    WlSessionLock {
        id: sessionLock
        surface: Component {
            WlSessionLockSurface {
                id: surf
                color: "black"
                readonly property bool main: (screen !== null && screen.name === root.primary) || Quickshell.screens.length === 1

                Backdrop {
                    id: backdrop
                    anchors.fill: parent
                    amount: 1
                    // the depth effect keeps the wallpaper's subject recognisable
                    blurScale: surf.depth ? 0.2 : 1
                }

                SystemClock { id: clock; precision: SystemClock.Minutes }

                // ---- depth effect (Settings > Appearance): a big clock behind
                // the wallpaper's subject (Wallpapers.depthMask), the card
                // compact at the bottom so the subject stays in view
                readonly property bool depth: Prefs.depthEffect && Wallpapers.depthMask !== "" && surf.main
                DepthClock {
                    anchors.fill: parent
                    backdrop: backdrop
                    mask: surf.depth ? Wallpapers.depthMask : ""
                    date: clock.date
                    contentOpacity: card.opacity
                }

                // depth layout: now playing as a slim tab in the sky above the
                // date, so the wallpaper's subject stays clear
                NowPlayingTab {
                    shown: surf.depth
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(surf.height * 0.06)
                    width: Math.min(560, surf.width - 48)
                    opacity: card.opacity
                }

                // the card (1040 x 500, radius 40), scaled down on small screens
                Item {
                    id: cardWrap
                    visible: surf.main
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: surf.depth ? surf.height * 0.5 - height * scale / 2 - 48 : 0
                    width: surf.depth ? 560 : 1040; height: surf.depth ? 200 : 500
                    scale: Math.min(1, (surf.width - 48) / width, (surf.height - 48) / height)

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: 40
                        color: Qt.rgba(Theme.glassBase.r, Theme.glassBase.g, Theme.glassBase.b, Theme.lite ? 0.92 : (Theme.light ? 0.62 : 0.42))
                        border.width: 1
                        border.color: Theme.glassLine
                        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 40; rightMargin: 40; topMargin: 1 } height: 1; color: Theme.glassHighlight }

                        // left: clock, date, now playing
                        Text {
                            id: time
                            visible: !surf.depth
                            x: 84; y: 48
                            textFormat: Text.StyledText
                            text: Qt.formatTime(clock.date, "HH") + `<font color="${Theme.accent}">:</font>` + Qt.formatTime(clock.date, "mm")
                            font.family: Theme.font; font.pixelSize: Theme.px(96); font.weight: Font.Bold; font.letterSpacing: -3
                            color: Theme.text
                        }
                        Text {
                            visible: !surf.depth
                            x: 88; anchors.top: time.bottom; anchors.topMargin: 4
                            text: Tr.date(clock.date, "dddd, d MMMM")
                            font.family: Theme.font; font.pixelSize: Theme.px(19)
                            color: Theme.muted
                        }
                        NowPlaying { shown: !surf.depth; x: 84; y: 232 }

                        Rectangle { visible: !surf.depth; x: 520; y: 100; width: 1; height: 300; color: Theme.glassLine }

                        // right: note, password, power buttons
                        Note { id: note; visible: !surf.depth; x: 608; y: 68 }
                        Text {
                            visible: surf.depth
                            x: 40; y: 32
                            text: Tr.f("Welcome back, {n}", { n: Prefs.firstName })
                            font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text
                        }
                        Connections {
                            target: root
                            function onWrongPassword() { pwd.wrong(); }
                            function onRightPassword() { root.unlocking = true; pwd.success(); }
                        }
                        Row {
                            anchors { right: parent.right; rightMargin: 40; bottom: parent.bottom; bottomMargin: 32 }
                            spacing: 20
                            Repeater {
                                model: [[Icons.weatherNight, "Sleep"], [Icons.restart, "Restart"], [Icons.power, "Shut down"]]
                                delegate: Sym {
                                    required property var modelData
                                    required property int index
                                    code: modelData[0]
                                    font.pixelSize: Theme.px(19)
                                    color: ph.hovered ? Theme.text : Theme.muted
                                    HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            if (index === 0) Quickshell.execDetached(["loginctl", "suspend"]);
                                            else if (index === 1) Power.reboot();
                                            else Power.poweroff();
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // outside the card so the lock stays bright while the card fades
                    PasswordBar {
                        id: pwd
                        x: surf.depth ? 40 : 608; y: surf.depth ? 76 : 348
                        message: root.hasFingerprint ? "Or touch the fingerprint reader" : root.pamMessage
                        onSubmitted: pw => root.tryPassword(pw)
                        onUnlocked: fadeOut.restart()
                        Component.onCompleted: focusField()
                    }
                    Component.onCompleted: note.shuffle()
                }

                // unlock: the card fades and grows slightly (the lock stays
                // bright), the blur clears, then the session unlocks
                ParallelAnimation {
                    id: fadeOut
                    NumberAnimation { target: card; property: "opacity"; to: 0; duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier }
                    NumberAnimation { target: cardWrap; property: "scale"; to: cardWrap.scale * 1.04; duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier }
                    NumberAnimation { target: backdrop; property: "amount"; to: 0; duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier }
                    onFinished: root.finishUnlock()
                }
                // the lock itself stays bright while the card fades: draw it above
                Connections {
                    target: root
                    function onRightPassword() { if (!surf.main) fadeOther.restart(); }
                }
                NumberAnimation { id: fadeOther; target: backdrop; property: "amount"; to: 0; duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bezier }

                // keyboard: Esc clears, any key focuses the field
                Item {
                    anchors.fill: parent
                    z: -1
                    Keys.onEscapePressed: pwd.reset()
                }
            }
        }
    }
}
