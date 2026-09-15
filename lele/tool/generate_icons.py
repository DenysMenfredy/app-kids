"""Generates every launcher and store icon from store/app-icon-master.png.

Run from the lele/ directory after replacing the master artwork:

    python3 tool/generate_icons.py

The master is a pre-rounded squircle sitting on black. Neither store wants
that: iOS applies its own mask and rejects an alpha channel outright, and
Android masks adaptive icons to whatever shape the OEM uses. So the artwork
is lifted off its background once, and each platform is then given the shape
it actually expects.
"""

import json
import os
import statistics

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'store/app-icon-master.png')
KEY = (255, 0, 255)


def load():
    """Returns the artwork and a mask of everything that is background.

    Flood-filling inward from the edges only selects background that is
    connected to the outside, so the bear's dark eyes and outlines survive —
    a plain colour key would eat them.
    """
    im = Image.open(SRC).convert('RGB')
    w, h = im.size
    work = im.copy()
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for y in range(60, h - 60, 40):
        seeds += [(30, y), (w - 30, y)]
    for x in range(60, w - 60, 40):
        seeds += [(x, 30), (x, h - 30)]
    for seed in seeds:
        if work.getpixel(seed) != KEY:
            ImageDraw.floodfill(work, seed, KEY, thresh=32)

    bgmask = Image.new('L', (w, h), 0)
    wp, bp = work.load(), bgmask.load()
    for y in range(h):
        for x in range(w):
            if wp[x, y] == KEY:
                bp[x, y] = 255

    # The squircle's inner edge shading survives the fill as a faint ring.
    # Content sits well inside, so clear everything outside an inset rounded
    # rect rather than raising the threshold into the artwork.
    inset = int(w * 0.055)
    ring = Image.new('L', (w, h), 255)
    ImageDraw.Draw(ring).rounded_rectangle(
        [inset, inset, w - 1 - inset, h - 1 - inset],
        radius=int(w * 0.22), fill=0)
    bgmask.paste(255, (0, 0), ring)
    return im, bgmask


def row_gradient(im, bgmask):
    """Median background colour per row: the true gradient, content-free.

    The background is a vignette rather than a flat colour, so rebuilding it
    from the background pixels themselves is what keeps the adaptive icon's
    foreground from showing a seam against its background layer.
    """
    w, h = im.size
    ip, bp = im.load(), bgmask.load()
    rows = {}
    for y in range(h):
        cols = [ip[x, y] for x in range(w)
                if bp[x, y] == 255 and sum(ip[x, y]) > 90]
        if len(cols) >= 20:
            rows[y] = tuple(
                int(statistics.median([c[i] for c in cols])) for i in range(3))
    ys = sorted(rows)
    smoothed = {}
    for i, y in enumerate(ys):
        win = [rows[k] for k in ys[max(0, i - 12):i + 13]]
        smoothed[y] = tuple(
            int(sum(c[j] for c in win) / len(win)) for j in range(3))
    return ys, smoothed


def gradient_image(ys, sm, size, art_box):
    """The gradient across `size` px, aligned so the artwork's own gradient
    continues into the area around it without a visible edge."""
    ctop, cbot = sm[ys[0]], sm[ys[-1]]
    img = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(img)
    y0, y1 = art_box
    for y in range(size):
        t = (y - y0) / max(1, (y1 - y0))
        draw.line([(0, y), (size, y)], fill=tuple(
            max(0, min(255, int(ctop[i] + (cbot[i] - ctop[i]) * t)))
            for i in range(3)))
    return img


