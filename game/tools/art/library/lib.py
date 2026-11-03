# Shared helpers for the art library builders (game/tools/art/library/build_*.py).
# Everything here only reads downloaded images and writes PNG / JSON; nothing in a download is ever executed.
# Run the builders with `python3 -I` (isolated mode) so a planted module in a download folder can never be imported.
import json, os, shutil
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
LIB = os.path.join(GAME, 'art', 'library')
OUTLINE = (10, 6, 16, 255)


def out_dir(*parts, clean=True):
    d = os.path.join(LIB, *parts)
    if clean and os.path.isdir(d):
        keep = os.path.join(d, 'source')
        for n in os.listdir(d):
            p = os.path.join(d, n)
            if p == keep: continue
            shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    os.makedirs(d, exist_ok=True)
    return d


def keep_source(dst_dir, *paths, rename=None):
    """Copy original files (already licence-checked) into <dst_dir>/source/."""
    s = os.path.join(dst_dir, 'source'); os.makedirs(s, exist_ok=True)
    for i, p in enumerate(paths):
        name = rename[i] if rename else os.path.basename(p)
        shutil.copyfile(p, os.path.join(s, name))


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def rgba(path):
    im = Image.open(path); im.seek(0)
    return im.convert('RGBA')


# ------------------------------------------------------------------ slicing

def strip(img, n=None, fw=None, fh=None):
    """Horizontal strip -> frames (give n frames or a frame width)."""
    fh = fh or img.height
    fw = fw or img.width // n
    n = n or img.width // fw
    return [img.crop((i * fw, 0, (i + 1) * fw, fh)) for i in range(n)]


def grid(img, fw, fh, count=None, cols=None):
    cols = cols or img.width // fw
    rows = img.height // fh
    out = []
    for r in range(rows):
        for c in range(cols):
            if count is not None and len(out) >= count: return out
            out.append(img.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh)))
    return out


def drop_empty(frames):
    return [f for f in frames if f.getchannel('A').getbbox()]


# ------------------------------------------------------------------ framing

def union_bbox(frames):
    box = None
    for f in frames:
        b = f.getchannel('A').getbbox()
        if not b: continue
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return box


def round_up(v, m):
    return (v + m - 1) // m * m


