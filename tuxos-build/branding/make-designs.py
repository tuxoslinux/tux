#!/usr/bin/env python3
"""TuxOS artwork that needs more than ImageMagick (run by make-assets.sh).

    make-designs.py TUX_PNG ASCII_TXT OUTDIR

Writes, under OUTDIR:
  desktop/tuxos-wallpaper.jpg       "Corner glow" wallpaper (3840x2160)
  grub-live/background.png          "Terminal" GRUB background, live ISO
  grub-installed/background.png     the same for the installed system
  grub-*/highlight_[cwe].png ...    GRUB menu pixmaps
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

TUX_SRC, ASCII, OUT = sys.argv[1:4]
NOTO = '/usr/share/fonts/noto/'
F_BLACK = NOTO + 'NotoSans-Black.ttf'
F_MONO = NOTO + 'NotoSansMono-Regular.ttf'

ACCENT = (245, 184, 0)
WHITE = (244, 246, 248)
ASCII_WHITE = (205, 205, 205)
ASCII_YELLOW = (214, 200, 40)


def tux(height):
    """Tux scaled to a height, with a thin dark-grey rim so he shows on black."""
    src = Image.open(TUX_SRC).convert('RGBA')
    w = round(src.width * height / src.height)
    t = src.resize((w, height), Image.LANCZOS)
    pad = max(4, height // 60)
    canvas = Image.new('RGBA', (w + 2 * pad, height + 2 * pad), (0, 0, 0, 0))
    canvas.paste(t, (pad, pad), t)
    alpha = canvas.getchannel('A').filter(ImageFilter.MaxFilter(2 * (pad // 2) + 1)).filter(
        ImageFilter.GaussianBlur(max(1, height / 400)))
    rim = Image.new('RGBA', canvas.size, (58, 58, 58, 255))
    rim.putalpha(alpha)
    return Image.alpha_composite(rim, canvas)


def wordmark(size):
    """"Tux" in white, "OS" in the accent yellow."""
    f = ImageFont.truetype(F_BLACK, size)
    w1 = f.getlength('Tux')
    asc, desc = f.getmetrics()
    img = Image.new('RGBA', (int(w1 + f.getlength('OS')) + 4, asc + desc), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((0, 0), 'Tux', font=f, fill=WHITE)
    d.text((w1, 0), 'OS', font=f, fill=ACCENT)
    return img.crop(img.getbbox())


def ascii_tux(size):
    """The fastfetch ASCII Tux ($1 white body, $2 yellow feet) as an image."""
    lines = open(ASCII).read().rstrip('\n').split('\n')
    f = ImageFont.truetype(F_MONO, size)
    cw = f.getlength('8')
    lh = round(size * 1.25)
    width = max(len(re.sub(r'\$[12]', '', l)) for l in lines)
    img = Image.new('RGBA', (int(cw * width) + 4, lh * len(lines) + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    colors = {'1': ASCII_WHITE, '2': ASCII_YELLOW}
    for y, line in enumerate(lines):
        x, c = 0, '1'
        for part in re.split(r'(\$[12])', line):
            if part in ('$1', '$2'):
                c = part[1]
                continue
            d.text((x * cw, y * lh), part, font=f, fill=colors[c])
            x += len(part)
    return img


def radial_glow(w, h, cx, cy, radius, strength):
    """Soft round yellow light centred on (cx, cy)."""
    small = Image.new('L', (w // 8, h // 8), 0)
    r = radius / 8
    ImageDraw.Draw(small).ellipse((cx / 8 - r, cy / 8 - r, cx / 8 + r, cy / 8 + r),
                                  fill=int(255 * strength))
    mask = small.filter(ImageFilter.GaussianBlur(r / 2.2)).resize((w, h), Image.BICUBIC)
    layer = Image.new('RGBA', (w, h), ACCENT + (0,))
    layer.putalpha(mask)
    return layer


def wallpaper(path):
    """Corner glow: Tux and the wordmark lower right in a soft yellow light.

    The group sits 680 px from the right and 450 px from the bottom (of
    3840x2160): at least 50 px clear of a bottom panel up to 60 px tall and
    of the edge when 4:3, 5:4 or 21:9 screens crop the picture.
    """
    W, H = 3840, 2160
    right, bottom = 680, 450
    img = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    t = tux(470)
    m = wordmark(120)
    group_w = max(t.width, m.width)
    gx = W - right - group_w
    mark_y = H - bottom - m.height
    tux_y = mark_y - 70 - t.height
    img.alpha_composite(radial_glow(W, H, gx + group_w / 2, tux_y + t.height * 0.55, 1500, 0.16))
    img.alpha_composite(t, (int(gx + (group_w - t.width) / 2), int(tux_y)))
    img.alpha_composite(m, (int(gx + (group_w - m.width) / 2), int(mark_y)))
    img.convert('RGB').save(path, quality=92)


def grub_background(path, prompt_host):
    """Terminal: a shell prompt on top, the ASCII Tux on the right."""
    W, H = 1024, 768
    img = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(F_MONO, 18)
    prompt = f'tuxos@{prompt_host}:~$ '
    d.text((48, 40), prompt, font=f, fill=ACCENT)
    d.text((48 + f.getlength(prompt), 40), 'ls /boot/menu', font=f, fill=WHITE)
    d.line((48, 80, 560, 80), fill=(40, 40, 40), width=1)
    a = ascii_tux(14)
    img.alpha_composite(a, (int(W - a.width - 30), int((H - a.height) / 2 + 10)))
    # GRUB decodes only 8-bit RGB(A) PNGs
    img.convert('RGB').save(path)


def grub_pixmaps(d):
    """Square yellow selection bar (reverse video), dark scrollbar."""
    for k, w in (('c', 1), ('w', 4), ('e', 4)):
        Image.new('RGBA', (w, 28), ACCENT + (255,)).save(f'{d}/highlight_{k}.png')
    Image.new('RGBA', (1, 1), (0, 0, 0, 0)).save(f'{d}/menu_c.png')
    Image.new('RGBA', (16, 1), (0, 0, 0, 0)).save(f'{d}/menu_e.png')
    s = (51, 51, 51, 255)
    Image.new('RGBA', (32, 1), s).save(f'{d}/slider_c.png')
    n = Image.new('RGBA', (32, 16), (0, 0, 0, 0))
    ImageDraw.Draw(n).rounded_rectangle((8, 0, 23, 31), 6, fill=s)
    n.save(f'{d}/slider_n.png')
    so = Image.new('RGBA', (32, 16), (0, 0, 0, 0))
    ImageDraw.Draw(so).rounded_rectangle((8, -16, 23, 15), 6, fill=s)
    so.save(f'{d}/slider_s.png')


if __name__ == '__main__':
    for sub in ('desktop', 'grub-live', 'grub-installed'):
        os.makedirs(f'{OUT}/{sub}', exist_ok=True)
    wallpaper(f'{OUT}/desktop/tuxos-wallpaper.jpg')
    grub_background(f'{OUT}/grub-live/background.png', 'live')
    grub_background(f'{OUT}/grub-installed/background.png', 'boot')
    grub_pixmaps(f'{OUT}/grub-live')
    grub_pixmaps(f'{OUT}/grub-installed')
