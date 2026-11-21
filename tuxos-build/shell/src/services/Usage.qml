pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// How often each app was opened from the shell (launcher ranking, the
// launcher's first page). Local only (~/.local/state/quickshell/...).
Singleton {
    id: usage

    property var counts: ({})

    FileView {
        id: file
        path: Quickshell.statePath("usage.json")
        onLoaded: { try { usage.counts = JSON.parse(text()); } catch (e) {} }
    }
    Timer { id: save; interval: 2000; onTriggered: file.setText(JSON.stringify(usage.counts)) }

    function count(id) { return counts[id] || 0; }
    function bump(id) {
        if (!id) return;
        const c = Object.assign({}, counts);
        c[id] = (c[id] || 0) + 1;
        counts = c;
        save.restart();
    }
    // launch a desktop entry and count it; `from` (a screen point, optional)
    // is where it was clicked: the new window grows out of there
    function launch(entry, from) {
        if (!entry) return;
        bump(entry.id);
        Shell.noteLaunch(entry, from);
        entry.execute();
    }
}
