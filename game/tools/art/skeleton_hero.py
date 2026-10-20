# Draws the hooded skeleton knight concept sheet in code (no source art, no AI image model).
#   python3 game/tools/art/skeleton_hero.py [--scale 4]
# Output: game/art/skeleton_hero/sheet.png (native pixels), sheet_preview.png (scaled),
#         and one PNG per pose under game/art/skeleton_hero/frames/.
# Side poses face right. Everything is drawn from palette colours and polygons, then an
# automatic pass adds the dark outline and the light/shade edges.
from PIL import Image, ImageDraw
import math, os, random, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'art', 'skeleton_hero')

OUTLINE = (12, 8, 18)
CAPE = (62, 42, 92)
CAPE_DARK = (40, 26, 62)
ARMOR = (44, 40, 58)
ARMOR_LIGHT = (74, 66, 96)
TRIM = (140, 38, 52)
BONE = (206, 202, 196)
BONE_DARK = (140, 136, 142)
SOCKET = (20, 14, 26)
RED = (232, 44, 52)
RED_HOT = (255, 150, 120)
STEEL = (120, 120, 134)
LEATHER = (30, 26, 40)


class Sprite:
    def __init__(self, w=64, h=64):
        self.img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def poly(self, pts, c):
        self.d.polygon([(round(x), round(y)) for x, y in pts], fill=c)

    def limb(self, a, b, w, c):
        (x0, y0), (x1, y1) = a, b
        dx, dy = x1 - x0, y1 - y0
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n * w / 2, dx / n * w / 2
        self.poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], c)
        self.d.ellipse([round(x1 - w / 2), round(y1 - w / 2), round(x1 + w / 2 - 1), round(y1 + w / 2 - 1)], fill=c)

    def rect(self, x0, y0, x1, y1, c):
        self.d.rectangle([round(x0), round(y0), round(x1), round(y1)], fill=c)

    def ellipse(self, x0, y0, x1, y1, c):
        self.d.ellipse([round(x0), round(y0), round(x1), round(y1)], fill=c)

    def px(self, x, y, c):
        self.d.point((round(x), round(y)), fill=c)

    def finish(self):
        return finish(self.img)


def lighten(c, f):
    return tuple(min(255, int(v + (255 - v) * f)) for v in c[:3]) + (255,)


def darken(c, f):
    return tuple(int(v * (1 - f)) for v in c[:3]) + (255,)


def finish(img):
    """Edge light on the upper-left, shade on the lower-right, dark outline around it all."""
    w, h = img.size
    src = img.load()
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dst = out.load()
    def a(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] > 0
    for y in range(h):
        for x in range(w):
            p = src[x, y]
            if p[3] == 0:
                continue
            if not a(x, y - 1) or not a(x - 1, y):
                dst[x, y] = lighten(p, 0.22)
            elif not a(x, y + 1) or not a(x + 1, y):
                dst[x, y] = darken(p, 0.28)
            else:
                dst[x, y] = p
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0 and (a(x - 1, y) or a(x + 1, y) or a(x, y - 1) or a(x, y + 1)):
                dst[x, y] = OUTLINE + (255,)
    return out


def ragged_hem(x0, x1, y, depth, teeth, seed):
    rnd = random.Random(seed)
    pts = []
    step = (x1 - x0) / teeth
    for i in range(teeth + 1):
        x = x0 + step * i
        pts.append((x, y + (depth if i % 2 else 0) + rnd.randint(-1, 2)))
    return pts


# ---------------------------------------------------------------- shared parts

def hood_and_skull_side(s, ox=0, oy=0, look=1.0):
    # skull first, hood over the back of it, hood rim in front
    s.poly([(26 + ox, 25 + oy), (26 + ox, 13 + oy), (30 + ox, 6 + oy), (37 + ox, 6 + oy),
            (41 + ox, 12 + oy), (40 + ox, 17 + oy), (34 + ox, 12 + oy), (31 + ox, 16 + oy),
            (33 + ox, 25 + oy)], CAPE)
    s.ellipse(30 + ox, 9 + oy, 40 + ox, 19 + oy, BONE)             # cranium
    s.rect(33 + ox, 18 + oy, 39 + ox, 22 + oy, BONE_DARK)           # jaw
    s.rect(34 + ox, 20 + oy, 39 + ox, 20 + oy, SOCKET)              # mouth line
    s.rect(34 + ox, 12 + oy, 38 + ox, 15 + oy, SOCKET)              # eye socket
    s.px(36 + ox, 13 + oy, RED); s.px(37 + ox, 13 + oy, RED_HOT); s.px(36 + ox, 14 + oy, RED)
    s.poly([(27 + ox, 12 + oy), (31 + ox, 5 + oy), (38 + ox, 5 + oy), (41 + ox, 10 + oy),
            (35 + ox, 8 + oy), (30 + ox, 11 + oy), (30 + ox, 24 + oy), (26 + ox, 26 + oy)], CAPE_DARK)


