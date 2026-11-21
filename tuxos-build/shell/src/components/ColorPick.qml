import QtQuick
import qs.theme

// Picks a readable accent from a picture (accent from wallpaper / album
// art): the most common bright, saturated hue, brought to the lightness the
// shell's text uses on dark glass. Grey pictures give no colour (picked
// is not emitted), so the accent stays as it is.
Canvas {
    id: cp
    property url source: ""
    signal picked(color c)
    width: 48; height: 48
    visible: true
    opacity: 0
    renderStrategy: Canvas.Immediate
    renderTarget: Canvas.Image          // an in-memory image: save() writes what was drawn
    // a picture seen before is already loaded (no imageLoaded again): paint now
    onSourceChanged: if (source.toString()) { if (isImageLoaded(source)) requestPaint(); else loadImage(source); }
    onImageLoaded: requestPaint()
    onPaint: {
        if (!source.toString() || !isImageLoaded(source)) return;
        const c = getContext("2d");
        c.clearRect(0, 0, width, height);
        c.drawImage(source, 0, 0, width, height);
        const d = c.getImageData(0, 0, width, height).data;
        const bins = new Array(24).fill(0).map(() => ({ w: 0, r: 0, g: 0, b: 0 }));
        let total = 0;
        for (let i = 0; i < d.length; i += 4) {
            const r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255;
            const max = Math.max(r, g, b), min = Math.min(r, g, b), v = max, s = max ? (max - min) / max : 0;
            if (s < 0.25 || v < 0.2) continue;
            let h = 0;
            if (max === r) h = ((g - b) / (max - min)) % 6; else if (max === g) h = (b - r) / (max - min) + 2; else h = (r - g) / (max - min) + 4;
            h = (h * 60 + 360) % 360;
            const w = s * v, k = Math.floor(h / 15) % 24;
            bins[k].w += w; bins[k].r += r * w; bins[k].g += g * w; bins[k].b += b * w; total += w;
        }
        let best = null;
        for (const bn of bins) if (!best || bn.w > best.w) best = bn;
        if (!best || best.w < 0.02 * width * height || total === 0) return;      // a grey picture
        const col = Qt.rgba(best.r / best.w, best.g / best.w, best.b / best.w, 1);
        // readable on the dark glass: HSL lightness ~0.74, saturation >= 0.55
        cp.picked(Qt.hsla(col.hslHue, Math.max(0.55, Math.min(0.9, col.hslSaturation)), 0.74, 1));
    }
}
