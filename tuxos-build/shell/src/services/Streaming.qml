pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Game streaming host (Sunshine via tuxos-stream): while it is on, a device
// asking to pair (Moonlight "Add PC") brings a card that opens Settings >
// Gaming for its PIN. Checked every 5 s only while the host runs.
Singleton {
    id: st
    property bool on: false
    property int pending: 0
    Process { id: statusProc; command: ["tuxos-stream", "status"]; stdout: StdioCollector { onStreamFinished: st.on = text.trim() === "on" } }
    Timer { interval: 30000; repeat: true; running: !Shell.live; triggeredOnStart: true; onTriggered: if (!statusProc.running) statusProc.running = true }
    Process {
        id: pendingProc
        command: ["tuxos-stream", "pending"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text) || 0;
                if (n > st.pending)
                    Toasts.show(Tr.t("A device wants to stream games"), Tr.t("Enter the PIN Moonlight shows in Settings > Gaming"), Icons.gamepadVariant, null,
                                [{ text: Tr.t("Enter PIN"), primary: true, run: () => Apps.run(`${Prefs.settingsApp} --page gaming`) }], 0);
                st.pending = n;
            }
        }
    }
    Timer { interval: 5000; repeat: true; running: st.on; onTriggered: if (!pendingProc.running) pendingProc.running = true }
    function refresh() { statusProc.running = false; statusProc.running = true; }
}