def torso_side(s, ox=0, oy=0, lean=0):
    s.poly([(25 + ox + lean, 22 + oy), (37 + ox + lean, 22 + oy), (39 + ox + lean * 0.6, 31 + oy),
            (36 + ox, 40 + oy), (24 + ox, 40 + oy), (23 + ox + lean * 0.5, 30 + oy)], ARMOR)
    s.rect(33 + ox + lean * 0.6, 28 + oy, 36 + ox + lean * 0.6, 31 + oy, RED)       # chest emblem
    s.px(34 + ox + lean * 0.6, 29 + oy, RED_HOT)
    s.rect(25 + ox, 37 + oy, 36 + ox, 39 + oy, LEATHER)                              # belt
    s.rect(30 + ox, 37 + oy, 32 + ox, 39 + oy, RED)                                  # buckle gem
    s.ellipse(25 + ox + lean, 20 + oy, 35 + ox + lean, 28 + oy, ARMOR_LIGHT)         # pauldron
    s.rect(26 + ox + lean, 26 + oy, 34 + ox + lean, 26 + oy, TRIM)


def cape_side(s, sway=0, oy=0, ox=0):
    pts = [(27 + ox, 22 + oy), (33 + ox, 24 + oy), (33 + ox, 44 + oy),
           (30 + ox + sway * 0.3, 54 + oy)]
    hem = ragged_hem(12 + ox + sway, 30 + ox + sway * 0.3, 55 + oy, 4, 7, 3)
    pts += list(reversed(hem)) + [(15 + ox + sway, 42 + oy), (21 + ox, 28 + oy)]
    s.poly(pts, CAPE)
    s.poly([(24 + ox, 28 + oy), (30 + ox, 30 + oy), (28 + ox + sway * 0.4, 50 + oy), (21 + ox + sway * 0.6, 48 + oy)], CAPE_DARK)


def sword_on_back(s, ox=0, oy=0):
    s.limb((22 + ox, 44 + oy), (29 + ox, 10 + oy), 2, STEEL)
    s.rect(26 + ox, 12 + oy, 32 + ox, 13 + oy, LEATHER)
    for t in (0.35, 0.55, 0.75):
        s.px(22 + (29 - 22) * t + ox, 44 + (10 - 44) * t + oy, RED)


def leg(s, hip, knee, foot, back=False):
    thigh = (50, 46, 66) if back else (84, 76, 108)
    shin = (30, 26, 40) if back else (52, 46, 68)
    s.limb(hip, knee, 6, thigh)
    s.limb(knee, foot, 5, shin)
    fx, fy = foot
    s.rect(fx - 3, fy - 2, fx + 3, fy + 1, (24, 20, 32))
    s.rect(fx - 3, fy - 4, fx + 1, fy - 4, TRIM)
    s.rect(fx - 2, fy - 5, fx + 1, fy - 5, TRIM)
    s.ellipse(knee[0] - 3, knee[1] - 2, knee[0] + 3, knee[1] + 3, STEEL if not back else (70, 70, 84))


def arm(s, sh, elbow, hand, back=False):
    c = darken(ARMOR, 0.2) if back else ARMOR_LIGHT
    s.limb(sh, elbow, 5, c)
    s.limb(elbow, hand, 4, BONE_DARK if not back else darken(BONE_DARK, 0.3))
    s.ellipse(hand[0] - 2, hand[1] - 2, hand[0] + 2, hand[1] + 2, BONE if not back else BONE_DARK)


# ---------------------------------------------------------------- poses

def side_stand(frame=None):
    s = Sprite()
    cape_side(s)
    sword_on_back(s)
    leg(s, (28, 38), (26, 48), (24, 59), back=True)
    arm(s, (28, 25), (26, 33), (27, 41), back=True)
    leg(s, (32, 38), (33, 48), (35, 59))
    torso_side(s)
    hood_and_skull_side(s)
    arm(s, (31, 25), (34, 33), (35, 41))
    return s.finish()


