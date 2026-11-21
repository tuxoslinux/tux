pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Driver news (SPEC round 6 #6): after an NVIDIA driver or Mesa update, one
// card with that release's game-relevant notes in the upstream project's own
// words (tuxos-drivernotes; TuxOS never invents numbers) and "Undo update"
// (tuxos-pkg undo puts the version before back, with its sibling packages).
// Checked a while after login; each new version is shown once.
Singleton {
    id: dn
    Timer { interval: 90000; running: !Shell.live; onTriggered: recent.running = true }
    Process {
        id: recent
        command: ["tuxos-pkg", "recent", "200"]
        stdout: StdioCollector { onStreamFinished: dn.look(text) }
    }
    function look(text) {
        // newest first: "date name old new"
        for (const l of text.split("\n")) {
            const f = l.trim().split(" ");
            if (f.length < 4 || !/^(mesa|nvidia-utils|nvidia-open-dkms|nvidia-dkms|nvidia-580xx-utils)$/.test(f[1])) continue;
            const key = f[1] + " " + f[3];
            if ((Prefs.driversSeen || []).indexOf(key) !== -1) return;     // the newest one was shown already
            Prefs.driversSeen = (Prefs.driversSeen || []).concat([key]).slice(-20);
            // only recent ones (an old upgrade found on a first login is not news)
            if (Date.now() - new Date(f[0]).getTime() > 7 * 86400000) return;
            notes.pkg = f[1]; notes.ver = f[3];
            notes.command = ["tuxos-drivernotes", f[1], f[3]];
            notes.running = true;
            return;
        }
    }
    Process {
        id: notes
        property string pkg: ""
        property string ver: ""
        stdout: StdioCollector { onStreamFinished: dn.show(notes.pkg, notes.ver, text.split("\n").filter(x => x)) }
    }
    function show(pkg, ver, lines) {
        const url = lines[0] || "";
        const name = pkg === "mesa" ? "Mesa" : "NVIDIA driver";
        const v = ver.replace(/^\d+:/, "").replace(/-[^-]*$/, "");
        const body = lines.length > 1 ? Tr.t("Fixed, in the release notes' words:") + "\n• " + lines.slice(1, 4).join("\n• ")
                                      : Tr.t("The release notes say what changed.");
        Toasts.show(Tr.f("{n} {v} is installed", { n: name, v: v }), body, Icons.expansionCard, null, [
            { text: Tr.t("Release notes"), primary: true, run: () => Quickshell.execDetached(["xdg-open", url]) },
            { text: Tr.t("Undo update"), run: () => Quickshell.execDetached(["sh", "-c", "pkexec tuxos-pkg undo \"$1\" && notify-send 'Update undone' \"$1: the version before is back (restart to use it)\"", "sh", pkg]) }
        ], 0);
    }
}
