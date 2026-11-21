pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Calendar subscriptions: calendars from Google, Outlook, Nextcloud, iCloud
// ... by their address in iCal format (.ics), read only. The list is
// ~/.config/tuxos/calendars.json [{ name, url, color }]; the desktop shell
// downloads each one every 30 minutes into ~/.cache/tuxos/calendars/<n>.ics
// and every process (shell, Calendar app) reads the files from there.
// Times with a time zone name are taken as this PC's local time; "Z" times
// as UTC. Repeating events (daily / weekly / monthly / yearly, with
// INTERVAL, COUNT, UNTIL, BYDAY for weekly) are expanded a year ahead.
Singleton {
    id: subs
    readonly property string conf: Quickshell.env("HOME") + "/.config/tuxos/calendars.json"
    readonly property string cache: Quickshell.env("HOME") + "/.cache/tuxos/calendars"
    readonly property bool fetcher: (Quickshell.env("QS_APP_ID") || "") === "" && Quickshell.env("TUXOS_GREETER") !== "1"
    readonly property var colors: ["#c9a7ff", "#7fd6e8", "#ffb38a", "#a8e6a1", "#f5a3c7"]
    property var list: []                 // [{ name, url, color }]
    property var events: []               // [{ title, start, end, cal, readOnly, allDay }]
    property string lastError: ""

    FileView {
        id: confFile
        path: subs.conf
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { subs.list = JSON.parse(text()) || []; } catch (e) { subs.list = []; } if (subs.fetcher) subs.fetch(); }
    }
    function save(l) {
        list = l;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"", "sh", conf, JSON.stringify(l, null, 1)]);
    }
    function addSub(name, url) {
        url = url.trim().replace(/^webcal:\/\//i, "https://");
        if (!/^https?:\/\//i.test(url)) return false;
        const l = list.filter(x => x.url !== url);
        l.push({ name: (name || "").trim() || hostOf(url), url: url, color: colors[l.length % colors.length] });
        save(l);
        // the shell sees the file change and downloads it
        Qt.callLater(() => { if (subs.fetcher) subs.fetch(); });
        return true;
    }
    function removeSub(s) { save(list.filter(x => x.url !== s.url)); }
    function hostOf(u) { const m = /^https?:\/\/([^/]+)/i.exec(u); return m ? m[1] : u; }
    function fileOf(i) { return cache + "/" + i + ".ics"; }

    // ---- download (the shell only)
    Timer { interval: 1800000; repeat: true; running: subs.fetcher && subs.list.length > 0; onTriggered: subs.fetch() }
    Process {
        id: dl
        stdout: StdioCollector { onStreamFinished: subs.lastError = text.trim() }
    }
    function fetch() {
        if (dl.running || !list.length) return;
        // one file per subscription; a failed download keeps the old file
        let sh = "mkdir -p \"$1\"; shift; i=0; err=''; for u in \"$@\"; do curl -fsSL --max-time 30 -o \"$C/$i.ics.new\" \"$u\" && grep -q 'BEGIN:VCALENDAR' \"$C/$i.ics.new\" && mv -f \"$C/$i.ics.new\" \"$C/$i.ics\" || { rm -f \"$C/$i.ics.new\"; err=\"$err $i\"; }; i=$((i+1)); done; echo \"$err\"";
        dl.command = ["sh", "-c", "C=\"$1\"; " + sh, "sh", cache].concat(list.map(x => x.url));
        dl.running = true;
    }

    // ---- read the downloaded files
    property int pending: 0
    property var parts: ({})
    Instantiator {
        model: subs.list
        delegate: FileView {
            required property var modelData
            required property int index
            path: subs.fileOf(index)
            printErrors: false
            watchChanges: true
            onFileChanged: reload()
            property bool got: false
            onLoaded: { got = true; subs.take(index, modelData, text()); }
            onLoadFailed: subs.take(index, modelData, "")
            // a watch on a file that does not exist yet never fires: look again
            readonly property int tick: subs.tick
            onTickChanged: if (!got) reload()
        }
    }
    property int tick: 0
    Timer { interval: 5000; repeat: true; running: subs.list.length > Object.keys(subs.parts).filter(k => subs.parts[k].length).length; onTriggered: subs.tick++ }
    function take(i, s, text) {
        const p = Object.assign({}, parts);
        p[s.url] = text ? parse(text, s.name) : [];
        parts = p;
        let all = [];
        for (const x of list) if (p[x.url]) all = all.concat(p[x.url]);
        events = all.sort((a, b) => a.start - b.start);
    }

    // ---- iCalendar (RFC 5545), the parts calendars use
    function icsTime(v, params) {
        // 20261111T093000Z | 20261111T093000 | 20261111 (VALUE=DATE)
        const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/.exec(v.trim());
        if (!m) return null;
        const y = +m[1], mo = +m[2] - 1, d = +m[3];
        if (m[4] === undefined) return { t: new Date(y, mo, d).getTime(), allDay: true };
        const h = +m[4], mi = +m[5], se = +(m[6] || 0);
        return { t: m[7] ? Date.UTC(y, mo, d, h, mi, se) : new Date(y, mo, d, h, mi, se).getTime(), allDay: false };
    }
    function parse(text, calName) {
        const lines = text.replace(/\r\n[ \t]/g, "").replace(/\n[ \t]/g, "").split(/\r?\n/);
        const out = [];
        const from = Date.now() - 62 * 86400000, to = Date.now() + 366 * 86400000;
        let ev = null, depth = 0;
        for (const raw of lines) {
            if (raw === "BEGIN:VEVENT") { ev = {}; continue; }
            if (raw === "END:VEVENT") { if (ev) expand(ev, calName, from, to, out); ev = null; continue; }
            if (!ev) continue;
            const c = raw.indexOf(":"); if (c < 0) continue;
            const head = raw.slice(0, c), val = raw.slice(c + 1);
            const name = head.split(";")[0].toUpperCase();
            if (name === "SUMMARY") ev.title = val.replace(/\\n/g, " ").replace(/\\([,;\\])/g, "$1");
            else if (name === "DTSTART") ev.start = icsTime(val, head);
            else if (name === "DTEND") ev.end = icsTime(val, head);
            else if (name === "DURATION") ev.dur = val;
            else if (name === "RRULE") ev.rrule = val;
            else if (name === "EXDATE") { ev.ex = (ev.ex || []).concat(val.split(",").map(x => { const t = icsTime(x, head); return t ? t.t : 0; })); }
            else if (name === "STATUS" && val.toUpperCase() === "CANCELLED") ev.cancelled = true;
        }
        return out;
    }
    function durMs(d) {
        const m = /^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(d || "");
        return m ? ((+(m[1] || 0) * 7 + +(m[2] || 0)) * 86400 + +(m[3] || 0) * 3600 + +(m[4] || 0) * 60 + +(m[5] || 0)) * 1000 : 0;
    }
    function expand(ev, calName, from, to, out) {
        if (!ev.start || ev.cancelled) return;
        const s0 = ev.start.t;
        const len = ev.end ? Math.max(0, ev.end.t - s0) : (ev.dur ? durMs(ev.dur) : (ev.start.allDay ? 86400000 : 3600000));
        const push = t => { if (t + len >= from && t <= to && !(ev.ex || []).includes(t)) out.push({ title: ev.title || "(no title)", start: t, end: t + len, cal: calName, readOnly: true, allDay: ev.start.allDay }); };
        if (!ev.rrule) { push(s0); return; }
        const r = {};
        for (const kv of ev.rrule.split(";")) { const i = kv.indexOf("="); r[kv.slice(0, i).toUpperCase()] = kv.slice(i + 1); }
        const step = Math.max(1, +(r.INTERVAL || 1)), count = r.COUNT ? +r.COUNT : Infinity;
        const until = r.UNTIL ? (icsTime(r.UNTIL) || { t: to }).t : to;
        const days = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };
        const byday = r.BYDAY && r.FREQ === "WEEKLY" ? r.BYDAY.split(",").map(x => days[x.slice(-2)]).filter(x => x !== undefined) : null;
        let n = 0, k = 0;
        const base = new Date(s0);
        // a series that started long ago: jump to just before the window
        // (COUNT still counts the skipped ones)
        const per = { DAILY: 86400000, WEEKLY: 7 * 86400000, MONTHLY: 31 * 86400000, YEARLY: 366 * 86400000 }[r.FREQ] || 0;
        if (per && from > s0) {
            k = Math.max(0, Math.floor((from - s0) / (per * step)) - 2);
            n = k * (byday ? byday.length : 1);
        }
        let guard = 0;
        while (n < count && guard++ < 2000) {
            const d = new Date(base);
            if (r.FREQ === "DAILY") d.setDate(base.getDate() + k * step);
            else if (r.FREQ === "WEEKLY") d.setDate(base.getDate() + k * 7 * step);
            else if (r.FREQ === "MONTHLY") d.setMonth(base.getMonth() + k * step);
            else if (r.FREQ === "YEARLY") d.setFullYear(base.getFullYear() + k * step);
            else { push(s0); return; }
            k++;
            if (byday) {
                // every chosen weekday of this week (the week the start falls in)
                const wk = new Date(d); wk.setDate(d.getDate() - d.getDay());
                for (const wd of byday) {
                    const x = new Date(wk); x.setDate(wk.getDate() + wd);
                    if (x.getTime() < s0) continue;
                    if (x.getTime() > until || x.getTime() > to || n >= count) { n = count; break; }
                    push(x.getTime()); n++;
                }
            } else {
                if (d.getTime() > until || d.getTime() > to) break;
                push(d.getTime()); n++;
            }
        }
    }
    Component.onCompleted: void list
}
