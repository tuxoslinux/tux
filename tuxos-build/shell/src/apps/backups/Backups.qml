import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Backups (mockup apps/21-backup): copies of the home folder on another
// disk (tuxos-backup: dated folders, unchanged files hard-linked), daily /
// weekly / by hand (the shell checks every hour), what to skip, history
// with Open (in Files) and Restore (copies the files back; nothing newer
// is overwritten).
AppWindow {
    id: app
    appName: "Backups"
    appIcon: 0xf0062
    implicitWidth: 1000; implicitHeight: 760

    readonly property string cfgPath: Quickshell.env("HOME") + "/.config/tuxos/backups.json"
    property var cfg: ({ dest: "", schedule: "daily", skip: [] })
    FileView {
        id: cfgFile
        path: app.cfgPath
        printErrors: false
        onLoaded: { try { app.cfg = Object.assign({ dest: "", schedule: "daily", skip: [] }, JSON.parse(text())); } catch (e) {} history.run(); }
        onLoadFailed: history.run()
    }
    function setCfg(k, v) {
        const c = Object.assign({}, cfg); c[k] = v; cfg = c;
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.config/tuxos"]);
        cfgFile.setText(JSON.stringify(c, null, 1));
        if (k === "dest") Qt.callLater(() => history.run());
    }
    function skipToggle(p, on) { setCfg("skip", on ? cfg.skip.concat([p]) : cfg.skip.filter(x => x !== p)); }

    // state of the last backup
    property var st: ({})
    FileView { id: stFile; path: Quickshell.env("HOME") + "/.local/state/tuxos/backup-state.json"; printErrors: false; watchChanges: true; onFileChanged: reload()
        onLoaded: { try { app.st = JSON.parse(text()); } catch (e) {} } }

    // places to back up to: mounted drives other than the system ones
    property var drives: []
    Cmd {
        id: drivesProc
        command: ["sh", "-c", "lsblk -J -b -o NAME,LABEL,SIZE,FSAVAIL,MOUNTPOINT,MODEL,RM,TRAN | jq -c '[.blockdevices[] | (., .children[]?) | select(.mountpoint != null and .mountpoint != \"/\" and (.mountpoint | test(\"^/(boot|efi|home)$|^\\\\[SWAP\\\\]$\") | not))]'"]
        Component.onCompleted: run()
        onDone: out => { try { app.drives = JSON.parse(out); } catch (e) { app.drives = []; } }
    }
    Timer { interval: 5000; repeat: true; running: true; onTriggered: drivesProc.run() }
    readonly property bool connected: cfg.dest !== "" && drives.some(d => cfg.dest.startsWith(d.mountpoint)) || (cfg.dest !== "" && cfg.dest.startsWith(Quickshell.env("HOME")))

    // the backups made so far
    property var snaps: []
    Cmd {
        id: history
        command: ["sh", "-c", "d=\"$1/TuxOS Backups/$(id -un)@$(cat /etc/hostname 2>/dev/null || hostname)\"; [ -d \"$d\" ] || exit 0; ls -1d \"$d\"/20* 2>/dev/null | grep -v '\\.partial$' | sort -r", "sh", app.cfg.dest]
        onDone: out => app.snaps = out.split("\n").filter(x => x)
    }
    Process {
        id: runner
        command: ["tuxos-backup"]
        stderr: StdioCollector { id: errOut }
        onExited: code => { app.message = code === 0 ? Tr.t("Backup done") : (errOut.text.trim() || Tr.t("The backup did not finish")); history.run(); }
    }
    Process {
        id: restorer
        property string from: ""
        onExited: code => app.message = code === 0 ? Tr.t("Files restored") : Tr.t("Restore did not finish")
    }
    property string message: ""
    property string confirm: ""
    function when(t) {
        if (!t) return Tr.t("never");
        const d = new Date(t * 1000), now = new Date();
        return d.toDateString() === now.toDateString() ? Tr.t("Today") + ", " + Qt.formatTime(d, "HH:mm") : Tr.date(d, "d MMM yyyy, HH:mm");
    }
    function snapName(p) { const n = p.substring(p.lastIndexOf("/") + 1); const m = /^(\d{4})-(\d\d)-(\d\d) (\d\d)\.(\d\d)$/.exec(n); return m ? Tr.date(new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]), "dddd d MMMM yyyy, HH:mm") : n; }

    Flickable {
        anchors { fill: parent; margins: 28; topMargin: 20 }
        contentHeight: col.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: parent.width
            spacing: 16
            // status
            Rectangle {
                width: parent.width; height: 110; radius: 20
                color: Theme.accentFill; border.width: 1; border.color: Theme.accentLine
                Row {
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    spacing: 16
                    Text { text: String.fromCodePoint(runner.running ? 0xf0450 : (app.st.ok === false ? 0xf0026 : 0xf0062)); font.family: Theme.symbols; font.pixelSize: Theme.px(40); color: app.st.ok === false ? Theme.warn : Theme.accent; anchors.verticalCenter: parent.verticalCenter
                        RotationAnimation on rotation { running: runner.running; from: 0; to: 360; duration: 1400; loops: Animation.Infinite; alwaysRunToEnd: true } }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text { text: runner.running ? Tr.t("Backing up...") : (app.cfg.dest ? Tr.f("Last backup: {w}", { w: app.when(app.st.last) }) : Tr.t("Backups are not set up")); font.family: Theme.font; font.pixelSize: Theme.px(20); font.weight: Font.DemiBold; color: Theme.text }
                        Text { text: app.message || (app.cfg.dest ? (app.connected ? Tr.t("The backup place is connected") : Tr.t("Connect the backup disk to back up")) : Tr.t("Choose a disk below - a USB disk or a second drive")); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
                        Text { visible: (app.st.skipped || []).length > 0; text: Tr.f("Not readable, skipped: {f}", { f: (app.st.skipped || []).map(p => p.replace(Quickshell.env("HOME") + "/", "")).join(", ") }); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.warn }
                    }
                }
                Btn { anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter } text: runner.running ? "Backing up..." : "Back up now"; primary: true; enabled2: app.cfg.dest !== "" && !runner.running
                      onClicked: if (app.cfg.dest && !runner.running) { app.message = ""; runner.running = true; } }
            }
            SettingCard {
                width: parent.width
                header: "Where"
                SettingRow {
                    title: "Backup place"; description: app.cfg.dest ? app.cfg.dest : Tr.t("Not chosen")
                    ChoiceList {
                        options: app.drives.map(d => ({ value: d.mountpoint, label: d.label || (d.model ? d.model.trim() : d.name), sub: d.fsavail ? Tr.f("{n} free", { n: d.fsavail >= 1e9 ? (d.fsavail / 1e9).toFixed(0) + " GB" : Math.round(d.fsavail / 1e6) + " MB" }) : "" }))
                                 .concat(app.cfg.dest && !app.drives.some(d => d.mountpoint === app.cfg.dest) ? [{ value: app.cfg.dest, label: app.cfg.dest }] : [])
                        current: app.cfg.dest
                        onPicked: v => app.setCfg("dest", v)
                    }
                }
                SettingRow {
                    title: "When"; last: true
                    Segmented { width: 330; options: ["Every day", "Every week", "By hand"]; current: ["daily", "weekly", "off"].indexOf(app.cfg.schedule); onPicked: i => app.setCfg("schedule", ["daily", "weekly", "off"][i]) }
                }
            }
            SettingCard {
                width: parent.width
                header: "What is skipped"
                SettingRow { title: "Caches, Trash and Steam games"; description: "Always skipped: they come back by themselves" }
                SettingRow { title: "Downloads"; Toggle { checked: app.cfg.skip.indexOf("Downloads") !== -1; onToggled: v => app.skipToggle("Downloads", v) } }
                SettingRow { title: "Videos"; Toggle { checked: app.cfg.skip.indexOf("Videos") !== -1; onToggled: v => app.skipToggle("Videos", v) } }
                SettingRow { title: "Music"; last: true; Toggle { checked: app.cfg.skip.indexOf("Music") !== -1; onToggled: v => app.skipToggle("Music", v) } }
            }
            Text { visible: app.snaps.length > 0; text: Tr.t("HISTORY"); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
            Repeater {
                model: app.snaps
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: col.width; height: app.confirm === modelData ? 104 : 56; radius: 14
                    color: Theme.fill; border.width: 1; border.color: Theme.glassLine
                    Row {
                        x: 16; y: 16
                        spacing: 12
                        Text { text: String.fromCodePoint(0xf0062); font.family: Theme.symbols; font.pixelSize: Theme.px(18); color: index === 0 ? Theme.accent : Theme.muted }
                        Text { text: app.snapName(modelData); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                        Text { visible: index === 0; text: Tr.t("newest"); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 8 }
                        spacing: 8
                        Btn { text: "Open"; onClicked: Quickshell.execDetached(["tuxos-app", "files", "--page", modelData]) }
                        Btn { text: "Restore..."; onClicked: app.confirm = app.confirm === modelData ? "" : modelData }
                    }
                    Row {
                        visible: app.confirm === modelData
                        x: 16; y: 58
                        spacing: 12
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Copy these files back into your home folder? Files you changed since then stay as they are."); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted; width: col.width - 260; wrapMode: Text.Wrap }
                        Btn { text: "Restore"; primary: true; onClicked: { app.confirm = ""; app.message = Tr.t("Restoring..."); restorer.command = ["rsync", "-a", "--update", modelData + "/", Quickshell.env("HOME") + "/"]; restorer.running = true; } }
                    }
                }
            }
        }
    }
}
