import QtQuick

// Public holidays in Bulgaria for a year (fixed days + Orthodox Easter).
QtObject {
    function orthodoxEaster(y) {
        // Meeus' Julian algorithm, then Julian -> Gregorian (+13 days 1900-2099)
        const a = y % 4, b = y % 7, c = y % 19, d = (19 * c + 15) % 30, e = (2 * a + 4 * b - d + 34) % 7;
        const month = Math.floor((d + e + 114) / 31), day = ((d + e + 114) % 31) + 1;
        const dt = new Date(y, month - 1, day);
        dt.setDate(dt.getDate() + 13);
        return dt;
    }
    function forYear(y) {
        const e = orthodoxEaster(y);
        const off = n => { const d = new Date(e); d.setDate(d.getDate() + n); return d; };
        return [
            [new Date(y, 0, 1), "New Year's Day"], [new Date(y, 2, 3), "Liberation Day"],
            [off(-2), "Good Friday"], [off(0), "Easter"], [off(1), "Easter Monday"],
            [new Date(y, 4, 1), "Labour Day"], [new Date(y, 4, 6), "St George's Day"], [new Date(y, 4, 24), "Culture and Literacy Day"],
            [new Date(y, 8, 6), "Unification Day"], [new Date(y, 8, 22), "Independence Day"],
            [new Date(y, 11, 24), "Christmas Eve"], [new Date(y, 11, 25), "Christmas"], [new Date(y, 11, 26), "Christmas (2nd day)"]
        ].map(h => ({ title: h[1], start: h[0].getTime(), end: h[0].getTime(), cal: "Holidays (BG)", allDay: true }));
    }
}
