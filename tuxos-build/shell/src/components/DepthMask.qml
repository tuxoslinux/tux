import QtQuick
import Quickshell

// Makes the depth-effect mask of a wallpaper (SPEC round 4 #13): the
// picture is shrunk; down each column the sky's brightness trend is
// followed and the subject starts where it breaks for good (landscapes,
// skylines, people against a sky); white = subject, transparent = sky,
// edges softened. Settings can touch it up by hand.
// save(file) writes it as a PNG; Settings can touch it up by hand.
Canvas {
    id: dm
    property url source: ""
    property real tolerance: 7          // how far (0-255, plus 5) the sky may stray from its trend
    signal made()
    width: 384; height: 216
    visible: true
    opacity: 0.01                       // painted (save() needs that), but not seen
    renderStrategy: Canvas.Immediate
    renderTarget: Canvas.Image          // an in-memory image: save() writes what was drawn
    // the mask keeps the picture's shape (384 px wide), so it lines up with
    // the wallpaper wherever both are cropped the same way
    Image {
        id: probe
        source: dm.source
        visible: false
        asynchronous: true
        sourceSize.width: 64
        onStatusChanged: if (status === Image.Ready && implicitWidth > 0) {
            dm.height = Math.round(dm.width * implicitHeight / implicitWidth);
            dm.loadImage(dm.source);
            dm.requestPaint();
        }
    }
    onImageLoaded: requestPaint()
    property bool ready: false
    property bool found: false          // the picture has a subject worth the effect
    onPaint: {
        if (!source.toString() || !isImageLoaded(source) || probe.status !== Image.Ready) return;
        const c = getContext("2d"), W = width, H = height;
        c.clearRect(0, 0, W, H);
        c.drawImage(source, 0, 0, W, H);
        const img = c.getImageData(0, 0, W, H), d = img.data;
        const lum = new Float32Array(W * H);
        for (let i = 0; i < W * H; i++) lum[i] = 0.299 * d[i * 4] + 0.587 * d[i * 4 + 1] + 0.114 * d[i * 4 + 2];
        if (Quickshell.env("TUXOS_DEBUG")) { let sum = 0; for (let i = 0; i < W * H; i++) sum += lum[i]; console.log("depth mask: mean brightness", sum / (W * H), "pixels", d.length); }
        // per column: follow the sky's brightness trend down from the top;
        // the subject starts at the first lasting break from it (a drop to a
        // dark silhouette or a jump to a bright one), and goes to the bottom
        const top = new Int32Array(W);
        for (let x = 0; x < W; x++) {
            let ema = lum[x], run = 0, start = 0, y0 = H;
            for (let y = 1; y < H; y++) {
                const v = lum[y * W + x], thr = Math.max(tolerance + 5, 0.35 * ema);
                if (Math.abs(v - ema) > thr) {
                    if (++run === 1) start = y;
                    if (run >= 3) { y0 = start; break; }
                } else { run = 0; ema = 0.8 * ema + 0.2 * v; }
            }
            top[x] = y0;
        }
        // smooth across columns (median of 7), never in the top 12 %; drawn
        // as fills (Qt's putImageData does not write the pixels back), with
        // a two-pixel soft edge
        c.clearRect(0, 0, W, H);
        let n = 0, cols = 0, minY = H, maxY = 0;
        for (let x = 0; x < W; x++) {
            const win = [];
            for (let k = Math.max(0, x - 3); k <= Math.min(W - 1, x + 3); k++) win.push(top[k]);
            win.sort((a, b) => a - b);
            const y0 = Math.max(Math.floor(H * 0.12), win[Math.floor(win.length / 2)]);
            if (y0 >= H) continue;
            cols++; minY = Math.min(minY, y0); maxY = Math.max(maxY, y0);
            c.fillStyle = "rgba(255,255,255,1)"; c.fillRect(x, y0, 1, H - y0);
            c.fillStyle = "rgba(255,255,255,0.6)"; c.fillRect(x, y0 - 1, 1, 1);
            c.fillStyle = "rgba(255,255,255,0.25)"; c.fillRect(x, y0 - 2, 1, 1);
            n += H - y0;
        }
        // is there depth at all? A subject across most of the picture, neither
        // a sliver nor everything, with an outline that is not one flat line
        // (a plain horizon) and that rises into where the clock sits
        const cover = n / (W * H);
        found = cols >= W * 0.5 && cover >= 0.08 && cover <= 0.85 && (maxY - minY) >= H * 0.08 && minY <= H * 0.62;
        if (Quickshell.env("TUXOS_DEBUG")) console.log("depth mask: subject pixels", n, "of", W * H, "cover", cover.toFixed(2), "outline", minY, "-", maxY, "found", found);
        fresh = true;
    }
    // save() only sees the mask once it is painted
    property bool fresh: false
    onPainted: if (fresh) { fresh = false; ready = true; made(); }
}