WALK = [  # (front knee, front foot, back knee, back foot, bob, sway, arm swing)
    ((37, 48), (42, 59), (24, 48), (18, 56), 0, 0, 1),
    ((32, 47), (33, 59), (30, 45), (25, 51), -2, 1, 0),
    ((24, 48), (18, 56), (37, 48), (42, 59), 0, 2, -1),
    ((30, 45), (25, 51), (32, 47), (33, 59), -2, 1, 0),
]


def side_walk(i):
    fk, ff, bk, bf, bob, sway, sw = WALK[i]
    s = Sprite()
    cape_side(s, sway=-sway - 1, oy=bob)
    sword_on_back(s, oy=bob)
    leg(s, (28, 38 + bob), bk, bf, back=True)
    arm(s, (28, 25 + bob), (26 + sw * 3, 33 + bob), (24 + sw * 6, 41 + bob), back=True)
    leg(s, (32, 38 + bob), fk, ff)
    torso_side(s, oy=bob)
    hood_and_skull_side(s, oy=bob)
    arm(s, (31, 25 + bob), (34 - sw * 3, 33 + bob), (36 - sw * 6, 40 + bob))
    return s.finish()


def front(back_view=False):
    s = Sprite()
    # cape behind everything
    hem = ragged_hem(10, 54, 57, 4, 11, 5)
    s.poly([(20, 22), (44, 22), (51, 40)] + list(reversed(hem)) + [(13, 40)], CAPE)
    s.poly([(24, 28), (40, 28), (42, 54), (22, 54)], CAPE_DARK)
    if back_view:
        # hooded back, sword slung diagonally across the cloak
        s.poly([(22, 26), (22, 12), (28, 5), (36, 5), (42, 12), (42, 26)], CAPE)
        s.poly([(25, 12), (29, 7), (35, 7), (39, 12), (36, 24), (28, 24)], CAPE_DARK)
        s.limb((20, 54), (44, 20), 3, STEEL)
        for t in (0.15, 0.3, 0.45, 0.6, 0.75):
            s.px(20 + 24 * t, 54 - 34 * t, RED)
        s.rect(41, 16, 47, 18, LEATHER)
        s.rect(26, 56, 31, 60, LEATHER); s.rect(34, 56, 39, 60, LEATHER)
        s.ellipse(18, 22, 27, 30, ARMOR_LIGHT); s.ellipse(37, 22, 46, 30, ARMOR_LIGHT)
        return s.finish()
    leg(s, (28, 40), (27, 49), (26, 59))
    leg(s, (36, 40), (37, 49), (38, 59))
    s.poly([(21, 23), (43, 23), (41, 40), (23, 40)], ARMOR)                       # torso
    s.poly([(28, 40), (36, 40), (39, 52), (32, 49), (25, 52)], darken(CAPE_DARK, 0.1))  # tassets
    s.rect(23, 37, 41, 39, LEATHER); s.rect(30, 36, 34, 40, RED)
    s.rect(30, 27, 34, 33, RED); s.px(31, 29, RED_HOT); s.px(33, 29, RED_HOT)       # chest skull
    s.px(31, 31, SOCKET); s.px(33, 31, SOCKET)
    s.ellipse(15, 21, 25, 30, ARMOR_LIGHT); s.ellipse(39, 21, 49, 30, ARMOR_LIGHT)  # pauldrons
    arm(s, (19, 27), (16, 35), (17, 43)); arm(s, (45, 27), (48, 35), (47, 43))
    # hood + skull
    s.poly([(22, 26), (21, 12), (27, 5), (37, 5), (43, 12), (42, 26)], CAPE)
    s.ellipse(26, 9, 38, 21, BONE)
    s.rect(28, 20, 36, 24, BONE_DARK); s.rect(28, 22, 36, 22, SOCKET)
    s.rect(27, 13, 31, 17, SOCKET); s.rect(33, 13, 37, 17, SOCKET)
    for x, y in ((29, 15), (35, 15)):
        s.px(x, y, RED); s.px(x + 1, y, RED_HOT)
    s.px(32, 18, SOCKET); s.px(32, 19, SOCKET)
    s.poly([(23, 14), (27, 7), (30, 9), (26, 20), (25, 27), (21, 25)], CAPE_DARK)
    s.poly([(41, 14), (37, 7), (34, 9), (38, 20), (39, 27), (43, 25)], CAPE_DARK)
    return s.finish()


