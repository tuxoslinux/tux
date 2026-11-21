import QtQuick
import Quickshell
import qs.theme
import qs.components

// About: TuxOS version, hardware, "Report a problem".
Column {
    id: page
    spacing: 16
    Row {
        spacing: 16
        Image { source: Qt.resolvedUrl("../../assets/tux.png"); width: 72; height: 72; sourceSize: Qt.size(144, 144); mipmap: true }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: Tr.t("TuxOS"); font.family: Theme.font; font.pixelSize: Theme.px(30); font.weight: Font.Bold; color: Theme.text }
            Text { text: page.info.VERSION ? "Version " + page.info.VERSION : "Arch-based, without systemd, made for games"; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
        }
    }
    property var info: ({})
    Cmd {
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; echo \"VERSION=${VERSION_ID:-$BUILD_ID}\"; echo \"KERNEL=$(uname -r)\"; echo \"CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')\"; echo \"CORES=$(nproc)\"; echo \"RAM=$(awk '/MemTotal/{printf \"%.1f GB\", $2/1048576}' /proc/meminfo)\"; echo \"GPU=$(lspci 2>/dev/null | grep -i -m1 -E 'vga|3d|display' | sed 's/.*: //')\"; echo \"DISK=$(df -h --output=size / | tail -1 | tr -d ' ')\"; echo \"UP=$(uptime -p 2>/dev/null)\"; echo \"DESKTOP=Hyprland $(hyprctl version -j 2>/dev/null | grep -m1 '\\\"tag\\\"' | cut -d'\\\"' -f4)\""]
        Component.onCompleted: run()
        onDone: out => { const i = {}; for (const l of out.split("\n")) { const k = l.indexOf("="); if (k > 0) i[l.slice(0, k)] = l.slice(k + 1); } page.info = i; }
    }
    SettingCard {
        SettingRow { title: Tr.t("Processor"); description: (page.info.CPU || "") + (page.info.CORES ? " · " + page.info.CORES + " threads" : "") }
        SettingRow { title: Tr.t("Graphics"); description: page.info.GPU || "" }
        SettingRow { title: Tr.t("Memory"); description: page.info.RAM || "" }
        SettingRow { title: Tr.t("System disk"); description: page.info.DISK || "" }
        SettingRow { title: Tr.t("Kernel"); description: page.info.KERNEL || "" }
        SettingRow { title: Tr.t("Desktop"); description: page.info.DESKTOP || "" }
        SettingRow { title: Tr.t("Running"); description: page.info.UP || ""; last: true }
    }
    // Report a problem (SPEC round 7 #14): the report is shown in full
    // first; nothing leaves the PC until "Copy and open GitHub"
    property string report: ""
    property bool reading: false
    Cmd {
        id: collect
        command: ["tuxos-report"]
        onDone: out => { page.report = out; page.reading = false; }
    }
    SettingCard {
        SettingRow {
            title: Tr.t("Report a problem"); description: Tr.t("Shows you the logs first; a GitHub issue is opened only after you agree"); last: page.report === ""
            Btn { text: page.reading ? Tr.t("Collecting...") : (page.report ? Tr.t("Collect again") : Tr.t("Report...")); enabled2: !page.reading; onClicked: { page.reading = true; collect.run(); } }
        }
        Item {
            visible: page.report !== ""
            width: parent.width; height: Theme.px(320)
            Rectangle {
                anchors.fill: parent; anchors.margins: 12; radius: 12; color: Theme.fill
                Flickable {
                    id: rf
                    anchors.fill: parent; anchors.margins: 10
                    contentHeight: rt.paintedHeight; contentWidth: width; clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    TextEdit { id: rt; width: rf.width; text: page.report; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
                               font.family: "monospace"; font.pixelSize: Theme.px(11); color: Theme.text; selectionColor: Theme.accentFill }
                }
            }
        }
        SettingRow {
            visible: page.report !== ""; last: true
            title: Tr.t("Names, your home folder and the PC's name were replaced")
            description: Tr.t("Read it first. Copy and open GitHub puts it on the clipboard and opens a new issue; paste it there and add what happened.")
            Btn {
                text: Tr.t("Copy and open GitHub"); primary: true
                onClicked: {
                    Quickshell.clipboardText = page.report;
                    Quickshell.execDetached(["xdg-open", "https://github.com/tuxoslinux/tux/issues/new?title=" + encodeURIComponent("Problem: ")]);
                }
            }
        }
    }
}