def main():
    im, bgmask = load()
    content = im.copy()
    content.putalpha(Image.eval(bgmask, lambda v: 255 - v))
    ys, sm = row_gradient(im, bgmask)

    def flat(size):
        """Full-bleed square: no alpha, no corners. Both stores mask it."""
        bg = gradient_image(ys, sm, size, (0, size)).convert('RGBA')
        bg.alpha_composite(content.resize((size, size), Image.LANCZOS))
        return bg

    def shaped(size, radius_ratio):
        src = flat(size)
        mask = Image.new('L', (size, size), 0)
        draw = ImageDraw.Draw(mask)
        if radius_ratio >= 0.5:
            draw.ellipse([0, 0, size - 1, size - 1], fill=255)
        else:
            draw.rounded_rectangle([0, 0, size - 1, size - 1],
                                   radius=int(size * radius_ratio), fill=255)
        out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        out.paste(src, (0, 0), mask)
        return out

    def foreground(canvas):
        """Artwork inside the 66dp safe circle, so no OEM mask can clip the
        wordmark. 264/432 is that circle expressed on the 108dp canvas."""
        art = round(canvas * 264 / 432)
        off = (canvas - art) // 2
        out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
        out.alpha_composite(content.resize((art, art), Image.LANCZOS), (off, off))
        return out

    def background(canvas):
        art = round(canvas * 264 / 432)
        off = (canvas - art) // 2
        return gradient_image(ys, sm, canvas, (off, off + art)).convert('RGB')

    written = []

    def save(img, path, rgb=False):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if rgb:
            flatten = Image.new('RGB', img.size, (255, 255, 255))
            rgba = img.convert('RGBA')
            flatten.paste(rgba, (0, 0), rgba)
            img = flatten
        img.save(path, 'PNG', optimize=True)
        written.append(path)

    # Android ------------------------------------------------------------
    res = os.path.join(ROOT, 'android/app/src/main/res')
    for dens, scale in {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2,
                        'xxhdpi': 3, 'xxxhdpi': 4}.items():
        legacy = round(48 * scale)
        adaptive = round(108 * scale)
        save(shaped(legacy, 0.225), '%s/mipmap-%s/ic_launcher.png' % (res, dens))
        save(shaped(legacy, 0.5), '%s/mipmap-%s/ic_launcher_round.png' % (res, dens))
        save(foreground(adaptive), '%s/mipmap-%s/ic_launcher_foreground.png' % (res, dens))
        save(background(adaptive), '%s/mipmap-%s/ic_launcher_background.png' % (res, dens))

    for name in ('ic_launcher', 'ic_launcher_round'):
        path = '%s/mipmap-anydpi-v26/%s.xml' % (res, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as handle:
            handle.write(
                '<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
                '</adaptive-icon>\n')
        written.append(path)

    # iOS ----------------------------------------------------------------
    ios = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
    with open(os.path.join(ios, 'Contents.json')) as handle:
        spec = json.load(handle)
    seen = set()
    for entry in spec['images']:
        name = entry['filename']
        if name in seen:
            continue
        seen.add(name)
        px = round(float(entry['size'].split('x')[0])
                   * int(entry['scale'].rstrip('x')))
        # The App Store rejects any alpha channel, so these are flattened.
        save(flat(px), os.path.join(ios, name), rgb=True)

    # web ----------------------------------------------------------------
    web = os.path.join(ROOT, 'web')
    save(shaped(192, 0.225), os.path.join(web, 'icons/Icon-192.png'))
    save(shaped(512, 0.225), os.path.join(web, 'icons/Icon-512.png'))
    save(shaped(64, 0.225), os.path.join(web, 'favicon.png'))
    for px in (192, 512):
        # Maskable icons obey the same safe zone: a browser may crop to a
        # circle, which would take the wordmark off a full-bleed icon.
        canvas = background(px).convert('RGBA')
        canvas.alpha_composite(foreground(px))
        save(canvas, os.path.join(web, 'icons/Icon-maskable-%d.png' % px), rgb=True)

    # store listings -----------------------------------------------------
    store = os.path.join(ROOT, 'store')
    save(flat(512), os.path.join(store, 'play-store-icon-512.png'), rgb=True)
    save(flat(1024), os.path.join(store, 'app-store-icon-1024.png'), rgb=True)

    print('wrote %d files' % len(written))


if __name__ == '__main__':
    main()
