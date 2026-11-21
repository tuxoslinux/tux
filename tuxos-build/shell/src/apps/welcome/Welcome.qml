import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Welcome (mockup apps/11-welcome): opens once, at the first login after
// the install. Six steps: language and keyboard, look (wallpaper, accent,
// light / dark), default apps, gaming, privacy, shortcuts. Everything can
// be changed later in Settings; Done (or closing it) does not ask again.
AppWindow {
    id: app
    appName: "Welcome to TuxOS"
    appIcon: 0xf0004
    implicitWidth: 1180; implicitHeight: 760
    property int step: 0
    readonly property var titles: ["Hello", "Make it yours", "Your apps", "Games", "Privacy", "Shortcuts"]
    readonly property var subs: [
        "TuxOS is ready. A few choices and you are done - all of them can be changed later in Settings.",
        "Pick a wallpaper and an accent colour. You can change both later in Settings.",
        "What TuxOS' shortcuts open. Super + B opens the browser, Super + W the terminal.",
        "Steam, Proton and the game tools. TuxOS switches into game mode by itself whenever a game runs.",
        "Everything stays on this PC. Choose what TuxOS keeps.",
        "The keys worth knowing. Super + / shows all of them, any time."
    ]
    readonly property string doneMark: Quickshell.env("HOME") + "/.local/state/tuxos/welcome-done"
    function finish() {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && touch \"$1\"", "sh", doneMark]);
        Qt.quit();
    }
    canClose: function() { Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && touch \"$1\"", "sh", doneMark]); return true; }

    // ---- progress
    Column {
        id: head
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 28 }
        spacing: 8
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Repeater {
                model: 6
                delegate: Rectangle {
                    required property int index
                    width: index === app.step ? 40 : 18; height: 5; radius: 3
                    color: index <= app.step ? Theme.accent : Theme.ink(0.18)
                    Behavior on width { enabled: !Theme.reduceMotion; Spring {} }
                }
            }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Tr.f("Step {i} of {n}", { i: app.step + 1, n: 6 }); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        Item { width: 1; height: 10 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Tr.t(app.titles[app.step]); font.family: Theme.font; font.pixelSize: Theme.px(36); font.weight: Font.Bold; color: Theme.text }
        Text { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(760, app.width - 80); horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: Tr.t(app.subs[app.step]); font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.muted }
    }

    // ---- the steps
    Item {
        id: body
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 28; bottom: foot.top; bottomMargin: 16; leftMargin: 44; rightMargin: 44 }

        // 1: language and keyboard
        Column {
            visible: app.step === 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(640, parent.width)
            spacing: 16
            SettingCard {
                width: parent.width
                SettingRow { title: "Language"; description: "TuxOS' shell and apps"; Segmented { width: 260; options: ["English", "Български"]; current: Prefs.language === "bg" ? 1 : 0; onPicked: i => Prefs.language = i === 1 ? "bg" : "en" } }
                SettingRow { title: "Keyboard"; description: kb.out.trim() ? kb.out.trim().split(",").map(c => Tr.t(({ us: "English (US)", gb: "English (UK)", bg: "Bulgarian", de: "German", fr: "French", es: "Spanish", it: "Italian", ru: "Russian", ua: "Ukrainian", gr: "Greek", tr: "Turkish", ro: "Romanian", pl: "Polish" })[c] || c)).join(", ") : Tr.t("English (US)"); last: true; Btn { text: "Change..."; onClicked: Quickshell.execDetached(["tuxos-app", "control", "--page", "keyboard"]) } }
            }
            Cmd { id: kb; command: ["sh", "-c", "hyprctl -j devices 2>/dev/null | jq -r '[.keyboards[] | select(.main) | .layout] | first // empty'"]; Component.onCompleted: run() }
            Rectangle {
                visible: app.recoveryKey === ""          // room for the recovery key while it is shown
                width: parent.width; height: 48; radius: 12
                color: Theme.ink(0.05); border.width: 1; border.color: tryField.activeFocus ? Theme.accentLine : Theme.glassLine
                TextInput {
                    id: tryField
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.font; font.pixelSize: Theme.px(15); color: Theme.text
                    Text { visible: tryField.text === ""; text: Tr.t("Try the keyboard here · Alt + Shift switches the layout"); font: tryField.font; color: Theme.dim; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            // the encrypted disk's recovery key (installer, tuxoscrypt): shown once
            SettingCard {
                visible: app.hasKey
                width: parent.width
                header: Tr.t("Your disk's recovery key")
                // the key itself: large, whole, selectable (4 groups a line)
                Item {
                    visible: app.recoveryKey !== ""
                    width: parent.width; height: keyText.implicitHeight + 28
                    TextEdit {
                        id: keyText
                        x: 24; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 48
                        readOnly: true; selectByMouse: true; selectionColor: Theme.accentFill
                        text: app.recoveryKey.split("-").reduce((a, g, i) => a + (i === 0 ? "" : (i % 4 === 0 ? "\n" : "  -  ")) + g, "")
                        horizontalAlignment: TextEdit.AlignHCenter
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Theme.px(20); font.weight: Font.DemiBold; color: Theme.text
                    }
                }
                SettingRow {
                    title: app.recoveryKey ? Tr.t("Keep it safe") : Tr.t("Opens the encrypted disk if you forget its password")
                    description: app.recoveryKey ? Tr.t("Write it down, away from this PC. TuxOS will not show it again.") : Tr.t("Shown only once")
                    last: true
                    Btn {
                        text: app.recoveryKey ? Tr.t("I wrote it down") : Tr.t("Show it"); primary: app.recoveryKey !== ""
                        onClicked: { if (app.recoveryKey) { forgetKey.running = true; } else showKey.running = true; }
                    }
                }
            }
        }

        // 2: look
        Column {
            visible: app.step === 1
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Repeater {
                    model: walls.out.split("\n").filter(x => x).slice(0, 4)
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool cur: app.wallpaper === modelData
                        width: Math.min(250, (body.width - 60) / 4); height: width * 0.62; radius: 16
                        color: Theme.fill
                        border.width: cur ? 3 : 0; border.color: Theme.accent
                        clip: true
                        Image { anchors { fill: parent; margins: parent.cur ? 3 : 0 } source: "file://" + modelData; sourceSize: Qt.size(500, 310); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        TapHandler { onTapped: app.setWallpaper(modelData) }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Repeater {
                    model: ["#8fb8ff", "#8fe3c0", "#b9a8ff", "#ff9fb3", "#ffd08f", "#e8eefa"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 42; height: 42; radius: 21; color: modelData
                        border.width: Theme.accent.toString() === Qt.color(modelData).toString() ? 3 : 0; border.color: Theme.text
                        TapHandler { onTapped: Prefs.accent = modelData }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
            Segmented { anchors.horizontalCenter: parent.horizontalCenter; width: 320; options: ["Dark", "Light", "Auto"]; current: ["dark", "light", "auto"].indexOf(Prefs.lightMode); onPicked: i => Prefs.lightMode = ["dark", "light", "auto"][i] }
        }
        Cmd { id: walls; command: ["sh", "-c", "ls -1 /usr/share/tuxos/wallpapers/*.jpg /usr/share/tuxos/wallpapers/*.png 2>/dev/null"]; Component.onCompleted: run() }

        // 3: default apps
        Column {
            visible: app.step === 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(700, parent.width)
            spacing: 16
            SettingCard {
                width: parent.width
                SettingRow { title: "Browser"; description: "Super + B"; ChoiceList { options: app.list("WebBrowser", /helium|firefox|chrom|brave|librewolf|zen/); current: Prefs.browser; onPicked: v => { Prefs.browser = v; Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", v + ".desktop"]); } } }
                SettingRow { title: "Terminal"; description: "Super + W"; ChoiceList { options: app.list("TerminalEmulator", /kitty|foot|alacritty|wezterm|ghostty|konsole/); current: Prefs.terminal; onPicked: v => Prefs.terminal = v } }
                SettingRow { title: "Music"; description: "Super + V"; ChoiceList { options: app.list("Audio", /spotify|music|strawberry|rhythmbox|elisa|amberol|audacious/); current: Prefs.music; onPicked: v => Prefs.music = v } }
                SettingRow { title: "Messaging"; description: "Super + M"; last: true; ChoiceList { options: app.list("InstantMessaging", /discord|vesktop|telegram|signal|viber|element/); current: Prefs.messaging; onPicked: v => Prefs.messaging = v } }
            }
            Text { width: parent.width; wrapMode: Text.Wrap; text: Tr.t("Missing one? The Store has Discord, Spotify, Telegram and more."); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        }

        // 4: games
        Column {
            visible: app.step === 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(700, parent.width)
            spacing: 16
            Cmd { id: steamCheck; command: ["sh", "-c", "pacman -Q steam >/dev/null 2>&1 && echo yes"]; Component.onCompleted: run() }
            Cmd { id: gaming; command: ["pkexec", "tuxos-gaming"]; onDone: (out, code) => { steamCheck.run(); app.installing = false; } }
            SettingCard {
                width: parent.width
                SettingRow {
                    title: "Gaming set"; description: steamCheck.out.trim() === "yes" ? "Steam, Proton-CachyOS, gamescope" + " · " + Tr.t("installed") : "Steam, Proton-CachyOS, umu, ProtonPlus, MangoHud, gamemode, gamescope"
                    Btn { visible: steamCheck.out.trim() !== "yes"; text: app.installing ? "Installing..." : "Install"; primary: true; onClicked: { if (!app.installing) { app.installing = true; gaming.run(); } } }
                }
                SettingRow { title: "Quiet while a game runs"; description: "Do not disturb until the game closes"; Toggle { checked: Prefs.gameSilence; onToggled: v => Prefs.gameSilence = v } }
                SettingRow { title: "Game HUD"; description: "Super + Shift + G: FPS, lows, frame times, temperatures (MangoHud)"; last: true }
            }
        }

        // 5: privacy
        Column {
            visible: app.step === 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(700, parent.width)
            spacing: 16
            SettingCard {
                width: parent.width
                SettingRow { title: "Clipboard history"; description: "Super + C · RAM only, gone at shutdown · password managers skipped"; Toggle { checked: Prefs.clipboardHistory; onToggled: v => Prefs.clipboardHistory = v } }
                SettingRow { title: "Screen time"; description: "Time per app and game, stored only here"; Toggle { checked: Prefs.screenTime; onToggled: v => Prefs.screenTime = v } }
                SettingRow { title: "Local AI"; description: "An assistant that runs only on this PC. Nothing leaves it."; Toggle { checked: Prefs.aiEnabled; onToggled: v => Prefs.aiEnabled = v } }
                SettingRow { title: "Private DNS with ad blocking"; description: "AdGuard DNS instead of the network's: blocks ads and trackers for every app"; last: true; Btn { text: "Settings"; onClicked: Quickshell.execDetached(["tuxos-app", "control", "--page", "network"]) } }
            }
            Text { width: parent.width; wrapMode: Text.Wrap; text: Tr.t("TuxOS sends nothing anywhere: no account, no tracking, no crash reports unless you send one yourself."); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
        }

        // 6: shortcuts
        Grid {
            visible: app.step === 5
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 2
            columnSpacing: 40; rowSpacing: 12
            Repeater {
                model: [["Super", "Apps, files and settings"], ["Super + 1 ... 9", "Go to a desktop"], ["Alt + Tab", "Switch windows"], ["Super + Space", "Mission Control"],
                        ["Super + Q", "Close the app"], ["Super + Z", "Snap layouts"], ["Super + Shift + S", "Take a screenshot"], ["Super + C", "Clipboard"],
                        ["Super + N", "Notifications"], ["Super + Shift + G", "Game HUD"], ["Super + L", "Lock the screen"], ["Super + /", "All shortcuts"]]
                delegate: Row {
                    required property var modelData
                    spacing: 12
                    Rectangle { width: 170; height: 36; radius: 10; color: Theme.ink(0.08); border.width: 1; border.color: Theme.glassLine
                        Text { anchors.centerIn: parent; text: modelData[0]; font.family: Theme.font; font.pixelSize: Theme.px(13); font.weight: Font.DemiBold; color: Theme.text } }
                    Text { width: 250; anchors.verticalCenter: parent.verticalCenter; text: Tr.t(modelData[1]); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
                }
            }
        }
    }
    property bool installing: false
    property string wallpaper: ""
    property bool hasKey: false
    property string recoveryKey: ""
    Process { command: ["sh", "-c", "command -v tuxos-recovery-key >/dev/null && tuxos-recovery-key has"]; running: true; onExited: code => app.hasKey = code === 0 }
    Process { id: showKey; command: ["pkexec", "tuxos-recovery-key", "show"]; stdout: StdioCollector { onStreamFinished: app.recoveryKey = text.trim() } }
    Process { id: forgetKey; command: ["pkexec", "tuxos-recovery-key", "forget"]; onExited: { app.hasKey = false; app.recoveryKey = ""; } }
    function setWallpaper(f) {
        wallpaper = f;
        Quickshell.execDetached(["qs", "-c", "tuxos", "ipc", "call", "wallpaper", "set", f, "default"]);
    }
    function list(cat, words) {
        return DesktopEntries.applications.values.filter(e => !e.noDisplay && (Array.from(e.categories || []).indexOf(cat) !== -1 || words.test((e.id + " " + e.name).toLowerCase())))
                .map(e => ({ value: e.id, label: e.name }));
    }

    // ---- back / next
    Item {
        id: foot
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 28 }
        height: 44
        Btn { visible: app.step > 0; text: "Back"; anchors.verticalCenter: parent.verticalCenter; onClicked: app.step-- }
        Text {
            anchors.centerIn: parent
            visible: app.recoveryKey === ""
            text: app.step < 5 ? Tr.t("Next") + ": " + app.titles.slice(app.step + 1).map(t => Tr.t(t).toLowerCase()).join(" · ") : ""
            font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.dim
        }
        Btn { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: app.step < 5 ? "Continue" : "Done"; primary: true; onClicked: app.step < 5 ? app.step++ : app.finish() }
    }
}