def red_crescent(s, cx, cy, r_out, r_in, a0, a1, seed=1):
    rnd = random.Random(seed)
    for y in range(s.img.size[1]):
        for x in range(s.img.size[0]):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            ang = math.degrees(math.atan2(dy, dx))
            if r_in <= r <= r_out and a0 <= ang <= a1:
                t = (r - r_in) / (r_out - r_in)
                edge = abs(ang - (a0 + a1) / 2) / ((a1 - a0) / 2)
                if rnd.random() < 0.15 + 0.85 * (1 - edge ** 3) * (0.4 + t):
                    s.px(x, y, RED_HOT if t > 0.8 and edge < 0.3 else RED)
    for _ in range(26):
        a = math.radians(rnd.uniform(a0 - 20, a1 + 20)); rr = rnd.uniform(r_in - 4, r_out + 5)
        s.px(cx + math.cos(a) * rr, cy + math.sin(a) * rr, RED)


def slash():
    s = Sprite(96, 64)
    cape_side(s, sway=-6, ox=-2, oy=6)
    leg(s, (36, 44), (28, 51), (20, 59), back=True)
    arm(s, (38, 30), (44, 32), (51, 28), back=True)
    leg(s, (40, 44), (49, 50), (52, 59))
    torso_side(s, ox=6, oy=6, lean=4)
    hood_and_skull_side(s, ox=8, oy=7)
    arm(s, (45, 33), (52, 38), (60, 41))
    s.limb((58, 41), (74, 47), 2, STEEL)                          # blade
    s.rect(56, 39, 59, 43, LEATHER)
    red_crescent(s, 52, 36, 36, 20, -50, 70, seed=7)
    return s.finish()


def cast():
    s = Sprite(96, 64)
    cape_side(s, sway=-2)
    leg(s, (28, 38), (25, 48), (22, 59), back=True)
    arm(s, (28, 25), (24, 33), (23, 41), back=True)
    leg(s, (32, 38), (35, 48), (38, 59))
    torso_side(s)
    hood_and_skull_side(s)
    arm(s, (31, 26), (40, 28), (49, 26))                          # reaching forward
    for dx, dy in ((2, -3), (3, -1), (3, 1)):
        s.limb((49, 26), (49 + dx + 2, 26 + dy), 1, BONE)         # spread fingers
    # a fiery skull flies from the hand
    ox, oy = 72, 28
    s.ellipse(ox - 8, oy - 8, ox + 8, oy + 8, (150, 24, 36))
    s.ellipse(ox - 6, oy - 7, ox + 6, oy + 5, RED)
    s.ellipse(ox - 3, oy - 5, ox + 3, oy + 1, RED_HOT)
    s.rect(ox - 5, oy - 3, ox - 2, oy, SOCKET); s.rect(ox + 2, oy - 3, ox + 5, oy, SOCKET)
    s.rect(ox - 3, oy + 3, ox + 3, oy + 5, SOCKET)
    for i in range(5):
        s.rect(ox - 3 + i * 1.5, oy + 3, ox - 3 + i * 1.5, oy + 5, RED_HOT if i % 2 else SOCKET)
    rnd = random.Random(2)
    for i in range(30):                                            # comet tail
        t = rnd.random()
        s.px(ox + 6 + t * 18 + rnd.uniform(-2, 2), oy + 6 + t * 10 + rnd.uniform(-3, 3), RED)
    return s.finish()


def build():
    frames = {'front': front(), 'side': side_stand(), 'back': front(back_view=True),
              'walk_0': side_walk(0), 'walk_1': side_walk(1), 'walk_2': side_walk(2), 'walk_3': side_walk(3),
              'slash': slash(), 'cast': cast()}
    sheet = Image.new('RGBA', (256, 192), (0, 0, 0, 0))
    spots = {'front': (0, 0), 'side': (64, 0), 'back': (128, 0),
             'walk_0': (0, 64), 'walk_1': (64, 64), 'walk_2': (128, 64), 'walk_3': (192, 64),
             'slash': (0, 128), 'cast': (96, 128)}
    for name, pos in spots.items():
        sheet.alpha_composite(frames[name], pos)
    return frames, sheet


if __name__ == '__main__':
    scale = int(sys.argv[sys.argv.index('--scale') + 1]) if '--scale' in sys.argv else 4
    frames, sheet = build()
    os.makedirs(os.path.join(OUT, 'frames'), exist_ok=True)
    for name, img in frames.items():
        img.save(os.path.join(OUT, 'frames', name + '.png'))
    sheet.save(os.path.join(OUT, 'sheet.png'))
    bg = Image.new('RGBA', sheet.size, (236, 234, 240, 255))
    bg.alpha_composite(sheet)
    bg.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(os.path.join(OUT, 'sheet_preview.png'))
    print('ok', sheet.size)
