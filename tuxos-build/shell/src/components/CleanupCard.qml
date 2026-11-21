import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// One-click cleanup (SPEC system care #11): what each part frees, shown
// before cleaning; "Clean up" cleans the ticked parts (tuxos-clean; the
// system parts ask for the password once). Used by System manager and
// Settings > Storage.
SettingCard {
    id: card
    header: Tr.t("Clean up")
    property var size: ({})                 // what -> bytes
    property var off: ({})                  // what -> not ticked
    property bool busy: false
    property string done: ""
    readonly property var parts: [
        ["packages", Tr.t("Old package versions"), Tr.t("Keeps the one before each update, for Undo")],
        ["orphans", Tr.t("Packages nothing needs any more"), Tr.t("Left behind by apps you removed")],
        ["shaders", Tr.t("Shader caches of removed games"), Tr.t("Steam games that are not installed any more")],
        ["logs", Tr.t("Old logs"), Tr.t("Game logs older than 30 days, old system logs")],
        ["trash", Tr.t("Trash"), Tr.t("Files you deleted")],
        ["thumbnails", Tr.t("Thumbnails"), Tr.t("Picture previews, made again when needed")]
    ]
    readonly property real total: parts.reduce((a, p) => a + (off[p[0]] ? 0 : (size[p[0]] || 0)), 0)
    function human(b) { return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? Math.round(b / 1e6) + " MB" : b > 0 ? Math.max(1, Math.round(b / 1e3)) + " kB" : Tr.t("Nothing"); }
    Process {
        id: sizes
        command: ["tuxos-clean", "sizes"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) { const p = l.split(" "); if (p.length === 2) o[p[0]] = +p[1]; }
                card.size = o;
                // after a clean: what really went (a cancelled password frees nothing)
                if (card.busy) {
                    const gone = Math.max(0, card.freeing - card.total);
                    card.busy = false;
                    card.done = gone > 0 ? Tr.f("Freed {n}", { n: card.human(gone) }) : Tr.t("Nothing was cleaned");
                }
            }
        }
    }
    // fresh figures while it is open
    Timer { interval: 20000; repeat: true; running: card.visible && !card.busy; onTriggered: if (!sizes.running) sizes.running = true }
    Process {
        id: clean
        onExited: sizes.running = true
    }
    property real freeing: 0
    function cleanUp() {
        const what = parts.map(p => p[0]).filter(w => !off[w] && (size[w] || 0) > 0);
        if (!what.length || busy) return;
        freeing = total; busy = true; done = "";
        clean.command = ["tuxos-clean", "run"].concat(what);
        clean.running = true;
    }
    Repeater {
        model: card.parts
        delegate: SettingRow {
            required property var modelData
            title: modelData[1]
            description: card.human(card.size[modelData[0]] || 0) + "  ·  " + modelData[2]
            Toggle { checked: !card.off[modelData[0]]; onToggled: v => { const o = Object.assign({}, card.off); o[modelData[0]] = !v; card.off = o; } }
        }
    }
    SettingRow {
        last: true
        title: card.busy ? Tr.t("Cleaning...") : (card.done || (card.total > 0 ? Tr.f("{n} can be freed", { n: card.human(card.total) }) : Tr.t("Nothing to free right now")))
        Btn { text: Tr.t("Clean up"); primary: true; enabled2: !card.busy && card.total > 0; onClicked: card.cleanUp() }
    }
}
