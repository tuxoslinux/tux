pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Tidy Downloads (SPEC round 5 #13; optional, Settings > Storage): once a
// day, files in ~/Downloads untouched for 30 days (setting) move to the
// Trash, with a notification and Undo (tuxos-clean tidy / untidy).
Singleton {
    id: td
    readonly property bool on: Prefs.tidyDownloads && !Shell.live && (Quickshell.env("QS_APP_ID") || "") === ""
    // a few minutes after login, then every hour checks whether today ran
    Timer { interval: 300000; repeat: true; running: td.on; onTriggered: td.check() }
    function check() {
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        if (!on || Prefs.tidyLast === today || Notifs.gameRunning || run.running) return;
        Prefs.tidyLast = today;
        run.command = ["tuxos-clean", "tidy", String(Prefs.tidyDays)];
        run.running = true;
    }
    Process {
        id: run
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text) || 0;
                if (n > 0) Toasts.show(Tr.t("Downloads tidied"), Tr.f(n === 1 ? "1 file older than {d} days moved to the Trash" : "{n} files older than {d} days moved to the Trash", { n: n, d: Prefs.tidyDays }),
                                       Icons.trashCanOutline, null, [{ text: Tr.t("Undo"), primary: true, run: () => Quickshell.execDetached(["tuxos-clean", "untidy"]) }], 15000);
            }
        }
    }
}
