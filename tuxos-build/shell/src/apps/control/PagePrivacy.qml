import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Privacy & security: screen lock, clipboard history, screen time, what is
// using the microphone / camera / screen right now.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Privacy & security"); description: Tr.t("What TuxOS keeps, and who can see and hear you.") }
    SettingCard {
        header: Tr.t("Right now")
        SettingRow { title: Privacy.list.length ? Privacy.list.map(x => x.app + " (" + x.kind.toLowerCase() + ")").join(", ") : "Nothing uses the microphone, camera or screen"; description: Tr.t("An orange pill in the bar shows it while it happens"); last: true }
    }
    SettingCard {
        header: Tr.t("Kept on this PC")
        SettingRow { title: Tr.t("Clipboard history"); description: Tr.t("Super + C · RAM only, gone at shutdown · password managers skipped"); Toggle { checked: Prefs.clipboardHistory; onToggled: v => Prefs.clipboardHistory = v } }
        SettingRow { title: Tr.t("Screen time"); description: Tr.t("Time per app and game, stored only here"); Toggle { checked: Prefs.screenTime; onToggled: v => { Prefs.screenTime = v; if (!v) ScreenTime.clear(); } } }
        SettingRow { title: Tr.t("Lock the screen after"); last: true
            Segmented { width: 440; options: ["2 min", "5 min", "10 min", "30 min", "Never"]; current: [2, 5, 10, 30, 0].indexOf(Prefs.lockMinutes); onPicked: i => Prefs.lockMinutes = [2, 5, 10, 30, 0][i] } }
    }

    // ---- search inside files (tuxos-index): local only, built when idle
    property string ixStatus: ""
    Cmd { id: ixCmd; command: ["tuxos-index", "status"]; Component.onCompleted: run()
          onDone: out => { const f = out.trim().split(" "); page.ixStatus = f[2] && f[2] !== "0" ? Tr.f("{n} files · {s} · updated {t}", { n: f[0], s: Activities.size(parseInt(f[1])), t: Tr.date(new Date(parseInt(f[2]) * 1000), "d MMM, HH:mm") }) : Tr.t("Not built yet: it is made when the PC is idle"); } }
    SettingCard {
        header: Tr.t("Search inside files")
        SettingRow {
            title: Tr.t("Find text inside documents and notes"); description: Tr.t("The launcher also finds words inside files in Documents, Desktop, Notes, Downloads and Projects. The index stays on this PC, is made when the PC is idle and never during games.")
            Toggle { checked: Prefs.fileIndex; onToggled: v => Prefs.fileIndex = v }
        }
        SettingRow {
            visible: Prefs.fileIndex; last: true
            title: Tr.t("Index"); description: page.ixStatus
            Row { spacing: 8
                Btn { text: Tr.t("Update now"); onClicked: { Quickshell.execDetached(["sh", "-c", "nice -n 19 tuxos-index build"]); ixLater.restart(); } }
                Btn { text: Tr.t("Folders..."); onClicked: Quickshell.execDetached(["sh", "-c", "f=\"$HOME/.config/tuxos/index-folders\"; [ -s \"$f\" ] || printf '# folders inside your home to search in, one per line\\nDocuments\\nDesktop\\nNotes\\nDownloads\\nProjects\\n' > \"$f\"; xdg-open \"$f\""]) }
            }
        }
    }
    Timer { id: ixLater; interval: 4000; onTriggered: ixCmd.run() }
    // ---- Secure Boot (SPEC round 7 #16): shim + this PC's TuxOS key (tuxos-secureboot)
    property var sb: ({ sb: "none", mok: "none", shim: false })
    property string sbPassword: ""
    property bool sbWorking: false
    Cmd {
        id: sbSt
        command: ["sh", "-c", "command -v tuxos-secureboot >/dev/null && tuxos-secureboot status"]
        Component.onCompleted: run()
        onDone: out => { const o = { sb: "none", mok: "none", shim: false }; for (const l of out.split("\n")) { const p = l.split(" "); if (p[0] === "sb") o.sb = p[1]; else if (p[0] === "mok") o.mok = p[1]; else if (p[0] === "shim") o.shim = p[1] === "yes"; } page.sb = o; }
    }
    Process {
        id: sbOn
        command: ["pkexec", "tuxos-secureboot", "enable"]
        stdout: StdioCollector { onStreamFinished: { const m = /password (\d+)/.exec(text); page.sbPassword = m ? m[1] : ""; } }
        onExited: { page.sbWorking = false; sbSt.run(); }
    }
    SettingCard {
        visible: page.sb.sb !== "none"
        header: Tr.t("Secure Boot")
        SettingRow {
            title: page.sb.sb === "on" && page.sb.mok === "enrolled" ? Tr.t("On, with TuxOS' key") : page.sb.mok === "pending" || page.sbPassword ? Tr.t("One step at the next start") : Tr.t("Secure Boot for TuxOS")
            description: page.sb.sb === "on" && page.sb.mok === "enrolled" ? Tr.t("TuxOS starts with Secure Boot on; Windows games with anti-cheat that need it work in dual boot")
                       : page.sb.mok === "enrolled" ? Tr.t("TuxOS is ready; turn Secure Boot on in the PC's firmware settings")
                       : Tr.t("Lets you keep Secure Boot on (Windows anti-cheat in dual boot). TuxOS signs its start with a key made for this PC")
            last: !(page.sb.mok === "pending" || page.sbPassword)
            Btn {
                visible: page.sb.mok !== "enrolled"
                text: page.sbWorking ? Tr.t("Setting up...") : (page.sb.mok === "pending" ? Tr.t("Set up again") : Tr.t("Set up"))
                primary: page.sb.mok === "none"; enabled2: !page.sbWorking
                onClicked: { page.sbWorking = true; sbOn.running = true; }
            }
        }
        // what to do on the firmware's blue screen at the next start
        Item {
            visible: page.sb.mok === "pending" || page.sbPassword !== ""
            width: parent.width; height: steps.implicitHeight + 24
            Text {
                id: steps
                x: 24; y: 8; width: parent.width - 48
                wrapMode: Text.Wrap; textFormat: Text.StyledText; lineHeight: 1.3
                font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted
                text: Tr.t("Restart. A blue screen (MokManager) appears: press a key, choose <b>Enroll MOK</b>, Continue, Yes, type the password below, then Reboot.") + "<br>"
                    + Tr.t("If it shows no Enroll MOK: choose <b>Enroll key from disk</b> and pick EFI / TuxOS / TuxOS-key.cer (no password needed).") + "<br>"
                    + Tr.t("Then turn Secure Boot on in the firmware settings if it is off.")
            }
        }
        SettingRow {
            visible: page.sbPassword !== ""
            title: Tr.f("One-time password: {p}", { p: page.sbPassword }); description: Tr.t("Only for that blue screen; write it down before you restart"); last: true
            Btn { text: Tr.t("Restart now"); onClicked: Quickshell.execDetached(["loginctl", "reboot"]) }
        }
    }
    // ---- TPM unlock (SPEC round 7 #17): GRUB opens the encrypted disk with a
    // key sealed in the TPM (tuxos-tpm); the password stays as the fallback
    property var tpm: ({ tpm: false, disk: "", sb: false, on: false })
    property bool tpmWorking: false
    property string tpmError: ""
    Cmd {
        id: tpmSt
        command: ["sh", "-c", "command -v tuxos-tpm >/dev/null && tuxos-tpm status"]
        Component.onCompleted: run()
        onDone: out => { const o = { tpm: false, disk: "", sb: false, on: false }; for (const l of out.split("\n")) { const p = l.split(" "); if (p[0] === "tpm") o.tpm = p[1] === "yes"; else if (p[0] === "disk") o.disk = p[1]; else if (p[0] === "secureboot") o.sb = p[1] === "yes"; else if (p[0] === "enabled") o.on = p[1] === "yes"; } page.tpm = o; }
    }
    Process {
        id: tpmSet
        property bool want: false
        command: ["pkexec", "tuxos-tpm", want ? "enable" : "disable"]
        stderr: StdioCollector { onStreamFinished: page.tpmError = text.replace(/^tuxos-tpm: /, "").trim() }
        onExited: { page.tpmWorking = false; tpmSt.run(); }
    }
    SettingCard {
        visible: page.tpm.disk === "encrypted"
        header: Tr.t("Disk encryption")
        SettingRow {
            title: Tr.t("Open the disk with the TPM")
            description: page.tpmWorking ? Tr.t("Setting up...")
                       : page.tpmError !== "" ? page.tpmError
                       : !page.tpm.tpm ? Tr.t("This PC has no TPM 2.0, or it is off in the firmware settings")
                       : page.tpm.on ? Tr.t("The PC starts without the disk password. After a firmware update or a new graphics card it asks once. The boot menu cannot be edited while this is on.")
                       : !page.tpm.sb ? Tr.t("Needs Secure Boot on first (above): without it a changed boot loader could get the key")
                       : Tr.t("Start without typing the disk password: the TPM gives the key only to this PC's own, unchanged start. The password keeps working.")
            last: true
            Toggle {
                visible: page.tpm.tpm && (page.tpm.sb || page.tpm.on)
                checked: page.tpm.on
                enabled: !page.tpmWorking
                onToggled: v => { page.tpmError = ""; page.tpmWorking = true; tpmSet.want = v; tpmSet.running = true; }
            }
        }
    }
}
