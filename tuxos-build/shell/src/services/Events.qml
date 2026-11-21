pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Calendar events shared by the shell (launcher "lunch with Alex tomorrow
// 13:00", next-event live activity, clock droplet) and the Calendar app.
// ~/.local/share/tuxos/events.json: [{ title, start (ms), end (ms) }].
Singleton {
    id: ev

    property var list: []
    // with the subscribed calendars (read only, CalendarSubs)
    readonly property var all: list.concat(CalendarSubs.events).sort((a, b) => a.start - b.start)

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/share/tuxos/events.json"
        printErrors: false      // no events yet
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { ev.list = JSON.parse(text()) || []; } catch (e) { ev.list = []; } }
    }
    function add(title, start, end, cal) {
        const l = list.slice();
        l.push({ id: Date.now(), title: title, start: start, end: end || start + 3600000, cal: cal || "Personal" });
        l.sort((a, b) => a.start - b.start);
        list = l;
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/share/tuxos"]);
        file.setText(JSON.stringify(l, null, 1));
    }
    function remove(e) {
        const l = list.filter(x => !(x.start === e.start && x.title === e.title));
        list = l;
        file.setText(JSON.stringify(l, null, 1));
    }
    function next(now) {
        for (const e of all) if (e.start >= now) return e;
        return null;
    }

    // "lunch with Alex tomorrow 13:00", "обяд с Алекс утре 13:00",
    // "dentist friday at 9", "call mom in 2 hours"; null if no date / time
    readonly property var weekdays: ({ sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6,
        sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6,
        "неделя": 0, "понеделник": 1, "вторник": 2, "сряда": 3, "четвъртък": 4, "петък": 5, "събота": 6 })
    function parse(q) {
        let s = " " + q.trim() + " ";
        let day = null, hh = -1, mm = 0, found = false;
        const now = new Date();
        const take = re => { const m = re.exec(s); if (m) { s = s.replace(m[0], " "); found = true; } return m; };
        let m;
        if ((m = take(/\s(?:in|след)\s+(\d+)\s*(min|minutes|минути|h|hours?|часа?)\s/i))) {
            const n = parseInt(m[1]);
            const t = new Date(now.getTime() + n * (/^(h|hour|час)/i.test(m[2]) ? 3600000 : 60000));
            return { title: clean(s), start: t.getTime() };
        }
        if (take(/\s(?:tomorrow|утре)\s/i)) { day = new Date(now); day.setDate(day.getDate() + 1); }
        else if (take(/\s(?:today|tonight|днес|довечера)\s/i)) day = new Date(now);
        else if ((m = take(/\s(?:on\s+|в\s+)?(sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat|неделя|понеделник|вторник|сряда|четвъртък|петък|събота)\s/i))) {
            day = new Date(now);
            const want = weekdays[m[1].toLowerCase()];
            let d = (want - day.getDay() + 7) % 7;
            if (d === 0) d = 7;
            day.setDate(day.getDate() + d);
        } else if ((m = take(/\s(\d{1,2})[./](\d{1,2})(?:[./](\d{2,4}))?\s/))) {
            day = new Date(now.getFullYear(), parseInt(m[2]) - 1, parseInt(m[1]));
            if (m[3]) day.setFullYear(parseInt(m[3]) < 100 ? 2000 + parseInt(m[3]) : parseInt(m[3]));
        }
        let ap = "";
        if ((m = take(/\s(?:at\s+|в\s+|@)?(\d{1,2})[:.](\d{2})\s*(am|pm)?\s/i))) { hh = parseInt(m[1]); mm = parseInt(m[2]); ap = m[3] || ""; }
        else if ((m = take(/\s(?:at|в|@)\s+(\d{1,2})\s*(am|pm)?\s/i)) || (m = take(/\s(\d{1,2})\s*(am|pm)\s/i))) { hh = parseInt(m[1]); ap = m[2] || ""; }
        ap = ap.toLowerCase();
        if (ap === "pm" && hh < 12) hh += 12;
        if (ap === "am" && hh === 12) hh = 0;
        if (!found || (day === null && hh < 0)) return null;
        if (day === null) { day = new Date(now); if (hh < now.getHours() || (hh === now.getHours() && mm <= now.getMinutes())) day.setDate(day.getDate() + 1); }
        day.setHours(hh < 0 ? 9 : hh, mm, 0, 0);
        const title = clean(s);
        if (!title) return null;
        return { title: title, start: day.getTime(), allDay: hh < 0 };
    }
    function clean(s) {
        s = s.replace(/\s+/g, " ").trim();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
}
