import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Disks (mockup apps/17-disks): every drive with its partitions as one bar,
// eject for removable ones, and three actions: make a bootable USB from an
// ISO (read back and checked), format (FAT32 / exFAT / ext4, one
// partition) and check health (SMART). The drive with the running system
// cannot be written or formatted; erasing asks once, naming the drive.
AppWindow {
    id: app
    appName: "Disks"
    appIcon: 0xf02ca

    property var drives: []
    property string sel: ""
    readonly property var d: drives.find(x => x.path === sel) || drives[0] || null
    Cmd {
        id: scan
        command: ["lsblk", "-J", "-b", "-o", "PATH,NAME,TYPE,SIZE,MODEL,TRAN,RM,HOTPLUG,ROTA,LABEL,FSTYPE,MOUNTPOINT,FSUSED,PTTYPE"]
        Component.onCompleted: run()
        onDone: out => {
            let j; try { j = JSON.parse(out); } catch (e) { return; }
            app.drives = (j.blockdevices || []).filter(x => x.type === "disk" && !/^(zram|loop|sr)/.test(x.name)).map(x => {
                const parts = (x.children || []).filter(p => p.type === "part");
                const mounts = [x.mountpoint].concat(parts.map(p => p.mountpoint)).concat(parts.reduce((a, p) => a.concat((p.children || []).map(c => c.mountpoint)), []));
                return { path: x.path, name: x.name, size: +x.size, model: (x.model || "").trim(), tran: x.tran || "", removable: !!(x.rm || x.hotplug || x.tran === "usb"), rota: !!x.rota,
                         system: mounts.some(m => /^(\/|\/boot.*|\/home|\/efi|\[SWAP\])$/.test(m || "")), parts: parts.map(p => ({ path: p.path, size: +p.size, label: p.label || "", fs: p.fstype || "", mount: p.mountpoint || "" })) };
            });
            if (!app.sel && app.drives.length) app.sel = app.drives[0].path;
        }
    }
    Timer { interval: 3000; repeat: true; running: !job.running; onTriggered: scan.run() }

    function gb(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : b >= 1e9 ? Math.round(b / 1e9) + " GB" : Math.round(b / 1e6) + " MB"; }
    function kind(x) {
        if (!x) return "";
        if (x.tran === "nvme") return "NVMe SSD";
        if (x.tran === "usb") return "USB";
        if (x.name.startsWith("mmcblk")) return Tr.t("SD card");
        if (x.name.startsWith("vd")) return Tr.t("Virtual disk");
        return x.rota ? Tr.t("Hard disk (HDD)") : "SATA SSD";
    }
    function nameOf(x) { return x.model || (x.name.startsWith("mmcblk") ? Tr.t("SD card") : x.name); }

    // ---- the running job (write / format / health)
    property string action: ""                // "" | "write" | "format" | "health"
    property string confirm: ""
    property string jobText: ""
    // a USB write / format shows as a live activity in the bar
    ActivityFile {
        key: "disks"
        active: job.running && (job.kind === "write" || job.kind === "format")
        title: job.kind === "write" ? Tr.t("Writing a USB drive") : Tr.t("Formatting a drive")
        sub: app.jobText
        progress: job.kind === "write" ? app.jobProgress : -1
        rightText: job.kind === "write" ? Math.round(app.jobProgress * 100) + " %" : ""
        icon: Icons.usb
    }
    property real jobProgress: -1
    property string isoPath: ""
    property string fs: "exfat"
    property string label: "USB"
    property var smart: null
    readonly property var sm: smart || ({})
    Process {
        id: job
        property string kind: ""
        property real total: 0
        stdout: StdioCollector { id: jobOut }
        stderr: SplitParser {
            splitMarker: "\r"
            onRead: line => {
                const m = /^(\d+) bytes/.exec(line.trim());
                if (m && job.total > 0) { app.jobProgress = Math.min(1, +m[1] / job.total); app.jobText = Tr.f("Writing · {a} of {b}", { a: app.gb(+m[1]), b: app.gb(job.total) }); }
                else if (/tuxos-disk:/.test(line)) app.jobText = line.replace(/.*tuxos-disk: /, "");
            }
        }
        onExited: code => {
            app.jobProgress = -1;
            if (kind === "smart") {
                try { app.smart = JSON.parse(jobOut.text); app.jobText = ""; } catch (e) { app.jobText = code === 126 || code === 127 ? Tr.t("Cancelled") : Tr.t("This drive does not report its health"); }
            } else if (code === 0) app.jobText = kind === "write" ? Tr.t("Done - checked against the ISO. You can start a PC from it now.") : Tr.t("Done - the drive is empty and ready");
            else if (code === 126 || code === 127) app.jobText = Tr.t("Cancelled");
            else if (!app.jobText || app.jobText.startsWith(Tr.t("Writing"))) app.jobText = Tr.t("It did not finish");
            scan.run();
        }
    }
    function start(kind, args, total) {
        job.kind = kind; job.total = total || 0; jobText = kind === "write" ? Tr.t("Writing...") : kind === "format" ? Tr.t("Formatting...") : Tr.t("Reading the health data...");
        jobProgress = kind === "write" ? 0 : -1;
        job.command = ["pkexec", "tuxos-disk", kind].concat(args);
        job.running = true;
    }
    // ISOs in Downloads (and the TuxOS ones in ~)
    Cmd { id: isos; command: ["sh", "-c", "ls -1t \"$HOME\"/Downloads/*.iso \"$HOME\"/*.iso 2>/dev/null | head -n 12"]; Component.onCompleted: run() }

    // ---- drives
    Column {
        id: side
        x: 12; y: 12; width: 226
        spacing: 4
        Text { leftPadding: 8; topPadding: 4; bottomPadding: 4; text: Tr.t("DRIVES"); font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
        Repeater {
            model: app.drives
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: app.d && app.d.path === modelData.path
                width: side.width; height: 40; radius: 11
                color: on ? Theme.accentFill : (dh.hovered ? Theme.fill : "transparent")
                border.width: on ? 1 : 0; border.color: Theme.accentLine
                Row { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } spacing: 12
                    Text { text: String.fromCodePoint(modelData.removable ? 0xf0553 : 0xf02ca); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: parent.parent.on ? Theme.accent : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: app.nameOf(modelData); width: 130; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; anchors.verticalCenter: parent.verticalCenter } }
                Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: app.gb(modelData.size); font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.dim }
                HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { app.sel = modelData.path; app.action = ""; app.confirm = ""; app.smart = null; if (!job.running) app.jobText = ""; } }
            }
        }
    }
    Rectangle { x: side.x + side.width + 11; y: 0; width: 1; height: parent.height; color: Theme.glassLine }

    Flickable {
        anchors { left: side.right; leftMargin: 32; right: parent.right; rightMargin: 28; top: parent.top; topMargin: 20; bottom: parent.bottom; bottomMargin: 16 }
        contentHeight: main.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: main
            width: parent.width
            spacing: 16
            visible: app.d !== null
            // header
            Item {
                width: parent.width; height: 62
                Rectangle { id: ic; width: 56; height: 56; radius: 16; color: Theme.ink(0.08)
                    Text { anchors.centerIn: parent; text: String.fromCodePoint(app.d && app.d.removable ? 0xf0553 : 0xf02ca); font.family: Theme.symbols; font.pixelSize: Theme.px(28); color: Theme.text } }
                Column { anchors { left: ic.right; leftMargin: 16; verticalCenter: ic.verticalCenter } spacing: 4
                    Text { text: app.d ? app.nameOf(app.d) : ""; font.family: Theme.font; font.pixelSize: Theme.px(26); font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: app.d ? [app.kind(app.d), app.gb(app.d.size), app.d.path, app.d.removable ? Tr.t("removable") : "", app.d.system ? Tr.t("holds TuxOS") : ""].filter(x => x).join(" · ") : ""; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted } }
                Btn { anchors { right: parent.right; verticalCenter: ic.verticalCenter } visible: app.d && app.d.removable && !app.d.system; text: "Eject"; icon: 0xf01ea
                      onClicked: Quickshell.execDetached(["sh", "-c", "for p in $(lsblk -nro PATH \"$1\" | tail -n +2); do udisksctl unmount -b \"$p\" 2>/dev/null; done; udisksctl power-off -b \"$1\"", "sh", app.d.path]) }
            }
            // partitions
            Text { text: Tr.t("PARTITIONS"); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
            Row {
                width: parent.width; height: 64
                spacing: 4
                readonly property real free: app.d ? Math.max(0, app.d.size - app.d.parts.reduce((a, p) => a + p.size, 0)) : 0
                Repeater {
                    model: app.d ? app.d.parts : []
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: Math.max(90, (main.width - 3 * (app.d.parts.length + 1)) * modelData.size / app.d.size); height: 64; radius: 12
                        color: index % 2 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                        clip: true
                        Column { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            Text { text: modelData.label || modelData.mount || modelData.path.replace("/dev/", ""); font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.text }
                            Text { text: app.gb(modelData.size) + (modelData.fs ? " · " + modelData.fs : ""); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted } }
                    }
                }
                Rectangle {
                    visible: parent.free > 16e6 || (app.d && app.d.parts.length === 0)
                    width: Math.max(90, main.width - x); height: 64; radius: 12
                    color: Theme.fill
                    Column { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        Text { text: Tr.t("Free space"); font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; color: Theme.text }
                        Text { text: app.gb(parent.parent.parent.free); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted } }
                }
            }
            // actions
            Text { text: Tr.t("ACTIONS"); font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted }
            Row {
                width: parent.width
                spacing: 12
                Repeater {
                    model: [["write", 0xf01bc, "Make a bootable USB", "Write an ISO (e.g. TuxOS) to this drive"], ["format", 0xf01fe, "Format", "Erase and make one FAT32, exFAT or ext4 partition"], ["health", 0xf0ad6, "Check health", "SMART data: temperature, hours, wear"]]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool blocked: modelData[0] !== "health" && app.d && app.d.system
                        width: (main.width - 28) / 3; height: 128; radius: 18
                        color: app.action === modelData[0] ? Theme.accentFill : (ah.hovered && !blocked ? Theme.fillHover : Theme.fill)
                        border.width: 1; border.color: app.action === modelData[0] ? Theme.accentLine : Theme.glassLine
                        opacity: blocked ? 0.45 : 1
                        Column { anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 8
                            Rectangle { width: 40; height: 40; radius: 11; color: app.action === modelData[0] ? Theme.accent : Theme.ink(0.08)
                                Text { anchors.centerIn: parent; text: String.fromCodePoint(modelData[1]); font.family: Theme.symbols; font.pixelSize: Theme.px(20); color: app.action === modelData[0] ? Theme.accentInk : Theme.text } }
                            Text { text: Tr.t(modelData[2]); font.family: Theme.font; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; color: Theme.text }
                            Text { width: parent.width; wrapMode: Text.Wrap; text: parent.parent.blocked ? Tr.t("Not on the drive TuxOS runs from") : Tr.t(modelData[3]); font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.muted } }
                        HoverHandler { id: ah; cursorShape: parent.blocked ? Qt.ForbiddenCursor : Qt.PointingHandCursor }
                        TapHandler { onTapped: { if (parent.blocked || job.running) return; app.action = modelData[0]; app.confirm = ""; app.jobText = ""; if (modelData[0] === "health") app.start("smart", [app.d.path]); } }
                    }
                }
            }
            // ---- the chosen action
            SettingCard {
                visible: app.action === "write"
                width: parent.width
                header: "Make a bootable USB"
                SettingRow { title: "ISO file"; description: app.isoPath || Tr.t("ISOs in Downloads are listed")
                    ChoiceList { options: isos.out.split("\n").filter(x => x).map(p => ({ value: p, label: p.substring(p.lastIndexOf("/") + 1) })); current: app.isoPath; onPicked: v => app.isoPath = v } }
                SettingRow {
                    title: app.confirm === "write" ? Tr.f("Erase {d} and write the ISO?", { d: app.d ? app.nameOf(app.d) + " (" + app.gb(app.d.size) + ", " + app.d.path + ")" : "" }) : Tr.t("Everything on the drive is replaced")
                    last: true
                    Row { spacing: 8
                        Btn { visible: app.confirm === "write"; text: "Cancel"; onClicked: app.confirm = "" }
                        Btn { text: app.confirm === "write" ? "Erase and write" : "Write"; primary: app.confirm !== "write"; danger: app.confirm === "write"; enabled2: app.isoPath !== "" && !job.running
                              onClicked: { if (!app.isoPath || job.running) return; if (app.confirm !== "write") { app.confirm = "write"; return; } app.confirm = ""; isoSize.run(); } } }
                }
            }
            Cmd { id: isoSize; command: ["stat", "-c", "%s", app.isoPath]; onDone: out => app.start("write", [app.isoPath, app.d.path], +out.trim()) }
            SettingCard {
                visible: app.action === "format"
                width: parent.width
                header: "Format"
                SettingRow { title: "Kind"; description: app.fs === "vfat" ? Tr.t("Works everywhere; files up to 4 GB") : app.fs === "exfat" ? Tr.t("Windows, macOS, Linux, cameras; big files") : Tr.t("Linux only; fastest, keeps permissions")
                    Segmented { width: 300; options: ["FAT32", "exFAT", "ext4"]; current: ["vfat", "exfat", "ext4"].indexOf(app.fs); onPicked: i => app.fs = ["vfat", "exfat", "ext4"][i] } }
                SettingRow { title: "Name"
                    Rectangle { width: 220; height: 36; radius: 10; color: Theme.ink(0.05); border.width: 1; border.color: lab.activeFocus ? Theme.accentLine : Theme.glassLine
                        TextInput { id: lab; anchors { fill: parent; leftMargin: 8; rightMargin: 8 } verticalAlignment: TextInput.AlignVCenter; text: app.label; onTextChanged: app.label = text; maximumLength: 16; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text } } }
                SettingRow {
                    title: app.confirm === "format" ? Tr.f("Erase everything on {d}?", { d: app.d ? app.nameOf(app.d) + " (" + app.gb(app.d.size) + ", " + app.d.path + ")" : "" }) : Tr.t("Everything on the drive is erased")
                    last: true
                    Row { spacing: 8
                        Btn { visible: app.confirm === "format"; text: "Cancel"; onClicked: app.confirm = "" }
                        Btn { text: app.confirm === "format" ? "Erase" : "Format"; primary: app.confirm !== "format"; danger: app.confirm === "format"; enabled2: !job.running
                              onClicked: { if (job.running) return; if (app.confirm !== "format") { app.confirm = "format"; return; } app.confirm = ""; app.start("format", [app.d.path, app.fs, app.label || "USB"]); } } }
                }
            }
            SettingCard {
                visible: app.action === "health" && app.smart !== null
                width: parent.width
                header: "Health"
                SettingRow { title: "Overall"; description: app.sm.smart_status ? (app.sm.smart_status.passed ? Tr.t("Good") : Tr.t("Failing - copy your files off it")) : "-" }
                SettingRow { title: "Temperature"; description: app.sm.temperature ? app.sm.temperature.current + " °C" : "-" }
                SettingRow { title: "Powered on"; description: app.sm.power_on_time ? Tr.f("{n} hours", { n: app.sm.power_on_time.hours }) : "-" }
                SettingRow { title: "Wear"; last: true
                    description: app.sm.nvme_smart_health_information_log ? app.sm.nvme_smart_health_information_log.percentage_used + " %" : Tr.t("Not reported") }
            }
            // progress / result
            Rectangle {
                visible: app.jobText !== ""
                width: parent.width; height: 74; radius: 18
                color: Theme.fill; border.width: 1; border.color: Theme.glassLine
                Column { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 20 } spacing: 8
                    Text { text: app.jobText; width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                    Rectangle { visible: app.jobProgress >= 0; width: parent.width; height: 6; radius: 3; color: Theme.ink(0.1)
                        Rectangle { width: parent.width * Math.max(0, app.jobProgress); height: 6; radius: 3; color: Theme.accent } } }
            }
        }
    }
}
