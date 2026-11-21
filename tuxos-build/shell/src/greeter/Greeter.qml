import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.theme
import qs.components
import qs.services
import qs.lock

// Login screen (SPEC login-v3), run by greetd inside cage: the blurred
// wallpaper and one wide glass card (1040 x 500, radius 40) split by a thin
// line: a big clock (150 px, blue colon) and the date on the left; the avatar
// in a blue ring, the name and the password field on the right. Session
// choice bottom left (TuxOS desktop, Game Mode, Console and any other
// installed desktop), sleep / restart / shut down bottom right. More than one
// user: a picker. Same password feedback and unlock motion as the lock screen.
Scope {
    id: root

    // ---- users (uid 1000-59999 with a real shell)
    property var users: []
    property int userIndex: 0
    readonly property var user: users[userIndex] || ({ name: "", full: "", avatar: "" })
    Process {
        running: true
        command: ["sh", "-c", "getent passwd | awk -F: '$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1\":\"$5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.users = text.split("\n").filter(l => l).map(l => {
                    const [name, gecos] = l.split(":");
                    const full = (gecos || "").split(",")[0] || name;
                    return { name: name, full: full, avatar: "/var/lib/AccountsService/icons/" + name };
                });
                const i = root.users.findIndex(u => u.name === state.lastUser);
                root.userIndex = i >= 0 ? i : 0;
            }
        }
    }

    // ---- the user's wallpaper and its depth effect: each user's shell
    // copies its wallpaper to /var/lib/tuxos-login-wallpapers/<user>.wallpaper
    // (a sticky shared folder; only a file owned by that user counts, and
    // <user>.nodepth when the depth effect is off). The login screen makes
    // its own mask once per picture (in its state folder), the same way the
    // shell does; no subject found: the usual layout.
    readonly property string depthDir: (Quickshell.env("XDG_STATE_HOME") || "/var/lib/tuxos-greeter") + "/depth"
    property string wall: "/usr/share/tuxos/wallpaper.png"
    property string wallKey: ""
    property string depthMask: ""
    property bool depthWanted: false        // look for a subject in `wall`
    readonly property bool depth: depthMask !== ""
    onUserChanged: if (user.name) { wallProc.running = false; wallProc.running = true; }
    Process {
        id: wallProc
        command: ["sh", "-c", "u=\"$1\" d=/var/lib/tuxos-login-wallpapers c=\"$2\" f=/usr/share/tuxos/wallpaper.png; uid=$(id -u \"$u\" 2>/dev/null); "
                  + "w=\"$d/$u.wallpaper\"; if [ -n \"$uid\" ] && [ -f \"$w\" ] && [ ! -L \"$w\" ] && [ \"$(stat -c %u \"$w\")\" = \"$uid\" ]; then f=\"$w\"; fi; echo \"$f\"; "
                  + "n=\"$d/$u.nodepth\"; if [ -f \"$n\" ] && [ \"$(stat -c %u \"$n\")\" = \"$uid\" ]; then echo off; else echo on; fi; "
                  + "mkdir -p \"$c\"; k=$(md5sum < \"$f\" | cut -c1-16); echo \"$k\"; if [ -s \"$c/$k.png\" ]; then echo yes; elif [ -e \"$c/$k.none\" ]; then echo none; fi",
                  "sh", root.user.name, root.depthDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").map(x => x.trim());
                root.wall = l[0] || "/usr/share/tuxos/wallpaper.png";
                root.wallKey = l[2] || "";
                const on = l[1] === "on";
                root.depthMask = on && l[3] === "yes" ? root.depthDir + "/" + root.wallKey + ".png" : "";
                root.depthWanted = on && root.wallKey !== "" && l[3] !== "yes" && l[3] !== "none";
            }
        }
    }

    // ---- sessions: TuxOS desktop first, Game Mode, Console, then others
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex] || ({ name: "TuxOS desktop", exec: ["tuxos-session"] })
    Process {
        running: true
        command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do [ -e \"$f\" ] || continue; n=$(sed -n 's/^Name=//p' \"$f\" | head -1); e=$(sed -n 's/^Exec=//p' \"$f\" | head -1); echo \"$(basename \"$f\" .desktop)|$n|$e\"; done; command -v gamescope >/dev/null && command -v steam >/dev/null && echo 'gamemode|Game Mode|gamescope -e -f -- steam -gamepadui -steamos3'; echo 'console|Console|bash -l'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l).map(l => {
                    const p = l.split("|");
                    return { id: p[0], name: p[1], exec: p[2].split(" ").filter(x => x) };
                });
                list.sort((a, b) => (b.id === "tuxos") - (a.id === "tuxos"));
                const tux = list.filter(s => s.id === "tuxos");
                // safe mode: TuxOS without the user's own settings files (the
                // way back when a setting keeps the desktop from starting)
                const safe = tux.length ? [{ id: "tuxos-safe", name: Tr.t("TuxOS desktop (safe mode)"), exec: ["env", "TUXOS_SAFE=1", "tuxos-session"] }] : [];
                const out = tux.concat(safe).concat(list.filter(s => s.id !== "tuxos"));
                root.sessions = out;
                // safe mode is for one start: next time the full desktop again
                let i = out.findIndex(s => s.id === (state.lastSession === "tuxos-safe" && !state.failed ? "tuxos" : state.lastSession));
                if (state.failed && (state.lastSession === "tuxos" || state.lastSession === "tuxos-safe")) {
                    const other = out.findIndex(s => s.id === (state.lastSession === "tuxos" ? "tuxos-safe" : "console"));
                    if (other >= 0) i = other;
                    root.notice = state.lastSession === "tuxos"
                        ? Tr.t("The desktop stopped right after it started. Safe mode starts it without your own settings (monitors, keys, rules); Settings can fix them there.")
                        : Tr.t("Safe mode stopped too. The console works; your settings are in ~/.config/hypr.");
                }
                root.sessionIndex = i >= 0 ? i : 0;
            }
        }
    }

    // remembered between logins (XDG_STATE_HOME=/var/lib/tuxos-greeter)
    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_STATE_HOME") || "/var/lib/tuxos-greeter") + "/greeter.json"
        onLoaded: {
            try {
                const j = JSON.parse(text());
                state.lastUser = j.user || ""; state.lastSession = j.session || "";
                // back here within 25 s of starting a desktop: it stopped right away
                state.failed = (j.at || 0) > 0 && Date.now() - j.at < 25000 && j.session !== "console";
            } catch (e) {}
        }
    }
    QtObject { id: state; property string lastUser: ""; property string lastSession: ""; property bool failed: false }

    // ---- greetd conversation
    signal wrong()
    signal right()
    property string pending: ""
    property string message: ""
    property string notice: ""             // the last desktop stopped right away
    function login(pw) {
        pending = pw;
        message = "";
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
        Greetd.createSession(user.name);
    }
    Connections {
        target: Greetd
        function onAuthMessage(msg, error, responseRequired, echo) {
            if (responseRequired) { Greetd.respond(root.pending); root.pending = ""; }
            else if (msg) { root.message = msg; Greetd.respond(""); }
        }
        function onAuthFailure(msg) { root.message = ""; Greetd.cancelSession(); root.wrong(); }
        function onReadyToLaunch() {
            stateFile.setText(JSON.stringify({ user: root.user.name, session: root.session.id, at: Date.now() }));
            root.right();
        }
        function onError(e) { root.message = e; root.wrong(); }
    }
    function launchNow() {
        Greetd.launch(root.session.exec, ["XDG_SESSION_TYPE=" + (root.session.id === "console" ? "tty" : "wayland"),
                                          "XDG_CURRENT_DESKTOP=" + (root.session.id.startsWith("tuxos") ? "TuxOS:Hyprland" : root.session.name)], true);
    }

    // boot time: when the login screen is ready (seconds since power-on)
    // (once per boot: a login screen that comes back after a log out is not a boot)
    Process { running: true; command: ["sh", "-c", "b=$(cat /proc/sys/kernel/random/boot_id); [ \"$(cat /tmp/tuxos-greeter-boot 2>/dev/null)\" = \"$b\" ] && exit 0; echo \"$b\" > /tmp/tuxos-greeter-boot; awk '{print $1}' /proc/uptime > /tmp/tuxos-greeter-ready"] }

    FloatingWindow {
        id: win
        color: "black"
        title: Tr.t("TuxOS login")

        Backdrop {
            id: backdrop
            anchors.fill: parent
            source: "file://" + root.wall
            // the depth effect keeps the wallpaper's subject recognisable
            blurScale: root.depth ? 0.2 : 1
        }
        SystemClock { id: clock; precision: SystemClock.Minutes }
        DepthClock {
            anchors.fill: parent
            backdrop: backdrop
            mask: root.depthMask
            date: clock.date
            contentOpacity: card.opacity
        }
        // looks for the subject once per picture
        Loader {
            active: root.depthWanted
            sourceComponent: DepthMask {
                source: "file://" + root.wall
                onMade: {
                    const k = root.wallKey, f = root.depthDir + "/" + k + ".png";
                    if (!found) { Quickshell.execDetached(["sh", "-c", ": > \"$1/$2.none\"", "sh", root.depthDir, k]); root.depthWanted = false; return; }
                    // saved first, then the maker is unloaded
                    Qt.callLater(() => { if (save(f)) root.depthMask = f; root.depthWanted = false; });
                }
            }
        }

        // the last desktop stopped right away: why safe mode is chosen
        Rectangle {
            visible: root.notice !== ""
            anchors { horizontalCenter: parent.horizontalCenter; bottom: wrap.top; bottomMargin: 16 * wrap.scale }
            width: Math.min(win.width - 48, noticeText.implicitWidth + 40); height: noticeText.implicitHeight + 24; radius: 16
            color: Theme.glassPanel; border.width: 1; border.color: Theme.warn
            Text { id: noticeText; anchors.centerIn: parent; width: Math.min(implicitWidth, win.width - 88); wrapMode: Text.Wrap; text: root.notice
                   font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
        }
        Item {
            id: wrap
            anchors.centerIn: parent
            // depth effect: compact at the bottom, the subject stays in view
            anchors.verticalCenterOffset: root.depth ? win.height * 0.5 - height * scale / 2 - 48 : 0
            width: root.depth ? 560 : 1040; height: root.depth ? 200 : 500
            scale: Math.min(1, (win.width - 48) / width, (win.height - 48) / height)

            Rectangle {
                id: card
                anchors.fill: parent
                radius: 40
                color: Qt.rgba(Theme.glassBase.r, Theme.glassBase.g, Theme.glassBase.b, Theme.lite ? 0.92 : (Theme.light ? 0.62 : 0.42))
                border.width: 1; border.color: Theme.glassLine
                Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 40; rightMargin: 40; topMargin: 1 } height: 1; color: Theme.glassHighlight }

                // depth layout: a greeting instead of clock + avatar
                Text {
                    visible: root.depth
                    x: 40; y: 32
                    text: Tr.f("Welcome back, {n}", { n: root.user.full.split(" ")[0] || root.user.name })
                    font.family: Theme.font; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; color: Theme.text
                }
                // left: big clock + date
                Column {
                    visible: !root.depth
                    x: 85
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -10
                    Text {
                        textFormat: Text.StyledText
                        text: Qt.formatTime(clock.date, "HH") + `<font color="${Theme.accent}">:</font>` + Qt.formatTime(clock.date, "mm")
                        font.family: Theme.font; font.pixelSize: Theme.px(150); font.weight: Font.Bold; font.letterSpacing: -5
                        color: Theme.text
                    }
                    Text {
                        leftPadding: 4
                        text: Tr.date(clock.date, "dddd, d MMMM")
                        font.family: Theme.font; font.pixelSize: Theme.px(20); color: Theme.muted
                    }
                }
                Rectangle { visible: !root.depth; x: 520; y: 100; width: 1; height: 300; color: Theme.glassLine }

                // right: user picker (more than one user), avatar, name
                Row {
                    visible: root.users.length > 1
                    x: root.depth ? parent.width - width - 40 : right.x + (right.width - width) / 2
                    y: root.depth ? 24 : 28
                    spacing: 8
                    Repeater {
                        model: root.users
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: 40; height: 40; radius: 20
                            color: Theme.ink(0.06)
                            border.width: 2; border.color: root.userIndex === index ? Theme.accent : "transparent"
                            Text { anchors.centerIn: parent; text: modelData.full.charAt(0).toUpperCase(); font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: { root.userIndex = index; pwd.reset(); pwd.focusField(); } }
                        }
                    }
                }
                Item {
                    id: right
                    visible: !root.depth
                    x: 520; width: 520; height: parent.height
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 120
                        spacing: 12
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 112; height: 112; radius: 56
                            color: Qt.rgba(11 / 255, 20 / 255, 36 / 255, 0.9)
                            border.width: 2; border.color: Theme.accent
                            Rectangle {
                                anchors.centerIn: parent
                                width: 128; height: 128; radius: 64
                                color: "transparent"
                                border.width: 6; border.color: Qt.rgba(143 / 255, 184 / 255, 1, 0.12)
                            }
                            Image {
                                id: face
                                anchors.centerIn: parent
                                width: 108; height: 108
                                source: "file://" + root.user.avatar
                                sourceSize: Qt.size(216, 216)
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                                layer.enabled: true
                            }
                            Image {
                                anchors.centerIn: parent
                                visible: face.status !== Image.Ready
                                source: Qt.resolvedUrl("../assets/tux.png")
                                width: 64; height: 64; sourceSize: Qt.size(128, 128)
                                mipmap: true
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.user.full
                            font.family: Theme.font; font.pixelSize: Theme.px(22); font.weight: Font.Medium; color: Theme.text
                        }
                        Item { width: 1; height: 8 }
                    }
                }

                // bottom left: session choice
                Item {
                    x: 36; y: parent.height - 62
                    width: sessRow.implicitWidth + 16; height: 32
                    Row {
                        id: sessRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text { text: root.session.name; font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.muted }
                        Sym { code: Icons.chevronDown; font.pixelSize: Theme.px(15); color: Theme.muted }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: sessMenu.visible = !sessMenu.visible }
                    Rectangle {
                        id: sessMenu
                        visible: false
                        y: -height - 8
                        width: 240; height: sessCol.implicitHeight + 12; radius: 16
                        color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
                        Column {
                            id: sessCol
                            anchors { fill: parent; margins: 4 }
                            Repeater {
                                model: root.sessions
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: sessCol.width; height: 36; radius: 11
                                    color: root.sessionIndex === index ? Theme.accentFill : (sh.hovered ? Theme.fill : "transparent")
                                    Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: modelData.name; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                                    HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: { root.sessionIndex = index; sessMenu.visible = false; pwd.focusField(); } }
                                }
                            }
                        }
                    }
                }
                // bottom right: sleep / restart / shut down
                Row {
                    anchors { right: parent.right; rightMargin: 40; bottom: parent.bottom; bottomMargin: 32 }
                    spacing: 20
                    Repeater {
                        model: [[Icons.weatherNight, ["loginctl", "suspend"]], [Icons.restart, ["loginctl", "reboot"]], [Icons.power, ["loginctl", "poweroff"]]]
                        delegate: Sym {
                            required property var modelData
                            code: modelData[0]
                            font.pixelSize: Theme.px(19)
                            color: ph.hovered ? Theme.text : Theme.muted
                            HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: Quickshell.execDetached(modelData[1]) }
                        }
                    }
                }
            }
            // outside the card so the lock stays bright while the card fades
            PasswordBar {
                id: pwd
                x: root.depth ? 40 : 520 + (520 - width) / 2; y: root.depth ? 76 : 318
                message: root.message
                onSubmitted: pw => root.login(pw)
                onUnlocked: fadeOut.restart()
                Component.onCompleted: focusField()
            }
            Connections {
                target: root
                function onWrong() { pwd.wrong(); }
                function onRight() { pwd.success(); }
            }
        }
        ParallelAnimation {
            id: fadeOut
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: wrap; property: "scale"; to: wrap.scale * 1.04; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: backdrop; property: "amount"; to: 0; duration: 380; easing.type: Easing.OutCubic }
            onFinished: root.launchNow()
        }
    }
}
