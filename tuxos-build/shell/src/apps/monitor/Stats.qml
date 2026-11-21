import QtQuick
import Quickshell
import Quickshell.Io

// Live numbers for the System manager: runs tuxos-sample while the app is
// open and turns its counters into rates and 60-second histories.
QtObject {
    id: st
    property bool running: true
    readonly property int keep: 60

    // CPU
    property real cpu: 0
    property var cores: []                 // % per thread
    property var cpuHist: []
    property var coreHist: []
    property int mhz: 0
    property int temp: -1
    // memory (kB)
    property real memTotal: 0
    property real memUsed: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property var memHist: []
    // disks / network: name -> { r, w } / { rx, tx, rxTotal, txTotal }
    property var disks: ({})
    property var diskHist: ({})
    property var nets: ({})
    property var netHist: ({})
    // GPU
    property var gpu: null                 // { kind, util, vramUsed, vramTotal, temp, clock, fan, power }
    property var gpuHist: []

    property var prev: null
    function push(arr, v) { const a = arr.concat([v]); return a.length > keep ? a.slice(a.length - keep) : a; }

    property Process proc: Process {
        running: st.running
        command: ["tuxos-sample", "1"]
        stdout: SplitParser {
            property var cur: ({})
            onRead: line => {
                if (line === "END") { st.take(cur); cur = {}; return; }
                const p = line.split(" ");
                if (p[0] === "T") cur.t = parseInt(p[1].slice(0, -6));
                else if (p[0].startsWith("cpu")) { (cur.cpu = cur.cpu || []).push(p.slice(1).map(Number)); }
                else if (p[0] === "M") (cur.mem = cur.mem || {})[p[1]] = +p[2];
                else if (p[0] === "D") (cur.disk = cur.disk || {})[p[1]] = [+p[2], +p[3]];
                else if (p[0] === "N") (cur.net = cur.net || {})[p[1]] = [+p[2], +p[3]];
                else if (p[0] === "F") cur.mhz = +p[1];
                else if (p[0] === "C") cur.temp = +p[1];
                else if (p[0] === "G") cur.gpu = p[1].split(",");
            }
        }
    }

    function take(c) {
        if (!c.cpu) return;
        const p = prev;
        prev = c;
        mhz = c.mhz || 0;
        temp = c.temp !== undefined ? c.temp : -1;
        const m = c.mem || {};
        memTotal = m.MemTotal || 0;
        memUsed = memTotal - (m.MemAvailable || 0);
        memCached = (m.Cached || 0) + (m.Buffers || 0);
        swapTotal = m.SwapTotal || 0;
        swapUsed = swapTotal - (m.SwapFree || 0);
        memHist = push(memHist, memTotal ? memUsed / memTotal * 100 : 0);
        if (c.gpu) {
            const g = c.gpu;
            gpu = { kind: g[0], util: +g[1] || 0, vramUsed: +g[2] || 0, vramTotal: +g[3] || 0, temp: g[4], clock: g[5], fan: g[6], power: g[7] };
            gpuHist = push(gpuHist, gpu.util);
        }
        if (!p) return;
        const dt = Math.max(0.2, (c.t - p.t) / 1000);
        // cpu: busy = total - idle - iowait
        const pct = (a, b) => { const ta = a.reduce((x, y) => x + y, 0), tb = b.reduce((x, y) => x + y, 0); const ia = a[3] + a[4], ib = b[3] + b[4]; const d = tb - ta; return d > 0 ? Math.max(0, Math.min(100, (d - (ib - ia)) / d * 100)) : 0; };
        cpu = pct(p.cpu[0], c.cpu[0]);
        cpuHist = push(cpuHist, cpu);
        const cs = [], ch = [];
        for (let i = 1; i < c.cpu.length && i < p.cpu.length; i++) {
            const v = pct(p.cpu[i], c.cpu[i]);
            cs.push(v);
            ch.push(push(coreHist[i - 1] || [], v));
        }
        cores = cs; coreHist = ch;
        const d = {}, dh = Object.assign({}, diskHist);
        for (const k in c.disk || {}) if (p.disk && p.disk[k]) {
            const r = (c.disk[k][0] - p.disk[k][0]) * 512 / dt, w = (c.disk[k][1] - p.disk[k][1]) * 512 / dt;
            d[k] = { r: r, w: w };
            dh[k] = push(dh[k] || [], (r + w) / 1048576);
        }
        disks = d; diskHist = dh;
        const n = {}, nh = Object.assign({}, netHist);
        for (const k in c.net || {}) if (p.net && p.net[k]) {
            const rx = (c.net[k][0] - p.net[k][0]) / dt, tx = (c.net[k][1] - p.net[k][1]) / dt;
            n[k] = { rx: rx, tx: tx, rxTotal: c.net[k][0], txTotal: c.net[k][1] };
            nh[k] = push(nh[k] || [], (rx + tx) / 1024);
        }
        nets = n; netHist = nh;
    }

    function bytes(b) {
        if (b >= 1e12) return (b / 1e12).toFixed(2) + " TB";
        if (b >= 1e9) return (b / 1e9).toFixed(1) + " GB";
        if (b >= 1e6) return (b / 1e6).toFixed(1) + " MB";
        if (b >= 1e3) return (b / 1e3).toFixed(0) + " kB";
        return Math.round(b) + " B";
    }
    function rate(b) { return bytes(b) + "/s"; }
}