def fit_canvas(anims, pad=2, mult=8, feet_x=None):
    """anims: {name: [frames]} all the same source size. Crops every frame to the union of all visible pixels (+pad),
    then grows the canvas to a multiple of `mult` keeping the feet on the bottom row.
    feet_x: if given (0..1), the horizontal centre of the idle pose is put at that fraction of the width.
    Returns (anims, (w, h), anchor) where anchor = feet point (x, y) in the new canvas."""
    allf = [f for fl in anims.values() for f in fl]
    x0, y0, x1, y1 = union_bbox(allf)
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad); x1 = min(allf[0].width, x1 + pad); y1 = y1  # feet stay on the bottom row
    w, h = x1 - x0, y1 - y0
    W, Hh = round_up(w, mult), round_up(h, mult)
    ox, oy = (W - w) // 2, Hh - h
    out = {}
    for k, fl in anims.items():
        out[k] = []
        for f in fl:
            c = Image.new('RGBA', (W, Hh)); c.alpha_composite(f.crop((x0, y0, x1, y1)), (ox, oy)); out[k].append(c)
    # feet: centre of the lowest opaque row of the first idle-ish frame
    first = next(iter(out.values()))[0]
    a = first.getchannel('A'); px = a.load(); feet = (W // 2, Hh - 1)
    for y in range(Hh - 1, -1, -1):
        xs = [x for x in range(W) if px[x, y] > 0]
        if xs: feet = ((xs[0] + xs[-1]) // 2, y); break
    return out, (W, Hh), feet


def scale_frames(frames, s, resample=Image.BOX):
    return [f.resize((max(1, round(f.width * s)), max(1, round(f.height * s))), resample) for f in frames]


def crisp_alpha(img, cut=96):
    a = img.getchannel('A').point(lambda v: 255 if v > cut else 0)
    img = img.copy(); img.putalpha(a); return img


def outline(img, colour=OUTLINE):
    w, h = img.size; src = img.load(); out = img.copy(); dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    X, Y = x + dx, y + dy
                    if 0 <= X < w and 0 <= Y < h and src[X, Y][3] == 255:
                        dst[x, y] = colour; break
    return out


def quantize_set(frames, colours=32):
    """One shared palette for a set of RGBA frames (hard alpha)."""
    pixels = []
    for f in frames:
        for p in f.getdata():
            if p[3]: pixels.append(p[:3])
    if not pixels: return frames
    strip_ = Image.new('RGB', (len(pixels), 1)); strip_.putdata(pixels)
    pal = strip_.quantize(colors=colours, method=Image.MEDIANCUT, dither=Image.NONE)
    out = []
    for f in frames:
        q = f.convert('RGB').quantize(palette=pal, dither=Image.NONE).convert('RGBA')
        q.putalpha(f.getchannel('A')); out.append(q)
    return out


# ------------------------------------------------------------------ colour grading

def ashen(img, sat=0.55, val=0.9, warm=0.10, cool=0.12):
    """Souls-style grade: desaturate, darken a touch, cool the shadows (blue-violet) and warm the highlights (ember)."""
    r, g, b, a = img.split()
    px = []
    for R, G, B in zip(r.getdata(), g.getdata(), b.getdata()):
        L = 0.299 * R + 0.587 * G + 0.114 * B
        R = L + (R - L) * sat; G = L + (G - L) * sat; B = L + (B - L) * sat
        t = L / 255.0
        R = R * val + (warm * 60 * t * t) - cool * 18 * (1 - t)
        G = G * val + (warm * 25 * t * t) - cool * 12 * (1 - t)
        B = B * val - (warm * 20 * t * t) + cool * 22 * (1 - t)
        px.append((max(0, min(255, int(R))), max(0, min(255, int(G))), max(0, min(255, int(B)))))
    out = Image.new('RGB', img.size); out.putdata(px)
    out = out.convert('RGBA'); out.putalpha(a)
    return out


# ------------------------------------------------------------------ previews + metadata

def _font():
    try:
        return ImageFont.load_default()
    except Exception:
        return None


def contact_sheet(rows, path, zoom=2, bg=(34, 30, 42, 255), max_cols=12, max_rows=3):
    """rows: [(label, [frames])] -> one PNG, every row its own line(s), nearest-neighbour zoom."""
    font = _font()
    cells = []
    for label, frames in rows:
        frames = frames[:max_cols * max_rows]
        if not frames: continue
        fw = max(f.width for f in frames); fh = max(f.height for f in frames)
        cells.append((label, frames, fw, fh))
    if not cells: return
    W = max(min(len(fr), max_cols) * (fw + 2) for _, fr, fw, fh in cells) + 4
    W = max(W, 160)
    H = sum(12 + ((len(fr) + max_cols - 1) // max_cols) * (fh + 2) for _, fr, fw, fh in cells) + 4
    sheet = Image.new('RGBA', (W, H), bg); d = ImageDraw.Draw(sheet); y = 2
    for label, frames, fw, fh in cells:
        d.text((2, y), label, fill=(235, 215, 150, 255), font=font); y += 12
        for i, f in enumerate(frames):
            cx = 2 + (i % max_cols) * (fw + 2); cy = y + (i // max_cols) * (fh + 2)
            d.rectangle((cx, cy, cx + fw - 1, cy + fh - 1), fill=(46, 42, 56, 255))
            sheet.alpha_composite(f, (cx + (fw - f.width) // 2, cy + fh - f.height))
        y += ((len(frames) + max_cols - 1) // max_cols) * (fh + 2)
    if zoom != 1:
        sheet = sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST)
    save(sheet, path)


def write_frames(d, anims, prefix_style='anim_n'):
    """anims {Anim: [frames]} -> <d>/<Anim>_<n>.png (the same naming as game/art/enemies)."""
    counts = {}
    for k, fl in anims.items():
        for i, f in enumerate(fl):
            save(f, os.path.join(d, f'{k}_{i}.png'))
        counts[k] = len(fl)
    return counts


def write_meta(d, **meta):
    with open(os.path.join(d, 'meta.json'), 'w') as fh:
        json.dump(meta, fh, indent=1)
