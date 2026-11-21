pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Things the shell keeps an eye on (SPEC round 3 "states" / "polish"):
//   removable drives: toast with Open / Eject, then "Safe to remove"
//   boot time: "Booted in 2.7 s" once per start (Settings can turn it off)
//   refresh rate: the screen runs below its best rate -> Fix / Keep
//   low memory (names the biggest app), disk over 90 %, CPU overheating
// The drive watcher is one idle process (udevadm); the other checks run
// once a minute.
Singleton {
    id: w
    property bool started: false
    function start() { if (started) return; started = true; udev.running = true; firstChecks.restart(); }

    // ---------------------------------------------------------------- drives
    Process {
        id: udev
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block", "--property"]
        // events are blocks of KEY=value lines; empty lines do not arrive,
        // so a block ends at the next header ("UDEV [...]") or after a pause
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("UDEV")) { w.flush(); return; }
                const k = line.indexOf("=");
                if (k > 0) { w.pending[line.slice(0, k)] = line.slice(k + 1); flushLater.restart(); }
            }
        }
    }
    property var pending: ({})
    Timer { id: flushLater; interval: 150; onTriggered: w.flush() }
    function flush() {
        const e = pending;
        pending = {};
        if (e.ACTION) blockEvent(e);
    }
    function blockEvent(e) {
        if (e.ACTION !== "add" || e.DEVTYPE !== "partition" && !(e.DEVTYPE === "disk" && e.ID_FS_USAGE === "filesystem")) return;
        if (e.ID_FS_USAGE !== "filesystem" || (e.ID_BUS !== "usb" && !/mmcblk/.test(e.DEVNAME || ""))) return;
        const name = e.ID_FS_LABEL || e.ID_MODEL || "USB drive";
        const dev = e.DEVNAME;
        Toasts.show(name.replace(/_/g, " ") + " connected", (e.ID_FS_TYPE || "") + " · " + dev, Icons.usbFlashDrive, null, [
            { text: Tr.t("Open"), primary: true, run: () => Quickshell.execDetached(["sh", "-c", "m=$(lsblk -no MOUNTPOINT \"$1\"); [ -n \"$m\" ] || m=$(udisksctl mount -b \"$1\" | sed -n 's/.* at \\(.*\\)\\.*$/\\1/p'); gio open \"${m%.}\"", "sh", dev]) },
            { text: Tr.t("Eject"), run: () => w.eject(dev, name) }
        ], 10000);
    }
    Process {
        id: ejectProc
        property string label
        onExited: code => code === 0 ? Toasts.show(Tr.t("Safe to remove ✓"), ejectProc.label.replace(/_/g, " "), Icons.usbFlashDrive)
                                     : Toasts.show(Tr.t("Still in use"), Tr.t("Close the files open on ") + ejectProc.label.replace(/_/g, " ") + " and try again", Icons.alertOutline)
    }
    function eject(dev, label) {
        ejectProc.label = label;
        ejectProc.command = ["sh", "-c", "m=$(lsblk -no MOUNTPOINT \"$1\"); [ -z \"$m\" ] || udisksctl unmount -b \"$1\" >/dev/null || exit 1; d=/dev/$(lsblk -no PKNAME \"$1\"); [ \"$d\" = /dev/ ] && d=$1; udisksctl power-off -b \"$d\" >/dev/null 2>&1; exit 0", "sh", dev];
        ejectProc.running = true;
    }

    // ---------------------------------------------------------------- once after login
    Timer { id: firstChecks; interval: 4000; onTriggered: { bootCard.running = true; refresh.running = true; if (Quickshell.env("GBM_ALWAYS_SOFTWARE") === "1") softGl.running = true; } }
    // ---- graphics that could not draw (tuxos-session: tuxos-glcheck failed, so
    // Mesa's software renderer draws everything): say so once per start
    Process {
        id: softGl
        command: ["sh", "-c", "f=\"/tmp/tuxos-softgl-$(id -u)\"; b=$(cat /proc/sys/kernel/random/boot_id); [ \"$(cat \"$f\" 2>/dev/null)\" = \"$b\" ] && exit 1; echo \"$b\" > \"$f\""]
        onExited: (code, st) => { if (code === 0) Toasts.show(Tr.t("Drawn without the GPU"), Tr.t("This PC's graphics driver could not draw, so the processor draws the desktop (slower). In VirtualBox: Settings > Display > Enable 3D Acceleration."), Icons.alertOutline, null, [], 15000); }
    }
    Process {
        id: bootCard
        // power-on -> login screen, plus password -> desktop (not the time
        // spent typing at the login screen); once per boot (/tmp is emptied at
        // each start; the runtime folder is not kept across a log out)
        command: ["sh", "-c", "f=\"/tmp/tuxos-booted-$(id -u)\"; b=$(cat /proc/sys/kernel/random/boot_id); [ \"$(cat \"$f\" 2>/dev/null)\" = \"$b\" ] && exit 1; echo \"$b\" > \"$f\"; echo \"$(cat /tmp/tuxos-greeter-ready 2>/dev/null || echo 0) $(cat \"$XDG_RUNTIME_DIR/tuxos-login-at\" 2>/dev/null || echo 0) $1\"", "sh", String(w.shellUp)]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/).map(Number);
                if (p.length < 3 || !Prefs.bootCard || !p[0] || !p[1]) return;
                const secs = p[0] + Math.max(0, p[2] - p[1]);
                if (secs > 0 && secs < 300) {
                    w.bootToast = Toasts.show(Tr.f("Booted in {s} s", { s: secs.toFixed(1) }), Tr.t("Power-on to login screen, plus login to desktop · Settings > Desktop turns this off"), Icons.rocket, null, [], 8000);
                    history.command = ["sh", "-c", "f=\"$HOME/.local/state/tuxos/boot-times\"; mkdir -p \"$(dirname \"$f\")\"; tail -n 5 \"$f\" 2>/dev/null; echo \"$(date +%s) $1\" >> \"$f\"; tail -n 50 \"$f\" > \"$f.n\" && mv \"$f.n\" \"$f\"", "sh", secs.toFixed(1)];
                    history.running = true;
                }
            }
        }
    }
    // ---- an update that did not finish (tuxos-pkg update writes its result)
    // (read again each minute too: a file that did not exist yet cannot be watched)
    Connections { target: Tick; function onMinute(t) { updResult.reload(); } }
    FileView {
        id: updResult
        path: "/var/lib/tuxos/updates/result"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const f = text().trim().split(" ");
            if (f[0] !== "failed") return;
            const at = parseInt(f[2]) || 0;
            if (at <= Prefs.updateFailSeen) return;
            Prefs.updateFailSeen = at;
            Toasts.show(Tr.t("The update did not finish"), Tr.t("pacman stopped before the end; the last lines of its log say why (often no internet, or a full disk)"), Icons.alertOutline, null, [
                { text: Tr.t("Show the log"), run: () => Quickshell.execDetached(["kitty", "--title", "Update log", "sh", "-c", "tail -n 40 /var/log/pacman.log; echo; read -p 'Enter closes' x"]) },
                { text: Tr.t("Try again"), primary: true, run: () => Apps.run(`${Prefs.settingsApp} --page updates`) }
            ], 0);
        }
    }

    // the last few starts, shown on the boot card while hovered
    property int bootToast: 0
    Process {
        id: history
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(x => x).reverse().map(l => { const [t, s] = l.split(" "); return Tr.date(new Date(parseInt(t) * 1000), "d MMM HH:mm") + "  ·  " + s + " s"; });
                if (rows.length) Toasts.setMore(w.bootToast, Tr.t("Before:") + "\n" + rows.join("\n"));
            }
        }
    }
    // when the shell came up (seconds since power-on)
    property real shellUp: 0
    Process { running: true; command: ["awk", "{print $1}", "/proc/uptime"]; stdout: StdioCollector { onStreamFinished: w.shellUp = parseFloat(text) } }
    Process {
        id: refresh
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    for (const m of JSON.parse(text)) {
                        const same = (m.availableModes || []).map(x => /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(x)).filter(x => x && +x[1] === m.width && +x[2] === m.height).map(x => +x[3]);
                        const best = Math.max(...same, 0);
                        if (best > m.refreshRate + 5) {
                            const mode = `${m.width}x${m.height}@${best}`;
                            Toasts.show(Tr.f("{s} can run at {b} Hz", { s: m.description || m.name, b: Math.round(best) }), Tr.f("It runs at {r} Hz now", { r: Math.round(m.refreshRate) }), Icons.monitor, null, [
                                { text: Tr.t("Fix"), primary: true, run: () => Quickshell.execDetached(["sh", "-c", "hyprctl dispatch \"(function() hl.monitor({ output = \\\"$1\\\", mode = \\\"$2\\\", position = \\\"auto\\\", scale = $3 }); return hl.dsp.no_op() end)()\"; f=\"$HOME/.config/hypr/monitors.lua\"; echo \"hl.monitor({ output = \\\"$1\\\", mode = \\\"$2\\\", position = \\\"auto\\\", scale = $3 })\" >> \"$f\"", "sh", m.name, mode, String(m.scale)]) },
                                { text: Tr.t("Keep"), run: () => {} }
                            ], 0);
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // ---------------------------------------------------------------- every minute
    // a process as people know it: TuxOS' own apps all run as "qs -p
    // .../app-NAME.qml"; anything else by its app's name when it has one
    function appName(comm, args) {
        const m = /app-([a-z]+)\.qml/.exec(args);
        if (comm === "qs" && m) return m[1].charAt(0).toUpperCase() + m[1].slice(1);
        const e = comm ? DesktopEntries.heuristicLookup(comm) : null;
        return e && e.name ? e.name : (comm || Tr.t("An app"));
    }
    property var warned: ({})
    function warnOnce(key, title, body, icon, buttons) {
        if (warned[key] && Date.now() - warned[key] < 3600000) return;
        const x = Object.assign({}, warned); x[key] = Date.now(); warned = x;
        Toasts.show(title, body, icon, null, buttons || [], 0);
    }
    Connections { target: Tick; enabled: w.started; function onMinute(t) { if (!checks.running) checks.running = true; if (new Date(t).getMinutes() === 7 && !backup.running) backup.running = true; } }
    // scheduled backups (TuxOS Backups): once an hour the script checks
    // whether one is due and the disk is there; a toast when one finished
    Process {
        id: backup
        command: ["sh", "-c", "[ -f \"$HOME/.config/tuxos/backups.json\" ] && command -v tuxos-backup >/dev/null && exec nice -n 10 ionice -c 3 tuxos-backup --if-due 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) Toasts.show(Tr.t("Backup done"), Tr.t("Your files are copied to the backup disk"), 0xf0062, () => Quickshell.execDetached(["tuxos-app", "backups"]))
        }
    }
    Process {
        id: checks
        command: ["sh", "-c", "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print \"M\", t, a}' /proc/meminfo; df -P / /home 2>/dev/null | awk 'NR>1 {sub(\"%\",\"\",$5); print \"D\", $6, $5}'; for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name 2>/dev/null) in k10temp|coretemp|zenpower) echo \"T $(( $(cat $h/temp1_input) / 1000 ))\"; break;; esac; done; ps -u \"$(id -u)\" -o rss=,pid=,comm=,args= --sort=-rss | awk -v me=\"$PPID\" '$2 != me && $3 !~ /^(Hyprland|Xwayland|pipewire|pipewire-pulse|wireplumber|dbus-daemon|qs-greeter)$/ { print \"P\", $0; exit }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const p = l.trim().split(/\s+/);
                    if (p[0] === "M" && +p[2] / +p[1] < 0.06) {
                        // the biggest app of the user (not the shell itself or the desktop's own parts)
                        const top = text.split("\n").find(x => x.startsWith("P ")) || "";
                        const q = top.trim().split(/\s+/);
                        const name = w.appName(q[3] || "", q.slice(4).join(" "));
                        const buttons = q[2] ? [{ text: Tr.f("Close {n}", { n: name }), primary: true, run: () => Quickshell.execDetached(["kill", q[2]]) },
                                                { text: Tr.t("Close anyway"), run: () => Quickshell.execDetached(["kill", "-9", q[2]]) }] : [];
                        w.warnOnce("mem", Tr.t("Memory is almost full"), q[2] ? Tr.f("{n} uses {m} MB", { n: name, m: Math.round(+q[1] / 1024) }) : Tr.t("Close an app you do not need"), Icons.memory, buttons);
                    }
                    if (p[0] === "D" && +p[2] >= 90) w.warnOnce("disk" + p[1], Tr.f("Disk {d} is {p} % full", { d: p[1], p: p[2] }), Tr.t("Free space in Settings > Storage & cleanup"), Icons.harddisk,
                                                                   [{ text: Tr.t("Clean up"), primary: true, run: () => Quickshell.execDetached(["tuxos-control", "--page", "storage"]) }]);
                    if (p[0] === "T" && +p[1] >= 95) w.warnOnce("heat", Tr.f("The CPU is very hot ({t} °C)", { t: p[1] }), Tr.t("Check the fans and the airflow"), Icons.thermometer);
                }
            }
        }
    }
}
