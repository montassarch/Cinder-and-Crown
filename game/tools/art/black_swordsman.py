# Builds the black swordsman art from the Hero Knight source frames:
#   1. recolors the blue-steel armor to near-black plate with bright edge highlights;
#   2. bakes a black plague-style mask with glowing red eyes into a second copy of every frame.
# Source:  game/tools/art/source/hero_knight/<Anim>/HeroKnight_<Anim>_<n>.png  (Sven Thole, see CREDITS)
# Output:  game/art/black_swordsman/{plain,masked}/<Anim>/HeroKnight_<Anim>_<n>.png
#   python3 game/tools/art/black_swordsman.py [--preview out.png]
from PIL import Image
import colorsys, glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'source', 'hero_knight')
OUT = os.path.join(HERE, '..', '..', 'art', 'black_swordsman')
ANIMS = ['Idle', 'Run', 'Jump', 'Fall', 'Roll', 'Attack1', 'Attack2', 'Attack3', 'Hurt', 'Death']

INK = (8, 8, 12)
ARMOR_RAMP = [(0.0, (6, 6, 10)), (0.30, (14, 14, 22)), (0.55, (34, 34, 48)), (0.80, (88, 90, 112)), (1.0, (176, 180, 204))]
EYE = (255, 40, 30)
EYE_CORE = (255, 190, 150)
MASK_BASE = (16, 15, 20)
MASK_LIGHT = (46, 44, 56)


def ramp(v):
    for (a, ca), (b, cb) in zip(ARMOR_RAMP, ARMOR_RAMP[1:]):
        if v <= b:
            t = (v - a) / (b - a)
            return tuple(int(ca[i] + (cb[i] - ca[i]) * t) for i in range(3))
    return ARMOR_RAMP[-1][1]


def is_skin(h, s, v):
    return 0.03 <= h <= 0.11 and 0.18 <= s <= 0.55 and v >= 0.7


def recolor_pixel(p):
    r, g, b, a = p
    if a == 0:
        return p
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if v >= 0.93 and s < 0.15:                       # smear arcs and blade glints stay bright
        return p
    if is_skin(h, s, v):                             # face and hands
        return p
    if (h < 0.04 or h > 0.93) and s > 0.7:           # scarf stays red, a touch deeper
        return (int(r * 0.9), int(g * 0.8), int(b * 0.8), a)
    if 0.09 <= h <= 0.16 and s > 0.7 and v > 0.7:    # gold trim stays
        return p
    if 0.03 <= h <= 0.12 and s > 0.4:                # brown leather and boots go charcoal
        nr, ng, nb = (int(c * 0.45) for c in (r, g, b))
        return (nr, ng, nb, a)
    # everything left is steel or blue plate (and the blade's shaded side): contrast ramp on lightness
    lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255
    return ramp(min(1.0, lum * 1.15)) + (a,)


def recolor(im):
    out = im.copy()
    px = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            px[x, y] = recolor_pixel(px[x, y])
    return out


def face_box(im):
    px = im.load()
    xs, ys = [], []
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a > 200 and is_skin(*colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)):
                xs.append(x); ys.append(y)
    if not xs:
        return None
    # the face is the topmost skin cluster (hands are lower); keep rows within 9px of the top
    top = min(ys)
    pts = [(x, y) for x, y in zip(xs, ys) if y <= top + 8]
    return (min(p[0] for p in pts), top, max(p[0] for p in pts), max(p[1] for p in pts))


def add_mask(im):
    """Plague-style mask: rounded hood, a long tapering beak, a glowing red eye."""
    box = face_box(im)
    if box is None:
        return im
    x0, y0, x1, y1 = box
    y1 = min(y1, y0 + 7)
    out = im.copy()
    px = out.load()
    W, H = out.size

    def put(x, y, c, a=255):
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = tuple(c) + (a,)

    # hood: rounded crown above the face, drape behind the head down to the neck
    for dy, (left, right) in enumerate(((x0 + 1, x1 - 1), (x0, x1), (x0 - 1, x1 + 1), (x0 - 2, x1 + 1))):
        for x in range(left, right + 1):
            put(x, y0 - 3 + dy, MASK_BASE)
    for y in range(y0, y1 + 2):
        for x in range(x0 - 2, x1 + 2):
            put(x, y, MASK_BASE)
    for y in range(y0 + 1, y1 + 3):                      # drape behind the neck
        put(x0 - 3, y, MASK_BASE)
    # lit rim along the crown and the back of the hood so the black still reads
    for x in range(x0 + 1, x1):
        put(x, y0 - 3, MASK_LIGHT)
    for y in range(y0 - 1, y1):
        put(x0 - 2, y, MASK_LIGHT)
    # beak: starts under the eye, tapers forward and curves down at the tip
    by = y0 + 3
    for k in range(1, 8):
        put(x1 + k, by, MASK_BASE)
    for k in range(1, 6):
        put(x1 + k, by + 1, MASK_BASE)
    for k in range(1, 4):
        put(x1 + k, by + 2, MASK_BASE)
    put(x1 + 7, by + 1, MASK_BASE)
    for k in range(2, 7):
        put(x1 + k, by, MASK_LIGHT)                       # lit top edge of the beak
    # glowing red eye lens set high on the mask, with a faint halo on the hood
    ex, ey = x1 - 1, y0 + 1
    for dx, dy in ((-1, -1), (2, -1), (-1, 2), (2, 2)):
        put(ex + dx, ey + dy, EYE, 90)
    for dx in (0, 1):
        for dy in (0, 1):
            put(ex + dx, ey + dy, EYE)
    put(ex + 1, ey, EYE_CORE)
    return out


def main():
    plain_dir = os.path.join(OUT, 'plain')
    masked_dir = os.path.join(OUT, 'masked')
    preview = []
    for anim in ANIMS:
        files = sorted(glob.glob(os.path.join(SRC, anim, '*.png')), key=lambda f: int(re.findall(r'_(\d+)\.png', f)[0]))
        for kind, d in (('plain', plain_dir), ('masked', masked_dir)):
            os.makedirs(os.path.join(d, anim), exist_ok=True)
        for f in files:
            name = os.path.basename(f)
            base = recolor(Image.open(f).convert('RGBA'))
            base.save(os.path.join(plain_dir, anim, name))
            masked = add_mask(base)
            masked.save(os.path.join(masked_dir, anim, name))
            if name.endswith('_0.png') or (anim in ('Run', 'Attack1') and name.endswith(('_3.png', '_4.png'))):
                preview.append((anim, Image.open(f).convert('RGBA'), base, masked))
    if '--preview' in sys.argv:
        out = sys.argv[sys.argv.index('--preview') + 1]
        cell = (100, 55)
        sheet = Image.new('RGBA', (cell[0] * 3, cell[1] * len(preview)), (40, 12, 16, 255))
        for r, (_, o, p, m) in enumerate(preview):
            for c, im in enumerate((o, p, m)):
                sheet.alpha_composite(im, (c * cell[0], r * cell[1]))
        sheet.resize((sheet.size[0] * 3, sheet.size[1] * 3), Image.NEAREST).save(out)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
