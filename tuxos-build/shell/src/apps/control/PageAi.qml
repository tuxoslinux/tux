import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// AI: local only (Ollama), off and not installed by default.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("AI"); description: Tr.t("An assistant that runs only on this PC. Nothing leaves it.") }
    Cmd { id: oc; command: ["sh", "-c", "command -v ollama >/dev/null && echo yes"]; Component.onCompleted: run() }
    readonly property bool installed: oc.out.trim() === "yes"
    SettingCard {
        SettingRow { title: Tr.t("Local AI"); description: page.installed ? "Type ? and a question in the launcher" : "Installs Ollama (about 1 GB with a small model)"; last: true
            Btn { text: page.installed ? (Prefs.aiEnabled ? "Turn off" : "Turn on") : "Install"; primary: !page.installed || !Prefs.aiEnabled
                onClicked: { if (!page.installed) Quickshell.execDetached(["kitty", "--title", "Local AI", "sh", "-c", "sudo pacman -S --needed ollama && ollama pull llama3.2; read -p 'Enter closes' x"]); else Prefs.aiEnabled = !Prefs.aiEnabled; } } }
    }
}
