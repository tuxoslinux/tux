pragma Singleton

import QtQuick
import Quickshell
import qs.theme
import Quickshell.Io

// Launcher answers (SPEC "App launcher", round 4): maths ("=" or a plain
// expression, %, ^, functions), unit conversions ("5 km to miles",
// "20 c in f", "3 m3 to l"), currencies ("100 usd to bgn", rates from the
// ECB through frankfurter.app, cached; offline: last cache, then built-in
// rates) and "time in Tokyo".
Singleton {
    id: calc

    // ------------------------------------------------------------ maths
    // a small recursive-descent parser; never eval()
    function evaluate(src) {
        let s = src.replace(/\s+/g, "").replace(/[×x](?=[\d(.])/g, "*").replace(/÷/g, "/").replace(/,/g, ".").replace(/π/g, "pi");
        let i = 0;
        const fns = {
            sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, ln: Math.log, log: Math.log10, log2: Math.log2,
            exp: Math.exp, round: Math.round, floor: Math.floor, ceil: Math.ceil,
            sin: x => Math.sin(x * Math.PI / 180), cos: x => Math.cos(x * Math.PI / 180), tan: x => Math.tan(x * Math.PI / 180),
            asin: x => Math.asin(x) * 180 / Math.PI, acos: x => Math.acos(x) * 180 / Math.PI, atan: x => Math.atan(x) * 180 / Math.PI
        };
        const consts = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI };
        function peek() { return s[i]; }
        function expr() {
            let v = term();
            while (peek() === "+" || peek() === "-") {
                const op = s[i++];
                let r = term();
                // "200 + 10%" means 200 + 10 % of 200
                if (r && r.pct) r = v * r.value / 100;
                v = op === "+" ? v + num(r) : v - num(r);
            }
            return v;
        }
        function num(x) { return (x && x.pct) ? x.value / 100 : x; }
        function term() {
            let v = factor();
            while (peek() === "*" || peek() === "/") {
                const op = s[i++];
                const r = num(factor());
                v = op === "*" ? num(v) * r : num(v) / r;
            }
            // "20% of 150"
            if (s.startsWith("of", i) && v && v.pct) { i += 2; return v.value / 100 * num(factor()); }
            return v;
        }
        // unary minus binds looser than ^ : -3^2 = -9
        function factor() {
            if (peek() === "-") { i++; return -num(factor()); }
            if (peek() === "+") { i++; return factor(); }
            let v = postfix();
            if (peek() === "^") { i++; v = Math.pow(num(v), num(factor())); }
            return v;
        }
        function postfix() {
            let v = atom();
            while (true) {
                if (peek() === "%") { i++; v = { pct: true, value: v }; continue; }
                if (peek() === "!") { i++; let f = 1; for (let k = 2; k <= v; k++) f *= k; v = f; continue; }
                break;
            }
            return v;
        }
        function atom() {
            if (peek() === "(") { i++; const v = expr(); if (peek() !== ")") throw "paren"; i++; return num(v); }
            const m = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(s.slice(i));
            if (m) { i += m[0].length; return parseFloat(m[0]); }
            const w = /^[a-z]+\d?/i.exec(s.slice(i));
            if (w) {
                const name = w[0].toLowerCase();
                i += w[0].length;
                if (fns[name]) { const a = num(atom()); return fns[name](a); }
                if (consts[name] !== undefined) return consts[name];
            }
            throw "bad";
        }
        const v = num(expr());
        if (i !== s.length || typeof v !== "number" || !isFinite(v)) throw "bad";
        return v;
    }

    function fmt(v) {
        if (Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0)) return v.toExponential(6).replace(/\.?0+e/, "e");
        const r = Math.round(v * 1e10) / 1e10;
        const parts = String(r).split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, " ");
        return parts.join(".");
    }

    // ------------------------------------------------------------ units
    // factor to the base unit of its kind
    readonly property var units: ({
        length: { m: 1, km: 1000, cm: 0.01, mm: 0.001, um: 1e-6, nm: 1e-9, mi: 1609.344, mile: 1609.344, miles: 1609.344, yd: 0.9144, yard: 0.9144, yards: 0.9144, ft: 0.3048, foot: 0.3048, feet: 0.3048, "in": 0.0254, inch: 0.0254, inches: 0.0254, nmi: 1852 },
        area: { m2: 1, km2: 1e6, cm2: 1e-4, mm2: 1e-6, ha: 1e4, acre: 4046.8564224, acres: 4046.8564224, ft2: 0.09290304, in2: 0.00064516, mi2: 2589988.110336 },
        volume: { m3: 1, l: 0.001, liter: 0.001, liters: 0.001, litre: 0.001, ml: 1e-6, cl: 1e-5, dl: 1e-4, cm3: 1e-6, ft3: 0.028316846592, in3: 1.6387064e-5, gal: 0.003785411784, gallon: 0.003785411784, gallons: 0.003785411784, qt: 0.000946352946, pt: 0.000473176473, cup: 0.00024, floz: 2.95735295625e-5 },
        mass: { kg: 1, g: 0.001, mg: 1e-6, t: 1000, tonne: 1000, lb: 0.45359237, lbs: 0.45359237, pound: 0.45359237, pounds: 0.45359237, oz: 0.028349523125, st: 6.35029318 },
        speed: { "m/s": 1, mps: 1, "km/h": 1 / 3.6, kmh: 1 / 3.6, kph: 1 / 3.6, mph: 0.44704, kn: 0.514444, knots: 0.514444 },
        data: { b: 1, bit: 0.125, bits: 0.125, kb: 1000, mb: 1e6, gb: 1e9, tb: 1e12, pb: 1e15, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776, kbit: 125, mbit: 125000, gbit: 1.25e8 },
        energy: { j: 1, kj: 1000, cal: 4.184, kcal: 4184, wh: 3600, kwh: 3.6e6, ev: 1.602176634e-19, btu: 1055.06 },
        pressure: { pa: 1, kpa: 1000, mpa: 1e6, bar: 1e5, mbar: 100, atm: 101325, psi: 6894.757, mmhg: 133.322 },
        time: { s: 1, sec: 1, ms: 0.001, min: 60, h: 3600, hr: 3600, hours: 3600, day: 86400, days: 86400, week: 604800, weeks: 604800, month: 2629746, months: 2629746, year: 31556952, years: 31556952 },
        angle: { deg: 1, rad: 180 / Math.PI, grad: 0.9, turn: 360 },
        power: { w: 1, kw: 1000, mw: 1e6, hp: 745.699872 },
        fuel: { "l/100km": "fuel", mpg: "fuel", "km/l": "fuel" }
    })
    readonly property var temps: ["c", "f", "k", "celsius", "fahrenheit", "kelvin"]

    function unitKind(u) {
        for (const k in units) if (units[k][u] !== undefined) return k;
        return "";
    }
    function convertUnits(v, a, b) {
        a = a.toLowerCase(); b = b.toLowerCase();
        if (temps.indexOf(a) !== -1 && temps.indexOf(b) !== -1) {
            const c = a[0] === "c" ? v : a[0] === "f" ? (v - 32) * 5 / 9 : v - 273.15;
            return b[0] === "c" ? c : b[0] === "f" ? c * 9 / 5 + 32 : c + 273.15;
        }
        const ka = unitKind(a), kb = unitKind(b);
        if (!ka || ka !== kb) return NaN;
        if (ka === "fuel") {
            // to l/100km first
            const l100 = a === "l/100km" ? v : a === "mpg" ? 235.214583 / v : 100 / v;
            return b === "l/100km" ? l100 : b === "mpg" ? 235.214583 / l100 : 100 / l100;
        }
        return v * units[ka][a] / units[kb][b];
    }

    // ------------------------------------------------------------ currency
    // EUR-based; BGN is pegged (1.95583). Fallback values for offline use.
    property var rates: ({ EUR: 1, BGN: 1.95583, USD: 1.08, GBP: 0.84, CHF: 0.95, JPY: 165, CNY: 7.8, RON: 4.97, TRY: 37, PLN: 4.3, CZK: 25.2, HUF: 395, SEK: 11.4, NOK: 11.6, DKK: 7.46, CAD: 1.48, AUD: 1.63, INR: 90, KRW: 1470, BRL: 6.0, MXN: 20, ZAR: 19.6 })
    property string ratesDate: "built-in"
    readonly property var currencyWords: ({ "$": "USD", dollar: "USD", dollars: "USD", "€": "EUR", euro: "EUR", euros: "EUR", lev: "BGN", leva: "BGN", "лв": "BGN", "£": "GBP", pound: "GBP", yen: "JPY" })

    FileView {
        id: rateCache
        path: Quickshell.cachePath("rates.json")
        printErrors: false      // not fetched yet
        onLoaded: {
            try {
                const j = JSON.parse(text());
                if (j.rates) { const r = j.rates; r.EUR = 1; calc.rates = r; calc.ratesDate = j.date || "cache"; }
            } catch (e) {}
        }
    }
    property double fetchedAt: 0
    Process {
        id: fetchRates
        command: ["curl", "-fsS", "--max-time", "6", "https://api.frankfurter.app/latest?from=EUR"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (j.rates) { j.rates.EUR = 1; calc.rates = j.rates; calc.ratesDate = j.date; rateCache.setText(text); }
                } catch (e) {}
            }
        }
    }
    function refreshRates() {
        // at most every 6 hours, only when someone converts money
        if (Date.now() - fetchedAt < 6 * 3600 * 1000) return;
        fetchedAt = Date.now();
        fetchRates.running = true;
    }
    function currency(w) {
        const l = w.toLowerCase();
        if (currencyWords[l]) return currencyWords[l];
        const u = w.toUpperCase();
        return rates[u] !== undefined ? u : "";
    }

    // ------------------------------------------------------------ cities
    readonly property var cities: ({
        tokyo: "Asia/Tokyo", sofia: "Europe/Sofia", plovdiv: "Europe/Sofia", varna: "Europe/Sofia", london: "Europe/London",
        paris: "Europe/Paris", berlin: "Europe/Berlin", madrid: "Europe/Madrid", rome: "Europe/Rome", amsterdam: "Europe/Amsterdam",
        athens: "Europe/Athens", istanbul: "Europe/Istanbul", moscow: "Europe/Moscow", kyiv: "Europe/Kyiv", bucharest: "Europe/Bucharest",
        "new york": "America/New_York", nyc: "America/New_York", "los angeles": "America/Los_Angeles", la: "America/Los_Angeles",
        chicago: "America/Chicago", toronto: "America/Toronto", "san francisco": "America/Los_Angeles", seattle: "America/Los_Angeles",
        "mexico city": "America/Mexico_City", "sao paulo": "America/Sao_Paulo", "buenos aires": "America/Argentina/Buenos_Aires",
        dubai: "Asia/Dubai", delhi: "Asia/Kolkata", mumbai: "Asia/Kolkata", beijing: "Asia/Shanghai", shanghai: "Asia/Shanghai",
        "hong kong": "Asia/Hong_Kong", singapore: "Asia/Singapore", seoul: "Asia/Seoul", sydney: "Australia/Sydney",
        melbourne: "Australia/Melbourne", auckland: "Pacific/Auckland", cairo: "Africa/Cairo", johannesburg: "Africa/Johannesburg",
        utc: "UTC", gmt: "UTC"
    })

    // ------------------------------------------------------------ answer
    // returns null or { title, subtitle, copy } ; time zones are answered
    // asynchronously through `zoneAnswer`
    property var zoneAnswer: null
    property string zoneAsked: ""
    Process {
        id: zoneProc
        property string city: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim().split("|");
                if (t.length === 2) calc.zoneAnswer = { title: t[0], subtitle: `${zoneProc.city} · ${t[1]}`, copy: t[0], kind: "Time" };
            }
        }
    }

    function answer(q) {
        q = q.trim();
        if (!q) return null;
        const forced = q.startsWith("=");
        const body = forced ? q.slice(1) : q;

        // time in <city>
        let m = /^(?:time\s+in|time|часът\s+в)\s+(.+)$/i.exec(body);
        if (m) {
            const city = m[1].toLowerCase().trim();
            const tz = cities[city];
            if (tz) {
                if (zoneAsked !== tz) {
                    zoneAsked = tz;
                    zoneAnswer = null;
                    zoneProc.city = m[1].replace(/\b\w/g, c => c.toUpperCase());
                    zoneProc.environment = { TZ: tz };
                    zoneProc.command = ["date", "+%H:%M|%a %-d %b, UTC%:z"];
                    zoneProc.running = true;
                }
                return zoneAnswer;
            }
        }

        // <n> <unit|currency> (to|in) <unit|currency>
        m = /^([\d.,\s+\-*/^()]+?)\s*([a-zа-я$€£\/0-9]+)\s+(?:to|in|into|в)\s+([a-zа-я$€£\/0-9]+)$/i.exec(body);
        if (m) {
            let v;
            try { v = evaluate(m[1]); } catch (e) { v = NaN; }
            if (!isNaN(v)) {
                const ca = currency(m[2]), cb = currency(m[3]);
                if (ca && cb) {
                    refreshRates();
                    const r = v / rates[ca] * rates[cb];
                    return { title: `${fmt(Math.round(r * 100) / 100)} ${cb}`, subtitle: `${fmt(v)} ${ca} · rates ${ratesDate}`, copy: String(Math.round(r * 100) / 100), kind: "Currency" };
                }
                const r = convertUnits(v, m[2], m[3]);
                if (!isNaN(r))
                    return { title: `${fmt(Math.round(r * 1e6) / 1e6)} ${m[3]}`, subtitle: `${fmt(v)} ${m[2]}`, copy: String(Math.round(r * 1e6) / 1e6), kind: "Convert" };
            }
        }

        // plain maths: needs an operator or a function unless forced with "="
        if (forced || /[\d)]\s*[-+*/^%x×÷!]|\b(sqrt|sin|cos|tan|log|ln|pi)\b/i.test(body)) {
            try {
                const v = evaluate(body);
                return { title: fmt(v), subtitle: body.trim() + " =", copy: String(Math.round(v * 1e10) / 1e10), kind: "Calculator" };
            } catch (e) {
                return forced ? { title: "…", subtitle: Tr.t("Keep typing"), copy: "", kind: "Calculator" } : null;
            }
        }
        return null;
    }
}
