#!/usr/bin/env python3
"""Builds the TuxOS cursor theme (SPEC: white, dark outline, blue busy ring)
as Xcursor files, without xcursorgen: python3 make-cursors.py OUTDIR"""
import math, os, struct, sys
from PIL import Image, ImageDraw, ImageFilter

WHITE, OUT, BLUE = (244, 247, 251, 255), (11, 20, 36, 255), (143, 184, 255, 255)
SIZES = (24, 32, 48, 64)
SS = 8  # supersampling

def canvas(n): return Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))

def finish(img, n, shadow=True):
    if shadow:
        a = img.split()[3].filter(ImageFilter.GaussianBlur(SS * n / 24 * 1.2))
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0)); sh.putalpha(a.point(lambda v: int(v * 0.35)))
        base = Image.new("RGBA", img.size, (0, 0, 0, 0)); base.paste(sh, (0, int(SS * n / 24))); base.alpha_composite(img); img = base
    return img.resize((n, n), Image.LANCZOS)

def poly(d, pts, n, s=1.0):
    k = SS * n / 24 * s
    return [(x * k, y * k) for x, y in pts]

def outlined(d, pts, n, width=1.5):
    k = SS * n / 24
    d.polygon(pts, fill=WHITE, outline=None)
    d.line(pts + [pts[0]], fill=OUT, width=int(width * k), joint="curve")

ARROW = [(3, 2), (3, 19), (7.5, 15), (10.5, 21.5), (13, 20.5), (10, 14.2), (16, 14.2)]

