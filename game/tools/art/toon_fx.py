# Hand-painted (cel-shaded) combat effects, drawn in code: hard colour bands, ragged flame edges, a soft glow.
#   python3 toon_fx.py <out_dir>
# Output: <out_dir>/<effect>/<n>.png  (RGBA, 150 px per metre like art/fx) and <out_dir>/sheet.png (all frames on grey).
# Effects: frost_blade (ice sword falls, crystals burst), tidal_slash (water crescent), arcane_ward (shield dome),
#          ember_blade (flame twists into a sword), ember_crash (floor breaks, fire bursts), fire_pillar.
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else 'toon_fx_out'
SS = 2                                    # supersampling for polygons


# ---------------------------------------------------------------- helpers
def fbm(w, h, seed, cells=(48, 24, 12, 6), weights=(0.5, 0.27, 0.15, 0.08)):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    for c, k in zip(cells, weights):
        g = rng.random((h // c + 3, w // c + 3)).astype(np.float32)
        img = Image.fromarray((g * 255).astype(np.uint8)).resize(((w // c + 3) * c, (h // c + 3) * c), Image.BICUBIC)
        out += np.asarray(img, dtype=float)[:h, :w] / 255.0 * k
    return out / sum(weights)


def cel(v, stops):
    """Hard colour bands: stops = [(threshold, (r, g, b, a)), ...] ascending; below the first threshold is clear."""
    h, w = v.shape
    out = np.zeros((h, w, 4))
    for t, col in stops:
        out[v >= t] = col
    return out


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA')


def glow(img, radius, colour, strength=1.0):
    """A soft halo of `colour` behind the bright parts of img."""
    a = np.asarray(img, dtype=float)[..., 3] / 255.0
    halo = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))
    ha = np.asarray(halo, dtype=float) / 255.0 * strength
    layer = np.zeros(a.shape + (4,))
    layer[..., :3] = colour
    layer[..., 3] = np.clip(ha * 255 * 0.8, 0, 255)
    base = to_img(layer)
    base.alpha_composite(img)
    return base


def canvas(w, h):
    return Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))


def down(img):
    return img.resize((img.width // SS, img.height // SS), Image.LANCZOS)


def poly(d, pts, fill, outline=None, width=0):
    p = [(x * SS, y * SS) for x, y in pts]
    if outline is not None and width:
        d.line(p + [p[0]], fill=outline, width=width * SS, joint='curve')
    d.polygon(p, fill=fill)


def faceted(d, pts, light, dark, edge, ridge=None, split=0.5):
    """A shard or blade: outlined, the left half light and the right half dark (cel shading)."""
    poly(d, pts, dark, edge, 3)
    n = len(pts)
    left = pts[: n // 2 + 1] if split == 0.5 else pts
    # light face: from the first point to the midpoint of the polygon's axis
    cx = sum(p[0] for p in pts) / n
    lit = [(min(x, cx + (x - cx) * 0.15), y) for x, y in pts]
    poly(d, lit, light)
    if ridge:
        top = min(pts, key=lambda p: p[1]); bottom = max(pts, key=lambda p: p[1])
        d.line([(top[0] * SS, top[1] * SS), (bottom[0] * SS, bottom[1] * SS)], fill=ridge, width=2 * SS)


def dots(d, rng, n, box, rmin, rmax, colour):
    for _ in range(n):
        x = rng.uniform(box[0], box[2]); y = rng.uniform(box[1], box[3]); r = rng.uniform(rmin, rmax)
        d.ellipse(((x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS), fill=colour)


def ease(t):
    return 1 - (1 - t) ** 2


FIRE = [(0.10, (120, 22, 8, 255)), (0.22, (215, 70, 15, 255)), (0.40, (250, 140, 25, 255)), (0.60, (255, 205, 60, 255)), (0.80, (255, 248, 190, 255))]
WATER = [(0.10, (18, 36, 120, 255)), (0.24, (30, 95, 220, 255)), (0.44, (70, 175, 255, 255)), (0.66, (170, 235, 255, 255)), (0.84, (245, 252, 255, 255))]


# ---------------------------------------------------------------- fire pillar
def fire_pillar():
    W, H = 300, 480
    # stretched tall, so the flame breaks into vertical licks instead of blobs
    noise = np.asarray(Image.fromarray((fbm(W, H, 7, cells=(30, 15, 8, 4)) * 255).astype(np.uint8)).resize((W, H * 3), Image.BICUBIC), dtype=float) / 255
    ash = np.asarray(Image.fromarray((fbm(W, H, 8, cells=(10, 5, 3, 2)) * 255).astype(np.uint8)).resize((W, H * 3), Image.BICUBIC), dtype=float) / 255
    heights = [0.25, 0.65, 1.0, 1.0, 0.95, 0.7, 0.35, 0.12]
    widths = [0.55, 0.85, 1.0, 1.0, 0.95, 0.8, 0.6, 0.45]
    frames = []
    ys, xs = np.mgrid[0:H, 0:W]
    for i, (hf, wf) in enumerate(zip(heights, widths)):
        n = noise[(H - i * 40) % (H * 2):(H - i * 40) % (H * 2) + H]      # the flame scrolls upward
        a = ash[(H - i * 40) % (H * 2):(H - i * 40) % (H * 2) + H]
        from_floor = (H - 20 - ys) / (H - 40)                     # 0 at the floor, 1 at the top
        half = 0.30 * W * wf * (1.0 + 0.25 * np.clip(0.15 - from_floor, 0, 1) * 6) * (0.92 + 0.16 * n)
        across = 1 - np.abs(xs - W / 2) / half
        top = np.clip((hf + (n - 0.5) * 0.35 - from_floor) / 0.08, 0, 1)        # ragged tongues along the top
        v = np.where(across > 0, across * 0.55 + (n - 0.5) * 0.9 + 0.32, across * 3 + (n - 0.5) * 0.6 + 0.2) * top
        v = np.where(from_floor < -0.02, 0, v)
        rgba = cel(v, FIRE)
        flecks = (a > 0.66) & (v > 0.35) & (v < 0.75)
        rgba[flecks] = (150, 50, 12, 255)
        img = to_img(rgba)
        big = img.resize((W * SS, H * SS), Image.NEAREST)
        d = ImageDraw.Draw(big)
        rng = np.random.default_rng(100 + i)
        if hf > 0.3:
            dots(d, rng, int(18 * hf), (W * 0.15, H * (1 - hf), W * 0.85, H - 30), 1.5, 4, (255, 170, 40, 255))
        dots(d, rng, 10, (W * 0.12, H - 45, W * 0.88, H - 18), 2, 5, (90, 40, 20, 255))   # cinders on the floor
        frames.append(glow(down(big), 10, (255, 110, 20), 0.9 * max(hf, 0.3)))
    return frames


# ---------------------------------------------------------------- tidal slash (water crescent)
def crescent_field(W, H, cx, cy, r, a0, a1, thick, noise, ragged=0.35):
    ys, xs = np.mgrid[0:H, 0:W]
    dx, dy = xs - cx, ys - cy
    ang = np.degrees(np.arctan2(dy, dx))
    rad = np.hypot(dx, dy)
    s = (ang - a0) / (a1 - a0)                                  # 0..1 along the arc
    inside = (s >= 0) & (s <= 1)
    prof = np.clip(np.sin(np.clip(s, 0, 1) * math.pi) ** 0.7, 0, 1)
    band = thick * prof
    depth = (r - rad) / np.maximum(band, 1e-3)                  # 0 on the outer edge, 1 on the inner edge
    v = np.where(inside & (depth >= 0) & (depth <= 1), 1 - np.abs(depth - 0.35) / 0.65, 0)
    in_band = inside & (depth >= -0.05) & (depth <= 1.05)
    v = v + (noise - 0.5) * ragged * in_band
    outer_tongues = inside & (depth < 0) & (depth > -0.7) & (noise > 0.5 - depth * 0.35)
    v = np.where(outer_tongues, 0.2 + (noise - 0.5) * 1.6, v)
    return np.clip(v * prof ** 0.3, 0, 1)


def tidal_slash():
    W, H = 340, 340
    noise = fbm(W, H, 21, cells=(24, 12, 6, 3))
    plan = [  # (arc start, arc end, thickness, break-up)
        (-130, -95, 40, 0.0), (-130, -40, 52, 0.0), (-128, 20, 60, 0.0), (-120, 70, 70, 0.0),
        (-110, 85, 72, 0.15), (-95, 90, 55, 0.35), (-80, 90, 38, 0.55),
    ]
    frames = []
    for i, (a0, a1, th, broken) in enumerate(plan):
        n = np.roll(noise, i * 9, axis=1)
        v = crescent_field(W, H, W * 0.42, H * 0.52, 130, a0, a1, th, n, ragged=0.6)
        if broken:
            v = np.where(n < 0.35 + broken * 0.5, v * 0.45, v)
        img = to_img(cel(v, WATER))
        big = img.resize((W * SS, H * SS), Image.NEAREST); d = ImageDraw.Draw(big)
        rng = np.random.default_rng(200 + i)
        for _ in range(6 if i > 1 else 0):                         # spray flicked off the outer edge
            a = math.radians(rng.uniform(a0, a1)); r = 130 + rng.uniform(6, 30)
            x, y = W * 0.42 + math.cos(a) * r, H * 0.52 + math.sin(a) * r
            poly(d, [(x, y), (x + math.cos(a + 1.6) * 3, y + math.sin(a + 1.6) * 3), (x + math.cos(a) * 14, y + math.sin(a) * 14)], (150, 225, 255, 255))
        frames.append(glow(down(big), 8, (40, 130, 255), 0.8))
    return frames


# ---------------------------------------------------------------- arcane ward (shield dome)
def arcane_ward():
    W, H = 440, 290
    cx, base_y, rx, ry = W / 2, H - 30, 190, 230
    ys, xs = np.mgrid[0:H, 0:W]
    frames = []
    for i in range(6):
        e = np.hypot((xs - cx) / rx, (ys - base_y) / ry)
        dome = (e <= 1) & (ys <= base_y)
        rim = np.clip((e - 0.55) / 0.45, 0, 1)
        arr = np.zeros((H, W, 4))
        arr[..., 0] = 110 + 110 * rim ** 2; arr[..., 1] = 30 + 60 * rim ** 3; arr[..., 2] = 150 + 90 * rim ** 2
        arr[..., 3] = np.where(dome, 55 + 150 * rim ** 3, 0)
        edge = dome & (e > 0.965)
        arr[edge] = (235, 170, 255, 235)
        img = to_img(arr)
        big = img.resize((W * SS, H * SS), Image.BILINEAR); d = ImageDraw.Draw(big)
        # swirling blades of light: crescents riding the dome, drawn as tapered polygons
        for k in range(3):
            phase = i / 6 * 2 * math.pi + k * 2.1
            pts_o, pts_i = [], []
            for j in range(17):
                s = j / 16
                a = phase + s * 1.5
                r_scale = 0.62 + 0.3 * math.sin(k + 1.3)
                x = cx + math.cos(a) * rx * r_scale
                y = base_y - 70 - math.sin(a) * ry * 0.22 - k * 34
                w = 11 * math.sin(s * math.pi) ** 0.8
                pts_o.append((x, y - w)); pts_i.append((x, y + w * 0.4))
            ring = pts_o + pts_i[::-1]
            poly(d, ring, (210, 70, 200, 255), (120, 20, 120, 255), 2)
            core = [(x, y + 2) for x, y in pts_o[3:-3]] + [(x, y - 1) for x, y in pts_i[3:-3][::-1]]
            poly(d, core, (255, 235, 255, 255))
        # ripples on the floor
        for k, (sx, alpha) in enumerate(((1.08, 200), (1.25, 120))):
            rr = rx * sx + (i % 3) * 4
            d.ellipse(((cx - rr) * SS, (base_y - 8 - k * 2) * SS, (cx + rr) * SS, (base_y + 8 + k * 2) * SS), outline=(225, 170, 255, alpha), width=2 * SS)
        rng = np.random.default_rng(300 + i)
        dots(d, rng, 8, (cx - rx, base_y - 6, cx + rx, base_y + 2), 1, 3, (255, 220, 255, 255))
        frames.append(glow(down(big), 6, (180, 60, 220), 0.5))
    return frames


# ---------------------------------------------------------------- swords (ice and fire)
def sword_points(cx, tip_y, length, width):
    """Blade, guard and grip of a sword pointing down, tip at (cx, tip_y)."""
    hilt_y = tip_y - length
    blade = [(cx, tip_y), (cx - width, tip_y - width * 2.2), (cx - width, hilt_y + 8), (cx + width, hilt_y + 8), (cx + width, tip_y - width * 2.2)]
    guard = [(cx - width * 3.4, hilt_y - 2), (cx - width * 1.2, hilt_y + 10), (cx + width * 1.2, hilt_y + 10), (cx + width * 3.4, hilt_y - 2),
             (cx + width * 1.6, hilt_y - 8), (cx - width * 1.6, hilt_y - 8)]
    grip = [(cx - width * 0.45, hilt_y - 8), (cx - width * 0.45, hilt_y - 36), (cx + width * 0.45, hilt_y - 36), (cx + width * 0.45, hilt_y - 8)]
    pommel = (cx, hilt_y - 42, width * 0.75)
    return blade, guard, grip, pommel


def draw_sword(d, cx, tip_y, length, width, light, dark, edge, gem):
    blade, guard, grip, (px, py, pr) = sword_points(cx, tip_y, length, width)
    faceted(d, blade, light, dark, edge, ridge=(255, 255, 255, 255))
    faceted(d, guard, light, dark, edge)
    poly(d, grip, dark, edge, 2)
    d.ellipse(((px - pr) * SS, (py - pr) * SS, (px + pr) * SS, (py + pr) * SS), fill=gem, outline=edge, width=2 * SS)


def frost_blade():
    W, H = 420, 470
    floor = H - 30
    ICE_L, ICE_D, ICE_E = (215, 240, 255, 255), (110, 165, 240, 255), (28, 40, 115, 255)
    frames = []
    shards = [(-150, 0.75, -20), (-95, 1.0, -12), (-45, 0.6, -6), (40, 0.65, 8), (95, 1.05, 14), (150, 0.8, 22)]
    for i in range(9):
        img = canvas(W, H); d = ImageDraw.Draw(img)
        drop = [0.0, 0.55, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0][i]
        grow = [0, 0, 0.35, 0.8, 1.0, 1.0, 0.8, 0.5, 0.2][i]
        fade = [1, 1, 1, 1, 1, 1, 0.85, 0.6, 0.3][i]
        # light rays up from the strike
        if grow:
            for k in range(7):
                x = W / 2 + (k - 3) * 26 + (i * 7 % 11) - 5
                hgt = (140 + (k * 37 % 60)) * grow
                d.rectangle(((x - 6) * SS, (floor - hgt) * SS, (x + 6) * SS, floor * SS), fill=(120, 170, 255, int(70 * fade)))
        tip = floor + 10 if drop == 1.0 else floor - 260 + 260 * drop
        if drop < 1.0:                                        # streaks behind the falling sword
            for k in range(5):
                x = W / 2 + (k - 2) * 10
                d.rectangle(((x - 2) * SS, (tip - 300) * SS, (x + 2) * SS, (tip - 150) * SS), fill=(170, 210, 255, 120))
        draw_sword(d, W / 2, tip, 250, 19, ICE_L, ICE_D, ICE_E, (120, 220, 255, 255))
        for ang, size, lean in shards:                        # crystals bursting out of the floor
            if not grow: break
            L = 150 * size * grow; w = 24 * size * max(grow, 0.4)
            bx = W / 2 + ang
            a = math.radians(lean * 2.2)
            tipx, tipy = bx + math.sin(a) * L, floor - math.cos(a) * L
            pts = [(bx - w, floor + 4), (bx - w * 0.9 + (tipx - bx) * 0.6, floor - L * 0.62), (tipx, tipy), (bx + w * 0.9 + (tipx - bx) * 0.6, floor - L * 0.62), (bx + w, floor + 4)]
            faceted(d, pts, ICE_L, ICE_D, ICE_E, ridge=(255, 255, 255, 255))
        if i == 2:                                            # the impact flash
            d.ellipse(((W / 2 - 70) * SS, (floor - 26) * SS, (W / 2 + 70) * SS, (floor + 14) * SS), fill=(230, 245, 255, 230))
        rng = np.random.default_rng(400 + i)
        if grow:
            dots(d, rng, 14, (W * 0.12, floor - 200 * grow, W * 0.88, floor), 1.5, 3.5, (220, 240, 255, 255))
        im = down(img)
        if fade < 1:
            a = np.asarray(im, dtype=float); a[..., 3] *= fade; im = to_img(a)
        frames.append(glow(im, 9, (70, 140, 255), 0.8))
    return frames


def ember_blade():
    W, H = 200, 330
    FL, FD, FE = (255, 215, 120, 255), (235, 110, 30, 255), (110, 25, 10, 255)
    frames = []
    for i in range(6):
        img = canvas(W, H); d = ImageDraw.Draw(img)
        helix = [1.0, 1.0, 0.8, 0.5, 0.2, 0.0][i]
        solid = [0.0, 0.0, 0.35, 0.7, 1.0, 1.0][i]
        if helix:
            for strand in (0, 1):
                pts_a, pts_b = [], []
                for j in range(40):
                    s = j / 39
                    y = 300 - s * 270
                    x = W / 2 + math.sin(s * 9 + strand * math.pi + i * 0.9) * (34 * (1 - s * 0.4)) * helix
                    w = 7 * math.sin(s * math.pi) ** 0.6 + 1
                    pts_a.append((x - w, y)); pts_b.append((x + w, y))
                poly(d, pts_a + pts_b[::-1], (240, 120, 30, int(255 * helix)), (120, 30, 10, int(255 * helix)), 2)
                core = [(x + 3, y) for x, y in pts_a[4:-4]] + [(x - 3, y) for x, y in pts_b[4:-4][::-1]]
                poly(d, core, (255, 230, 140, int(255 * helix)))
        if solid:
            tmp = canvas(W, H); dt = ImageDraw.Draw(tmp)
            draw_sword(dt, W / 2, 305, 215, 12, FL, FD, FE, (255, 80, 40, 255))
            # the sword points up: flip the drawing
            tmp = tmp.transpose(Image.FLIP_TOP_BOTTOM).transform(tmp.size, Image.AFFINE, (1, 0, 0, 0, 1, -(H * SS - 335 * SS) * 0), Image.BICUBIC)
            a = np.asarray(tmp, dtype=float); a[..., 3] *= solid
            img.alpha_composite(to_img(a))
        rng = np.random.default_rng(500 + i)
        dots(d, rng, 10, (W * 0.2, 20, W * 0.8, 310), 1.2, 3, (255, 190, 70, 255))
        frames.append(glow(down(img), 8, (255, 120, 30), 0.9))
    return frames


# ---------------------------------------------------------------- ember crash (floor breaks, fire bursts)
def ember_crash():
    W, H = 380, 320
    floor = H - 26
    ROCK_L, ROCK_D, ROCK_E = (170, 125, 85, 255), (105, 70, 45, 255), (40, 24, 18, 255)
    noise = fbm(W, H, 61, cells=(24, 12, 6, 3))
    rng0 = np.random.default_rng(600)
    rocks = [(rng0.uniform(-120, 120), rng0.uniform(14, 30), rng0.uniform(-0.5, 0.5)) for _ in range(9)]
    frames = []
    for i in range(6):
        burst = [1.0, 0.85, 0.55, 0.3, 0.1, 0.0][i]
        img = canvas(W, H); d = ImageDraw.Draw(img)
        # the fire swoosh: a crescent rising from the floor
        if burst:
            v = crescent_field(W, H, W * 0.5 + 190, floor + 10, 200, -178, -100, 70 * (0.6 + 0.4 * burst), np.roll(noise, i * 11, axis=0), 0.5)
            v *= burst ** 0.5
            fire = to_img(cel(v, FIRE)).resize((W * SS, H * SS), Image.NEAREST)
            img.alpha_composite(fire)
        # flames along the crack
        fl = fbm(W, 120, 62 + i, cells=(16, 8, 4, 2))
        ys, xs = np.mgrid[0:120, 0:W]
        height = 1 - ys / 120
        across = 1 - np.abs(xs - W / 2) / (150 - i * 8)
        v = (across * 0.6 + (fl - 0.5) * 1.2 + 0.25 - height * (1.1 - burst * 0.3)) * (ys < 118)
        base = np.zeros((H, W)); base[floor - 118:floor + 2] = v[:120]
        img.alpha_composite(to_img(cel(base, FIRE)).resize((W * SS, H * SS), Image.NEAREST))
        # rocks: heaved up at first, settling after
        for k, (dx, size, tilt) in enumerate(rocks):
            lift = [26, 38, 20, 6, 0, 0][i] * (0.4 + (k % 3) * 0.3)
            x = W / 2 + dx; y = floor - size * 0.4 - lift
            pts = [(x + math.cos(t + tilt) * size * (0.75 + 0.35 * ((k + j) % 3) / 2), y + math.sin(t + tilt) * size * 0.6) for j, t in enumerate(np.linspace(0, 2 * math.pi, 7)[:-1])]
            poly(d, pts, ROCK_D, ROCK_E, 2)
            poly(d, [(px, py) for px, py in pts if py <= y + 2] + [(x, y)], ROCK_L)
        rng = np.random.default_rng(650 + i)
        dots(d, rng, int(16 * burst) + 3, (W * 0.15, floor - 180 * max(burst, 0.2), W * 0.85, floor - 10), 1.5, 4, (255, 180, 60, 255))
        dots(d, rng, int(10 * burst), (W * 0.2, floor - 120, W * 0.8, floor - 20), 2, 5, (90, 60, 40, 255))   # flying grit
        frames.append(glow(down(img), 8, (255, 110, 20), 0.6 + 0.4 * burst))
    return frames


EFFECTS = {
    'frost_blade': frost_blade, 'tidal_slash': tidal_slash, 'arcane_ward': arcane_ward,
    'ember_blade': ember_blade, 'ember_crash': ember_crash, 'fire_pillar': fire_pillar,
}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for name, fn in EFFECTS.items():
        frames = fn()
        d = os.path.join(OUT, name); os.makedirs(d, exist_ok=True)
        for i, f in enumerate(frames):
            f.save(os.path.join(d, f'{i}.png'))
        rows.append((name, frames))
        print('done', name, len(frames))
    cell = 170
    sheet = Image.new('RGBA', (cell * 9, cell * len(rows)), (71, 71, 71, 255))
    for r, (name, frames) in enumerate(rows):
        for c, f in enumerate(frames):
            t = f.copy(); t.thumbnail((cell - 6, cell - 6))
            sheet.alpha_composite(t, (c * cell + (cell - t.width) // 2, r * cell + (cell - t.height) // 2))
    sheet.convert('RGB').save(os.path.join(OUT, 'sheet.png'))
