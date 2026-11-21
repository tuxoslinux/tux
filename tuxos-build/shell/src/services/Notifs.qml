pragma Singleton

import QtQuick
import Quickshell
import qs.theme
import Quickshell.Io
import Quickshell.Services.Notifications

// Notifications (SPEC round 2 / 3): the shell is the notification server.
// Pop-ups top right; history in the centre (Super + N), grouped by app;
// Do not disturb (Super + D, for Prefs.dndHours, default 3 h); focus modes
// (Do not disturb, Work, Gaming, Sleep); quiet while a game runs, while the
// screen is shared and while locked; "While you were away" digest after.
Singleton {
    id: n

    // ---- state
    property double dndUntil: 0                 // ms; 0 = off
    property string focus: ""                   // "", "dnd", "work", "gaming", "sleep"
    property bool gameRunning: false            // /run/tuxos-gamed/mode
    property bool screenShared: false           // set by the privacy indicator
    property bool locked: false                 // set by the lock screen
    readonly property bool dnd: dndUntil > now || focus !== ""
    // a game silences pop-ups when Settings > Gaming says so (or its own profile)
    readonly property bool quiet: dnd || (gameRunning && Games.gameQuiet) || screenShared || locked
    property double now: Date.now()
    Timer { interval: 30000; running: n.dndUntil > 0; repeat: true; onTriggered: n.now = Date.now() }

    // pop-ups currently on screen, newest first
    property var popups: []
    // everything still tracked (history), newest first
    // only the desktop shell is the notification server (apps such as Settings
    // read this service too, and must not take the name over)
    readonly property bool isServer: (Quickshell.env("QS_APP_ID") || "") === "" && Quickshell.env("TUXOS_GREETER") !== "1"
    readonly property var server: serverLoader.item
    readonly property var history: server ? server.trackedNotifications.values.slice().reverse() : []
    property var times: ({})                    // id -> arrival time (ms)
    function timeOf(notif) { return times[notif.id] || Date.now(); }
    property int missed: 0                      // arrived while quiet
    property var missedApps: ({})

    readonly property var focusInfo: ({
        dnd: "Do not disturb: notifications silenced",
        work: "Work focus: chat and games silenced, Balanced profile",
        gaming: "Gaming focus: notifications silenced, Performance profile, until the game closes",
        sleep: "Sleep focus: notifications silenced, night light, Power saver"
    })

    function toggleDnd() {
        if (dnd) { dndUntil = 0; setFocus(""); }
        else { now = Date.now(); dndUntil = now + Prefs.dndHours * 3600000; }
        Toasts.show(dnd ? "Do not disturb" : "Do not disturb off",
                    dnd ? `Until ${Qt.formatTime(new Date(dndUntil), "HH:mm")} · Super + D turns it off` : "Notifications are back", dnd ? Icons.bellOff : Icons.bell);
    }
    function setFocus(mode) {
        const was = focus;
        focus = mode;
        if (mode === "") dndUntil = 0;
        // each focus mode also sets the power profile and night light
        if (mode === "gaming") Profiles.set("performance");
        else if (mode === "work") Profiles.set("balanced");
        else if (mode === "sleep") Profiles.set("power-saver");
        if (mode === "sleep") Quickshell.execDetached(["sh", "-c", "pkill -x hyprsunset; hyprsunset -t 3600 >/dev/null 2>&1 &"]);
        else if (was === "sleep") Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
    }
    onQuietChanged: {
        if (!quiet && missed > 0) {
            const apps = Object.keys(missedApps);
            Toasts.show(Tr.t("While you were away"), `${missed} notification${missed > 1 ? "s" : ""} from ${apps.slice(0, 3).join(", ")}${apps.length > 3 ? " and more" : ""}`, Icons.bellOutline, () => Shell.showOverlay("centre"));
            missed = 0;
            missedApps = ({});
        }
    }

    // game mode state from tuxos-gamed
    FileView {
        path: "/run/tuxos-gamed/mode"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: n.gameRunning = text().trim() === "on"
    }

    LazyLoader {
        id: serverLoader
        active: n.isServer
    NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true

        onNotification: notif => {
            notif.tracked = true;
            // kept over a shell reload: already seen, no new pop-up
            if (notif.lastGeneration) return;
            const t = Object.assign({}, n.times);
            t[notif.id] = Date.now();
            n.times = t;
            const critical = notif.urgency === NotificationUrgency.Critical;
            // a muted app: kept in the centre, never pops up or sounds
            if (!critical && (Prefs.mutedApps || []).indexOf(notif.appName || "Apps") !== -1) return;
            if (n.quiet && !critical) {
                n.missed++;
                const m = Object.assign({}, n.missedApps);
                m[notif.appName || "Apps"] = true;
                n.missedApps = m;
                return;
            }
            n.popups = [notif].concat(n.popups).slice(0, 4);
            Sounds.play("notification");
        }
    }
    }

    function dropPopup(notif) { popups = popups.filter(x => x !== notif); }
    function mute(app) {
        if ((Prefs.mutedApps || []).indexOf(app) === -1) Prefs.mutedApps = (Prefs.mutedApps || []).concat([app]);
        popups = popups.filter(x => (x.appName || "Apps") !== app);
        Toasts.show(Tr.f("{app} is muted", { app: app }), Tr.t("Its notifications wait in the centre; Settings > Notifications unmutes it"), Icons.bellOff, null,
                    [{ text: Tr.t("Undo"), run: () => Prefs.mutedApps = Prefs.mutedApps.filter(x => x !== app) }]);
    }
    function clearAll() {
        if (server) for (const x of server.trackedNotifications.values.slice()) x.dismiss();
        popups = [];
    }

    // history grouped by app: [{ app, entry, items: [...] }]
    readonly property var groups: {
        const g = [];
        for (const x of history) {
            const key = x.appName || "Apps";
            let grp = g.find(y => y.app === key);
            if (!grp) { grp = { app: key, desktopEntry: x.desktopEntry, items: [] }; g.push(grp); }
            grp.items.push(x);
        }
        return g;
    }

    function ago(ms) {
        const s = Math.max(0, (Date.now() - ms) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return `${Math.floor(s / 60)} min ago`;
        if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
        return Tr.date(new Date(ms), "d MMM");
    }
}
