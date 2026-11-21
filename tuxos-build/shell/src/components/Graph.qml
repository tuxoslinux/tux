import QtQuick
import qs.theme

// A small live line graph with a soft fill (System manager, overview,
// HUD). values: numbers 0..max, oldest first; shows the last `points`.
Canvas {
    id: g
    property var values: []
    property real max: 100
    property int points: 60
    property color color: Theme.accent
    property bool grid: false
    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    renderStrategy: Canvas.Cooperative
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width, h = height, n = points;
        if (grid) {
            ctx.strokeStyle = Theme.ink(0.06); ctx.lineWidth = 1;
            for (let i = 1; i < 4; i++) { ctx.beginPath(); ctx.moveTo(0, h * i / 4); ctx.lineTo(w, h * i / 4); ctx.stroke(); }
        }
        const v = values.slice(-n);
        if (v.length < 2) return;
        const x = i => w - (v.length - 1 - i) * w / (n - 1);
        const y = val => h - 2 - Math.max(0, Math.min(1, val / (max || 1))) * (h - 4);
        ctx.beginPath();
        ctx.moveTo(x(0), y(v[0]));
        for (let i = 1; i < v.length; i++) ctx.lineTo(x(i), y(v[i]));
        ctx.strokeStyle = g.color; ctx.lineWidth = 2; ctx.stroke();
        ctx.lineTo(x(v.length - 1), h); ctx.lineTo(x(0), h); ctx.closePath();
        const grad = ctx.createLinearGradient(0, 0, 0, h);
        grad.addColorStop(0, Qt.rgba(g.color.r, g.color.g, g.color.b, 0.30));
        grad.addColorStop(1, Qt.rgba(g.color.r, g.color.g, g.color.b, 0.0));
        ctx.fillStyle = grad; ctx.fill();
    }
}
