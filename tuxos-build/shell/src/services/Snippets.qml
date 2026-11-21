pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Text snippets (SPEC: ";mail" -> the address): the list lives in
// ~/.config/tuxos/snippets.json ([{ trigger, text }], Settings > Keyboard &
// shortcuts). tuxos-snippetd (root) reports when a trigger was typed; the
// shell erases it and types the text into the focused app (wtype). "{date}"
// and "{time}" in a text become today's date and the time.
Singleton {
    id: sn
    property var list: []
    readonly property string path: Quickshell.env("HOME") + "/.config/tuxos/snippets.json"
    FileView {
        id: file
        path: sn.path
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { sn.list = JSON.parse(text()) || []; } catch (e) { sn.list = []; } sn.register(); }
    }
    function save(l) { list = l; file.setText(JSON.stringify(l, null, 1)); register(); }
    function add(trigger, text) {
        let t = trigger.trim().toLowerCase().replace(/[^a-z0-9;-]/g, "");
        if (!t.startsWith(";")) t = ";" + t;
        if (t.length < 3 || !text) return false;
        save(list.filter(x => x.trigger !== t).concat([{ trigger: t, text: text }]));
        return true;
    }
    function remove(t) { save(list.filter(x => x.trigger !== t)); }

    Socket {
        id: sock
        path: "/run/tuxos-snippetd.sock"
        connected: false
        onConnectedChanged: if (connected) sn.register(); else retry.restart()
        parser: SplitParser { onRead: line => { if (line.startsWith("M ")) sn.expand(line.slice(2).trim()); } }
    }
    // connect when the daemon is there (looked for again each minute)
    Process { id: look; command: ["test", "-S", "/run/tuxos-snippetd.sock"]; onExited: code => { if (code === 0) sock.connected = true; else retry.restart(); } }
    Timer { id: retry; interval: 60000; onTriggered: if (!Shell.live && !sock.connected) look.running = true }
    Component.onCompleted: if (!Shell.live) look.running = true
    function register() {
        if (!sock.connected) return;
        let m = "C\n";
        for (const x of list) m += "T " + x.trigger + "\n";
        sock.write(m);
        sock.flush();
    }
    function expand(t) {
        const x = list.find(s => s.trigger === t);
        if (!x) return;
        const d = new Date();
        const text = x.text.replace(/\{date\}/g, Tr.date(d, "d MMMM yyyy")).replace(/\{time\}/g, Qt.formatTime(d, "HH:mm"));
        // erase the trigger, then type the text
        const keys = [];
        for (let i = 0; i < t.length; i++) keys.push("-k", "BackSpace");
        Quickshell.execDetached(["wtype"].concat(keys));
        typeLater.text = text;
        typeLater.restart();
    }
    Timer { id: typeLater; interval: 120; property string text: ""; onTriggered: Quickshell.execDetached(["wtype", "--", text]) }
}