def arrow(n):
    img = canvas(n); d = ImageDraw.Draw(img); outlined(d, poly(d, ARROW, n), n); return finish(img, n), (3 * n // 24, 2 * n // 24)

def ring(n, phase, small=False):
    img = canvas(n); d = ImageDraw.Draw(img); k = SS * n / 24
    if small:
        d2 = ImageDraw.Draw(img); outlined(d2, poly(d2, ARROW, n, 0.8), n)
        cx, cy, r, w = 17 * k, 17 * k, 4.5 * k, 2.2 * k
    else:
        cx, cy, r, w = 12 * k, 12 * k, 8 * k, 3 * k
    d.ellipse((cx - r - w / 2 - k, cy - r - w / 2 - k, cx + r + w / 2 + k, cy + r + w / 2 + k), outline=OUT, width=int(w + 2 * k))
    d.ellipse((cx - r - w / 2, cy - r - w / 2, cx + r + w / 2, cy + r + w / 2), outline=(255, 255, 255, 70), width=int(w))
    d.arc((cx - r - w / 2, cy - r - w / 2, cx + r + w / 2, cy + r + w / 2), start=phase, end=phase + 110, fill=BLUE, width=int(w))
    return finish(img, n), ((3 * n // 24, 2 * n // 24) if small else (n // 2, n // 2))

def hand(n):
    img = canvas(n); d = ImageDraw.Draw(img); k = SS * n / 24
    pts = [(9, 2.5), (11, 2.5), (11.5, 3.2), (11.5, 10), (13.5, 9.5), (15.5, 10), (17.5, 10.6), (19, 11.6), (19, 17), (17.5, 21.5), (11, 21.5), (6, 16), (5, 13.5), (6.2, 12.6), (8.2, 13.6), (8.5, 3.2)]
    outlined(d, poly(d, pts, n), n)
    for x in (11.5, 13.5, 15.5, 17.5):
        d.line([(x * k, 12 * k), (x * k, 15.5 * k)], fill=OUT, width=int(1 * k))
    return finish(img, n), (int(9.8 * n / 24), int(2.6 * n / 24))

def ibeam(n):
    img = canvas(n); d = ImageDraw.Draw(img); k = SS * n / 24
    segs = [[(8, 3), (10.5, 3), (12, 4.3), (13.5, 3), (16, 3)], [(12, 4.3), (12, 19.7)], [(8, 21), (10.5, 21), (12, 19.7), (13.5, 21), (16, 21)]]
    for s in segs: d.line([(x * k, y * k) for x, y in s], fill=OUT, width=int(4 * k), joint="curve")
    for s in segs: d.line([(x * k, y * k) for x, y in s], fill=WHITE, width=int(1.8 * k), joint="curve")
    return finish(img, n), (n // 2, n // 2)

def cross(n):
    img = canvas(n); d = ImageDraw.Draw(img); k = SS * n / 24
    for w, c in ((4, OUT), (1.8, WHITE)):
        d.line([(12 * k, 2 * k), (12 * k, 22 * k)], fill=c, width=int(w * k)); d.line([(2 * k, 12 * k), (22 * k, 12 * k)], fill=c, width=int(w * k))
    return finish(img, n), (n // 2, n // 2)

def arrows(n, dirs):
    """resize / move: double arrows along dirs (list of angles in degrees)"""
    img = canvas(n); d = ImageDraw.Draw(img); k = SS * n / 24; c = 12 * k
    for w, col in ((4.2, OUT), (2, WHITE)):
        for a in dirs:
            r = math.radians(a); dx, dy = math.cos(r), math.sin(r)
            d.line([(c - dx * 8.5 * k, c - dy * 8.5 * k), (c + dx * 8.5 * k, c + dy * 8.5 * k)], fill=col, width=int(w * k))
            for s in (1, -1):
                tip = (c + s * dx * 9.5 * k, c + s * dy * 9.5 * k)
                for t in (2.6, -2.6):
                    bx = c + s * dx * 6 * k - dy * t * k; by = c + s * dy * 6 * k + dx * t * k
                    d.line([tip, (bx, by)], fill=col, width=int(w * k))
    return finish(img, n), (n // 2, n // 2)

def forbidden(n):
    img = canvas(n); d = ImageDraw.Draw(img); k = SS * n / 24; c, r = 12 * k, 8 * k
    for w, col in ((4.5, OUT), (2.4, (255, 122, 138, 255))):
        d.ellipse((c - r, c - r, c + r, c + r), outline=col, width=int(w * k))
        d.line([(c - r * 0.7, c + r * 0.7), (c + r * 0.7, c - r * 0.7)], fill=col, width=int(w * k))
    return finish(img, n), (n // 2, n // 2)

def help_(n):
    img, hot = arrow(n)
    big = canvas(n); d = ImageDraw.Draw(big); k = SS * n / 24
    d.ellipse((13 * k, 13 * k, 23 * k, 23 * k), fill=BLUE, outline=OUT, width=int(1.2 * k))
    d.text((16.3 * k, 13.6 * k), "?", fill=OUT, font_size=int(8 * k)) if hasattr(d, "text") else None
    img.alpha_composite(finish(big, n, False)); return img, hot

def write(path, frames):
    """frames: list of (size, image, hot, delay)"""
    toc, chunks, pos = [], [], 16 + 12 * len(frames)
    for size, img, hot, delay in frames:
        w, h = img.size
        px = bytearray()
        raw = img.tobytes()
        for i in range(0, len(raw), 4):
            r, g, b, a = raw[i], raw[i + 1], raw[i + 2], raw[i + 3]
            px += struct.pack("<I", (a << 24) | ((r * a // 255) << 16) | ((g * a // 255) << 8) | (b * a // 255))
        chunk = struct.pack("<IIIIIIIII", 36, 0xfffd0002, size, 1, w, h, hot[0], hot[1], delay) + bytes(px)
        toc.append(struct.pack("<III", 0xfffd0002, size, pos)); chunks.append(chunk); pos += len(chunk)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(frames))); f.write(b"".join(toc)); f.write(b"".join(chunks))

def build(out):
    cur = os.path.join(out, "cursors"); os.makedirs(cur, exist_ok=True)
    def one(name, fn, *a):
        frames = []
        for n in SIZES:
            img, hot = fn(n, *a); frames.append((n, img, hot, 0))
        write(os.path.join(cur, name), frames)
    def anim(name, small):
        frames = []
        for n in SIZES:
            for i in range(12):
                img, hot = ring(n, i * 30 - 90, small); frames.append((n, img, hot, 50))
        write(os.path.join(cur, name), frames)
    one("default", arrow); one("pointer", hand); one("text", ibeam); one("crosshair", cross); one("not-allowed", forbidden); one("help", help_)
    one("move", arrows, [0, 90]); one("ew-resize", arrows, [0]); one("ns-resize", arrows, [90]); one("nwse-resize", arrows, [45]); one("nesw-resize", arrows, [135])
    anim("wait", False); anim("progress", True)
    aliases = {"default": ["left_ptr", "arrow", "top_left_arrow", "context-menu", "alias", "copy", "cell", "vertical-text", "default"],
               "pointer": ["hand1", "hand2", "pointing_hand", "grab", "grabbing", "openhand", "closedhand", "fleur-hand", "9d800788f1b08800ae810202380a0822", "e29285e634086352946a0e7090d73106"],
               "text": ["xterm", "ibeam"], "crosshair": ["cross", "tcross", "color-picker", "plus", "cell"],
               "not-allowed": ["no-drop", "forbidden", "circle", "crossed_circle", "dnd-no-drop"], "help": ["question_arrow", "whats_this", "left_ptr_help"],
               "move": ["fleur", "all-scroll", "size_all", "dnd-move", "dnd-none"],
               "ew-resize": ["col-resize", "e-resize", "w-resize", "size_hor", "sb_h_double_arrow", "h_double_arrow", "right_side", "left_side", "split_h"],
               "ns-resize": ["row-resize", "n-resize", "s-resize", "size_ver", "sb_v_double_arrow", "v_double_arrow", "top_side", "bottom_side", "split_v"],
               "nwse-resize": ["nw-resize", "se-resize", "size_fdiag", "bd_double_arrow", "top_left_corner", "bottom_right_corner"],
               "nesw-resize": ["ne-resize", "sw-resize", "size_bdiag", "fd_double_arrow", "top_right_corner", "bottom_left_corner"],
               "wait": ["watch", "clock"], "progress": ["left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599"]}
    for target, names in aliases.items():
        for nm in names:
            p = os.path.join(cur, nm)
            if nm == target or os.path.exists(p): continue
            os.symlink(target, p)
    with open(os.path.join(out, "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=TuxOS\nComment=White cursors with a dark outline and a blue busy ring\n")
    with open(os.path.join(out, "cursor.theme"), "w") as f:
        f.write("[Icon Theme]\nName=TuxOS\n")
    # preview sheet
    names = ["default", "pointer", "text", "crosshair", "move", "ew-resize", "nwse-resize", "not-allowed", "help"]
    sheet = Image.new("RGBA", (len(names) * 72 + 3 * 72, 80), (40, 44, 52, 255))
    fns = [arrow, hand, ibeam, cross, lambda n: arrows(n, [0, 90]), lambda n: arrows(n, [0]), lambda n: arrows(n, [45]), forbidden, help_]
    for i, fn in enumerate(fns): sheet.alpha_composite(fn(64)[0], (i * 72 + 4, 8))
    for j, ph in enumerate((-90, 30)): sheet.alpha_composite(ring(64, ph)[0], ((len(names) + j) * 72 + 4, 8))
    sheet.alpha_composite(ring(64, 0, True)[0], ((len(names) + 2) * 72 + 4, 8))
    sheet.save(os.path.join(out, "preview.png"))

if __name__ == "__main__":
    build(sys.argv[1])
