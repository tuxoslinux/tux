import QtQuick
import Quickshell
import qs.services

// A window class or process name as people know it: the app's name,
// the game's name (steam_app_<id>), else the name itself.
QtObject {
    // the app list fills in after start: names follow it
    readonly property var known: DesktopEntries.applications.values
    function of(id) {
        if (!id) return "";
        const m = /^steam_app_(\d+)$/.exec(id);
        if (m) { const g = Games.list.find(x => x.source === "Steam" && String(x.appid) === m[1]); return g ? g.name : "Steam game " + m[1]; }
        const low = id.toLowerCase();
        const e = known.find(x => x.id.toLowerCase() === low || (x.startupClass || "").toLowerCase() === low) || DesktopEntries.heuristicLookup(id);
        if (e && e.name) return e.name;
        return id.charAt(0).toUpperCase() + id.slice(1);
    }
    function duration(s) {
        s = Math.round(s);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
        return h > 0 ? `${h} h ${m} min` : (m > 0 ? `${m} min` : (s > 0 ? "< 1 min" : "0 min"));
    }
}
