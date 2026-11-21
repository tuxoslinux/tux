pragma Singleton

import QtQuick
import Quickshell
import qs.theme
import Quickshell.Io

// Local AI "Ask" mode (SPEC round 4): Ollama on this computer only, off and
// not installed by default. "?question" in the launcher asks it; the answer
// comes back as a toast (and is copied to the clipboard).
Singleton {
    id: ai

    property string model: "llama3.2"
    property bool busy: proc.running

    Process {
        id: proc
        property string question: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let reply = "";
                try { reply = JSON.parse(text).response || ""; } catch (e) {}
                if (reply) {
                    Quickshell.clipboardText = reply;
                    Toasts.show(Tr.t("Ask: ") + proc.question, reply.length > 400 ? reply.slice(0, 400) + "…" : reply, Icons.robot, null, [], 20000);
                } else {
                    Toasts.show(Tr.t("Ask is off"), Tr.t("Turn on local AI in TuxOS Control > AI (installs Ollama, runs only on this PC)"), Icons.robot,
                                () => Apps.run(`${Prefs.settingsApp} --page ai`));
                }
            }
        }
    }
    function ask(q) {
        if (!q) return;
        proc.question = q;
        proc.command = ["curl", "-fsS", "--max-time", "120", "http://127.0.0.1:11434/api/generate",
                        "-d", JSON.stringify({ model: model, prompt: q, stream: false })];
        proc.running = true;
        Toasts.show(Tr.t("Thinking…"), q, Icons.robot, null, [], 3000);
    }
}
