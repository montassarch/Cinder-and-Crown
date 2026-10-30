# Paints the three later worlds the way cathedral.py paints the first: four parallax layers, fog, floor and
# ledge tiles, a glow and four frames of light, all at game pixel scale (216 px tall, floor top at 192).
#   python3 game/tools/art/biomes.py [--preview out_dir]
# Output: game/art/biomes/<world>/*.png
#   frost_ossuary  an ice-bound crypt of bones: navy and pale cyan, blue crystal lights, snow
#   molten_forge   a giant's foundry: soot black and lava orange, furnace mouths, ash
#   storm_spire    a castle top in a night storm: slate blue, lanterns, rain and lightning
from PIL import Image, ImageDraw
import math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cathedral import arch, haze_gradient, dither_band, mix, BAYER, FLAME  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'art', 'biomes')
H = 216
FLOOR = 192
W = 384


def rgba(c, a=255):
    return tuple(c) + (a,)


def tiled(draw_fn, width, period, *args):
    """Calls draw_fn(x, ...) at x and x +/- width so shapes crossing an edge wrap and the layer tiles."""
    for x in range(0, width, period):
        for shift in (-width, 0, width):
            draw_fn(x + shift, *args)


def glow(colour, size=96, strength=200):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - size / 2, y - size / 2) / (size / 2)
            if d < 1:
                px[x, y] = rgba(colour, int(strength * (1 - d) ** 2))
    return img


def fog(colour, alpha=120, seed=0):
    img = Image.new('RGBA', (W, 80), (0, 0, 0, 0))
    px = img.load()
    for y in range(80):
        a = math.sin(y / 79 * math.pi) ** 1.5
        for x in range(W):
            v = (math.sin(x * 2 * math.pi * 8 / W + y * 0.11 + seed) + math.sin(x * 2 * math.pi * 3 / W - y * 0.07) + 2) / 4
            if (BAYER[y % 4][x % 4] + 0.5) / 16.0 < a * (0.15 + 0.5 * v):
                px[x, y] = rgba(colour, alpha)
    return img


def flame_frames(colours):
    out = []
    for rows in FLAME:
        img = Image.new('RGBA', (14, len(rows)), (0, 0, 0, 0))
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in colours:
                    img.putpixel((x, y), rgba(colours[ch]))
        out.append(img)
    return out


def speckle(img, box, colours, count, seed):
    r = random.Random(seed)
    px = img.load()
    for _ in range(count):
        x = r.randint(box[0], box[2] - 1); y = r.randint(box[1], box[3] - 1)
        if px[x, y][3]:
            px[x, y] = rgba(r.choice(colours))


# ===================================================================================== frost ossuary
def frost():
    out = {}
    # far: a frozen cavern; hanging ice, a frozen waterfall, pale light down low
    img = Image.new('RGBA', (W, H))
    haze_gradient(img, (8, 14, 30), (36, 66, 104), (120, 168, 200), 0.6)
    d = ImageDraw.Draw(img)
    def falls(x):
        for k in range(18):
            c = mix((60, 104, 150), (150, 200, 230), k / 17)
            d.rectangle((x - 18 + k, 20, x - 17 + k, 196), fill=rgba(c))
        for y in range(24, 196, 7):
            d.line([(x - 14, y), (x + 1, y + 3)], fill=rgba((180, 220, 240)))
    tiled(falls, W, 192)
    def stalactite(x, length, shade):
        d.polygon([(x - 9, 0), (x + 9, 0), (x + 1, length)], fill=rgba(shade))
        d.line([(x - 6, 0), (x, length - 4)], fill=rgba(mix(shade, (200, 230, 250), 0.4)))
    r = random.Random(1)
    for x in range(8, W, 24):
        stalactite(x, r.randint(18, 60), (28, 50, 84))
    for x in range(0, W + 1, 64):                                  # distant ice spires on the cavern floor
        d.polygon([(x - 14, 196), (x - 2, 120 + (x * 7) % 30), (x + 12, 196)], fill=rgba((54, 92, 132)))
        d.polygon([(x - 2, 196), (x - 2, 128 + (x * 7) % 30), (x + 12, 196)], fill=rgba((80, 124, 164)))
    dither_band(img, 130, 200, (170, 205, 230), 0.0, 0.55, 3)
    out['layer_far'] = img

    # mid-far: columns of stacked skulls, frosted, linked by rib arches
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    def skull_column(x):
        d.rectangle((x - 11, 14, x + 11, 190), fill=rgba((44, 60, 86)))
        for y in range(20, 186, 12):
            for sx in (-6, 5):
                d.ellipse((x + sx - 4, y, x + sx + 4, y + 8), fill=rgba((122, 136, 156)))
                d.point((x + sx - 2, y + 4), fill=rgba((30, 38, 56))); d.point((x + sx + 1, y + 4), fill=rgba((30, 38, 56)))
        d.rectangle((x - 11, 14, x - 9, 190), fill=rgba((140, 186, 220)))          # frost on the lit side
        d.rectangle((x - 15, 8, x + 15, 16), fill=rgba((58, 78, 106)))
        d.rectangle((x - 14, 186, x + 14, 194), fill=rgba((58, 78, 106)))
    tiled(skull_column, W, 96, )
    def ribs(x):
        for k in range(4):
            d.arc((x + 6, 6 + k * 5, x + 90, 90 + k * 5), 190, 350, fill=rgba((96, 112, 136)), width=2)
    tiled(ribs, W, 96)
    d.rectangle((0, 0, W, 8), fill=rgba((20, 30, 50)))
    out['layer_mid_far'] = img

    # mid: the crypt wall: ice-glazed masonry, rows of skull niches, frozen arches, crystal clusters (lights)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = random.Random(11)
    wall = (50, 70, 98)
    d.rectangle((0, 42, W, 190), fill=rgba(wall))
    for y in range(42, 190, 10):
        off = 0 if (y // 10) % 2 == 0 else 14
        for x in range(-28 + off, W, 28):
            s = r.randint(-5, 5)
            d.rectangle((x + 1, y + 1, x + 26, y + 8), fill=rgba((wall[0] + s, wall[1] + s + 2, wall[2] + s + 4)))
    for cx in (192,):                                                # a frozen arch with a pale glow behind
        arch(d, cx, 150, 64, 120, rgba((18, 26, 44)))
        arch(d, cx, 148, 54, 110, rgba((96, 150, 196)))
        arch(d, cx, 130, 26, 64, rgba((190, 228, 248)))
    for row_y in (60, 92):                                           # ossuary niches full of skulls
        for x in list(range(20, 140, 22)) + list(range(244, 372, 22)):
            d.rectangle((x - 8, row_y, x + 8, row_y + 18), fill=rgba((20, 28, 44)))
            d.ellipse((x - 5, row_y + 6, x + 5, row_y + 16), fill=rgba((176, 186, 196)))
            d.rectangle((x - 3, row_y + 10, x - 1, row_y + 12), fill=rgba((24, 30, 44)))
            d.rectangle((x + 1, row_y + 10, x + 3, row_y + 12), fill=rgba((24, 30, 44)))
    for x in (0, 128, 256, 384):                                     # pillars at the bay seams, ice-crusted
        d.rectangle((x - 13, 0, x + 13, 192), fill=rgba((66, 90, 120)))
        d.rectangle((x - 13, 0, x - 9, 192), fill=rgba((150, 196, 226)))
        d.rectangle((x + 9, 0, x + 13, 192), fill=rgba((40, 56, 80)))
        d.rectangle((x - 17, 24, x + 17, 36), fill=rgba((84, 112, 146)))
        d.rectangle((x - 16, 180, x + 16, 192), fill=rgba((84, 112, 146)))
        for k in range(5):                                           # icicles hanging off the capital
            d.polygon([(x - 15 + k * 7, 36), (x - 11 + k * 7, 36), (x - 13 + k * 7, 44 + (k * 5) % 9)], fill=rgba((190, 225, 245)))
    for cx in (70, 300):                                             # crystal plinths under the lights
        d.rectangle((cx - 10, 168, cx + 10, 192), fill=rgba((56, 76, 104)))
        d.rectangle((cx - 12, 164, cx + 12, 169), fill=rgba((96, 130, 166)))
        for k, (dx, h) in enumerate(((-7, 10), (6, 12), (-1, 16))):
            d.polygon([(cx + dx - 3, 164), (cx + dx, 164 - h), (cx + dx + 3, 164)], fill=rgba((120, 190, 240)))
    for cx in (40, 160, 230, 350):                                   # bones and skulls in the frost at the wall foot
        d.ellipse((cx - 4, 184, cx + 4, 192), fill=rgba((200, 210, 220)))
        d.rectangle((cx - 2, 186, cx - 1, 187), fill=rgba((30, 36, 50))); d.rectangle((cx + 1, 186, cx + 2, 187), fill=rgba((30, 36, 50)))
        d.line([(cx + 6, 190), (cx + 16, 187)], fill=rgba((200, 210, 220)), width=2)
    out['layer_mid'] = img

    # near: icicle curtains and frosted chains hanging from the roof
    img = Image.new('RGBA', (W * 2, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = random.Random(5)
    for x in range(0, W * 2, 6):
        L = r.randint(4, 30) if (x // 60) % 3 != 1 else r.randint(20, 58)
        d.polygon([(x, 0), (x + 5, 0), (x + 2, L)], fill=rgba((150, 205, 240)))
        d.line([(x + 1, 0), (x + 2, L - 2)], fill=rgba((235, 248, 255)))
    for x in range(70, W * 2, 190):
        for y in range(0, r.randint(40, 80), 4):
            d.rectangle((x + (2 if (y // 4) % 2 else 0), y, x + 2 + (2 if (y // 4) % 2 else 0), y + 3), fill=rgba((24, 36, 56)))
    out['layer_near'] = img

    out['fog'] = fog((190, 225, 245), 130, 1)
    t = Image.new('RGBA', (32, 16), rgba((70, 92, 122)))
    d = ImageDraw.Draw(t)
    d.line([(0, 0), (31, 0)], fill=rgba((235, 250, 255))); d.line([(0, 1), (31, 1)], fill=rgba((150, 200, 232)))
    d.line([(0, 7), (31, 7)], fill=rgba((34, 46, 70))); d.line([(0, 15), (31, 15)], fill=rgba((34, 46, 70)))
    for x in (15, 7):
        d.line([(x, 8), (x, 14)], fill=rgba((34, 46, 70)))
    d.line([(24, 2), (24, 6)], fill=rgba((34, 46, 70)))
    for x in (3, 12, 21, 28):                                        # frost drips over the top edge
        d.line([(x, 2), (x, 2 + (x % 3) + 1)], fill=rgba((200, 235, 250)))
    speckle(t, (0, 3, 32, 15), [(90, 116, 150), (54, 72, 100)], 26, 21)
    out['ground_tile'] = t
    t = Image.new('RGBA', (16, 8), rgba((84, 110, 140)))
    d = ImageDraw.Draw(t)
    d.line([(0, 0), (15, 0)], fill=rgba((240, 252, 255))); d.line([(0, 1), (15, 1)], fill=rgba((160, 210, 240)))
    d.line([(0, 7), (15, 7)], fill=rgba((36, 48, 72))); d.line([(7, 2), (7, 6)], fill=rgba((36, 48, 72)))
    out['ledge_tile'] = t
    out['glow'] = glow((110, 190, 255))
    for i in range(4):                                               # a crystal whose sparkle walks round it
        c = Image.new('RGBA', (14, 20), (0, 0, 0, 0))
        d = ImageDraw.Draw(c)
        d.polygon([(7, 0), (12, 8), (7, 19), (2, 8)], fill=rgba((90, 170, 240)))
        d.polygon([(7, 0), (7, 19), (2, 8)], fill=rgba((170, 225, 255)))
        d.line([(7, 1), (7, 18)], fill=rgba((235, 250, 255)))
        sx, sy = [(4, 6), (10, 9), (6, 14), (8, 4)][i]
        d.point((sx, sy), fill=rgba((255, 255, 255))); d.point((sx + 1, sy), fill=rgba((255, 255, 255)))
        d.point((sx, sy - 1), fill=rgba((220, 245, 255))); d.point((sx, sy + 1), fill=rgba((220, 245, 255)))
        out['light_%d' % i] = c
    return out


# ===================================================================================== molten forge
def forge():
    out = {}
    img = Image.new('RGBA', (W, H))
    haze_gradient(img, (14, 4, 6), (70, 22, 14), (200, 96, 40), 0.62)
    d = ImageDraw.Draw(img)
    def lava_fall(x):
        for k in range(14):
            c = mix((200, 60, 10), (255, 200, 80), 1 - abs(k - 7) / 7)
            d.rectangle((x - 7 + k, 30, x - 6 + k, 196), fill=rgba(c))
        d.ellipse((x - 20, 186, x + 20, 200), fill=rgba((255, 170, 60)))
    tiled(lava_fall, W, 192)
    def stack(x):                                                     # smokestacks and a giant cog, far away
        d.rectangle((x + 40, 40, x + 54, 196), fill=rgba((44, 16, 14)))
        d.rectangle((x + 37, 36, x + 57, 44), fill=rgba((56, 22, 18)))
        cx, cy, R = x + 100, 120, 30
        for k in range(12):
            a = k * math.tau / 12
            d.polygon([(cx + math.cos(a - 0.12) * R, cy + math.sin(a - 0.12) * R), (cx + math.cos(a - 0.08) * (R + 8), cy + math.sin(a - 0.08) * (R + 8)),
                       (cx + math.cos(a + 0.08) * (R + 8), cy + math.sin(a + 0.08) * (R + 8)), (cx + math.cos(a + 0.12) * R, cy + math.sin(a + 0.12) * R)], fill=rgba((52, 18, 16)))
        d.ellipse((cx - R, cy - R, cx + R, cy + R), fill=rgba((52, 18, 16)))
        d.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=rgba((96, 40, 24)))
    tiled(stack, W, 192)
    dither_band(img, 128, 200, (230, 120, 50), 0.0, 0.55, 3)
    out['layer_far'] = img

    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    def girder(x):                                                    # iron girders and hanging chains
        d.rectangle((x - 8, 10, x + 8, 190), fill=rgba((40, 20, 18)))
        d.rectangle((x - 8, 10, x - 6, 190), fill=rgba((150, 70, 34)))
        for y in range(20, 186, 18):
            d.line([(x - 8, y), (x + 8, y + 16)], fill=rgba((30, 14, 12)), width=2)
            d.line([(x + 8, y), (x - 8, y + 16)], fill=rgba((30, 14, 12)), width=2)
        for y in range(10, 120, 6):
            d.ellipse((x + 40, y, x + 46, y + 7), outline=rgba((70, 32, 24)))
    tiled(girder, W, 96)
    d.rectangle((0, 0, W, 10), fill=rgba((26, 10, 10)))
    out['layer_mid_far'] = img

    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    plate = (58, 34, 30)
    d.rectangle((0, 38, W, 190), fill=rgba(plate))
    for y in range(38, 190, 24):                                      # riveted iron plates
        for x in range(0, W, 32):
            d.rectangle((x, y, x + 31, y + 23), outline=rgba((36, 20, 18)))
            for rx, ry in ((3, 3), (28, 3), (3, 20), (28, 20)):
                d.point((x + rx, y + ry), fill=rgba((120, 70, 50)))
    dither_band(img, 140, 190, (196, 104, 56), 0.0, 0.6, 4)           # furnace light pooling along the floor
    for cx in (110, 290):                                             # furnace mouths (the lights burn inside)
        d.rectangle((cx - 26, 104, cx + 26, 172), fill=rgba((42, 22, 20)))
        arch(d, cx, 164, 40, 52, rgba((20, 8, 8)))
        arch(d, cx, 162, 32, 44, rgba((160, 50, 14)))
        arch(d, cx, 160, 22, 30, rgba((250, 150, 40)))
        d.rectangle((cx - 30, 172, cx + 30, 178), fill=rgba((80, 44, 36)))
        for k in range(-24, 25, 8):                                   # glow spilling on the plate below
            d.line([(cx + k, 179), (cx + k * 1.3, 190)], fill=rgba((150, 70, 30)))
    for cx in (200,):                                                 # a lava channel window
        d.rectangle((cx - 30, 60, cx + 30, 92), fill=rgba((24, 10, 10)))
        for k in range(28):
            d.line([(cx - 28 + k * 2, 62), (cx - 28 + k * 2, 90)], fill=rgba(mix((200, 60, 10), (255, 190, 70), (k % 5) / 4)))
        for k in range(-30, 31, 10):
            d.line([(cx + k, 60), (cx + k, 92)], fill=rgba((24, 10, 10)), width=2)
    for x in (0, 128, 256, 384):                                      # soot-black pillars with hot edges
        d.rectangle((x - 13, 0, x + 13, 192), fill=rgba((46, 26, 24)))
        d.rectangle((x - 13, 0, x - 10, 192), fill=rgba((210, 110, 50)))
        d.rectangle((x - 17, 22, x + 17, 34), fill=rgba((66, 36, 30)))
        d.rectangle((x - 16, 180, x + 16, 192), fill=rgba((66, 36, 30)))
    for cx in (40, 180, 240, 350):                                    # anvils and slag at the wall foot
        d.polygon([(cx - 8, 180), (cx + 10, 180), (cx + 6, 184), (cx - 4, 184)], fill=rgba((34, 30, 34)))
        d.rectangle((cx - 2, 184, cx + 4, 192), fill=rgba((34, 30, 34)))
        d.line([(cx - 8, 180), (cx + 10, 180)], fill=rgba((170, 120, 100)))
    out['layer_mid'] = img

    img = Image.new('RGBA', (W * 2, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = random.Random(5)
    d.rectangle((0, 0, W * 2, 6), fill=rgba((30, 12, 10)))
    for x in range(0, W * 2, 160):                                    # a pipe run with a bent drop
        d.rectangle((x, 8, x + 120, 14), fill=rgba((54, 28, 24)))
        d.rectangle((x, 8, x + 120, 9), fill=rgba((170, 90, 50)))
        d.rectangle((x + 110, 8, x + 116, 40), fill=rgba((54, 28, 24)))
    for x in range(40, W * 2, 110):                                   # chains and hooks
        L = r.randint(30, 80)
        for y in range(0, L, 4):
            d.rectangle((x + (2 if (y // 4) % 2 else 0), y, x + 2 + (2 if (y // 4) % 2 else 0), y + 3), fill=rgba((26, 12, 12)))
        d.arc((x - 3, L - 2, x + 7, L + 8), 0, 200, fill=rgba((26, 12, 12)), width=2)
    out['layer_near'] = img

    out['fog'] = fog((255, 140, 60), 90, 2)
    t = Image.new('RGBA', (32, 16), rgba((46, 34, 34)))
    d = ImageDraw.Draw(t)
    d.line([(0, 0), (31, 0)], fill=rgba((255, 170, 70))); d.line([(0, 1), (31, 1)], fill=rgba((140, 70, 40)))
    d.line([(0, 7), (31, 7)], fill=rgba((24, 16, 18))); d.line([(0, 15), (31, 15)], fill=rgba((24, 16, 18)))
    for x in (15, 7):
        d.line([(x, 8), (x, 14)], fill=rgba((24, 16, 18)))
    d.line([(4, 3), (9, 5), (12, 4)], fill=rgba((240, 110, 30)))   # glowing cracks in the basalt
    d.line([(19, 10), (23, 12), (27, 11)], fill=rgba((240, 110, 30)))
    speckle(t, (0, 2, 32, 15), [(64, 48, 46), (34, 26, 28)], 24, 22)
    out['ground_tile'] = t
    t = Image.new('RGBA', (16, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(t)
    d.rectangle((0, 0, 15, 7), fill=rgba((60, 40, 36)))
    d.line([(0, 0), (15, 0)], fill=rgba((255, 160, 70))); d.line([(0, 7), (15, 7)], fill=rgba((26, 16, 16)))
    for x in (3, 7, 11):                                              # an iron grate
        d.rectangle((x, 2, x + 1, 6), fill=rgba((26, 16, 16)))
    out['ledge_tile'] = t
    out['glow'] = glow((255, 120, 40), 110, 220)
    for i, f in enumerate(flame_frames({'r': (210, 50, 20), 'o': (255, 120, 30), 'y': (255, 200, 70), 'w': (255, 250, 210)})):
        out['light_%d' % i] = f
    return out


# ===================================================================================== storm spire
def storm():
    out = {}
    img = Image.new('RGBA', (W, H))
    haze_gradient(img, (6, 8, 20), (30, 38, 72), (96, 108, 150), 0.62)
    d = ImageDraw.Draw(img)
    d.ellipse((260, 24, 300, 64), fill=rgba((196, 206, 230)))           # the moon, half under cloud
    d.ellipse((268, 30, 296, 58), fill=rgba((226, 232, 246)))
    r = random.Random(3)
    for layer, (col, y0) in enumerate((((40, 48, 82), 40), ((56, 64, 102), 64), ((44, 50, 86), 92))):
        for x in range(-40, W + 40, 34):
            rr = 18 + r.randint(0, 12)
            for shift in (-W, 0, W):
                d.ellipse((x + shift - rr, y0 - rr // 2 + r.randint(-6, 6), x + shift + rr, y0 + rr // 2), fill=rgba(col))
    def spire(x):                                                    # distant towers with lit windows
        h = 70 + (x * 13) % 50
        d.rectangle((x - 7, 196 - h, x + 7, 196), fill=rgba((20, 24, 44)))
        d.polygon([(x - 10, 196 - h), (x, 196 - h - 22), (x + 10, 196 - h)], fill=rgba((20, 24, 44)))
        for y in range(196 - h + 10, 190, 14):
            d.rectangle((x - 1, y, x + 1, y + 3), fill=rgba((250, 210, 120)))
    tiled(spire, W, 64)
    dither_band(img, 136, 200, (130, 140, 180), 0.0, 0.5, 3)
    out['layer_far'] = img

    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    def island(x):                                                   # broken towers on floating rock
        d.polygon([(x + 10, 110), (x + 70, 110), (x + 56, 140), (x + 40, 158), (x + 24, 140)], fill=rgba((34, 38, 62)))
        d.rectangle((x + 26, 50, x + 54, 112), fill=rgba((44, 50, 80)))
        d.polygon([(x + 26, 50), (x + 34, 40), (x + 40, 48), (x + 48, 36), (x + 54, 50)], fill=rgba((44, 50, 80)))
        d.rectangle((x + 26, 50, x + 28, 112), fill=rgba((110, 124, 170)))
        for y in (62, 82):
            d.rectangle((x + 36, y, x + 42, y + 8), fill=rgba((240, 200, 110)))
    tiled(island, W, 192)
    out['layer_mid_far'] = img

    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = random.Random(11)
    wall = (58, 64, 96)
    d.rectangle((0, 112, W, 190), fill=rgba(wall))                   # a low battlement wall: the sky shows above it
    for y in range(112, 190, 10):
        off = 0 if (y // 10) % 2 == 0 else 14
        for x in range(-28 + off, W, 28):
            s = r.randint(-5, 5)
            d.rectangle((x + 1, y + 1, x + 26, y + 8), fill=rgba((wall[0] + s, wall[1] + s, wall[2] + s + 3)))
    for x in range(0, W, 24):                                         # crenellations
        d.rectangle((x, 100, x + 12, 112), fill=rgba((70, 78, 112)))
        d.rectangle((x, 100, x + 12, 101), fill=rgba((150, 164, 210)))
    for x in (0, 128, 256, 384):                                      # tall arched towers at the bay seams
        d.rectangle((x - 16, 0, x + 16, 192), fill=rgba((66, 72, 104)))
        d.rectangle((x - 16, 0, x - 12, 192), fill=rgba((140, 154, 200)))
        d.rectangle((x + 12, 0, x + 16, 192), fill=rgba((40, 44, 70)))
        arch(d, x, 90, 14, 40, rgba((18, 20, 38)))
        arch(d, x, 88, 8, 30, rgba((250, 210, 110)))
    for cx in (192,):                                                 # a blue and gold banner
        d.rectangle((cx - 14, 104, cx + 14, 106), fill=rgba((140, 120, 70)))
        d.polygon([(cx - 12, 106), (cx + 12, 106), (cx + 12, 160), (cx, 150), (cx - 12, 160)], fill=rgba((36, 56, 130)))
        d.rectangle((cx - 4, 118, cx + 4, 132), fill=rgba((230, 196, 100)))
    for cx in (80, 260):                                              # lantern posts (the lights hang here)
        d.rectangle((cx - 2, 142, cx + 2, 192), fill=rgba((30, 32, 50)))
        d.rectangle((cx - 7, 140, cx + 7, 143), fill=rgba((70, 76, 110)))
    for cx in (30, 160, 220, 340):                                    # puddles catching the light at the foot
        d.ellipse((cx - 10, 188, cx + 10, 192), fill=rgba((120, 140, 190)))
    out['layer_mid'] = img

    img = Image.new('RGBA', (W * 2, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in range(0, W * 2, 256):                                    # a broken arch framing the top corners
        d.pieslice((x - 60, -60, x + 60, 60), 0, 180, fill=rgba((24, 26, 44)))
        d.pieslice((x - 44, -44, x + 44, 44), 0, 180, fill=(0, 0, 0, 0))
    for x in range(120, W * 2, 256):                                  # pennants snapping in the wind
        d.line([(x, 0), (x, 30)], fill=rgba((30, 30, 46)), width=2)
        d.polygon([(x, 4), (x + 30, 10), (x, 18)], fill=rgba((150, 30, 40)))
    out['layer_near'] = img

    out['fog'] = fog((150, 165, 210), 110, 3)
    t = Image.new('RGBA', (32, 16), rgba((62, 68, 98)))
    d = ImageDraw.Draw(t)
    d.line([(0, 0), (31, 0)], fill=rgba((190, 210, 255))); d.line([(0, 1), (31, 1)], fill=rgba((110, 124, 170)))
    d.line([(0, 7), (31, 7)], fill=rgba((30, 34, 54))); d.line([(0, 15), (31, 15)], fill=rgba((30, 34, 54)))
    for x in (15, 7):
        d.line([(x, 8), (x, 14)], fill=rgba((30, 34, 54)))
    d.line([(24, 1), (24, 6)], fill=rgba((30, 34, 54)))
    d.line([(3, 3), (10, 3)], fill=rgba((120, 140, 200)))            # wet sheen
    speckle(t, (0, 2, 32, 15), [(80, 88, 120), (46, 50, 76)], 24, 23)
    out['ground_tile'] = t
    t = Image.new('RGBA', (16, 8), rgba((74, 80, 112)))
    d = ImageDraw.Draw(t)
    d.line([(0, 0), (15, 0)], fill=rgba((200, 220, 255))); d.line([(0, 1), (15, 1)], fill=rgba((130, 144, 190)))
    d.line([(0, 7), (15, 7)], fill=rgba((32, 36, 56)))
    for x in (2, 8, 14):                                              # balusters
        d.rectangle((x, 3, x + 1, 6), fill=rgba((40, 44, 66)))
    out['ledge_tile'] = t
    out['glow'] = glow((120, 170, 255), 96, 210)
    for i, f in enumerate(flame_frames({'r': (40, 80, 200), 'o': (80, 150, 255), 'y': (160, 210, 255), 'w': (240, 250, 255)})):
        lantern = Image.new('RGBA', (14, 20), (0, 0, 0, 0))
        lantern.alpha_composite(f.resize((10, 12), Image.NEAREST), (2, 4))
        d = ImageDraw.Draw(lantern)
        d.rectangle((1, 2, 12, 19), outline=rgba((40, 42, 60)))      # the lantern cage
        d.line([(1, 2), (12, 2)], fill=rgba((90, 96, 130)))
        d.line([(6, 0), (7, 0)], fill=rgba((40, 42, 60)))
        out['light_%d' % i] = lantern
    return out


WORLDS = {'frost_ossuary': frost, 'molten_forge': forge, 'storm_spire': storm}


def preview(made, path, light_x, light_y):
    w = 468
    scene = Image.new('RGBA', (w, H), (0, 0, 0, 255))
    for name in ('layer_far', 'layer_mid_far', 'layer_mid', 'layer_near'):
        im = made[name]
        for x in range(0, w, im.size[0]):
            scene.alpha_composite(im, (x, 0))
    for x in range(0, w, W):
        scene.alpha_composite(made['fog'], (x, 130))
    for x in range(0, w, 32):
        scene.alpha_composite(made['ground_tile'], (x, FLOOR)); scene.alpha_composite(made['ground_tile'], (x, FLOOR + 16))
    for x in range(140, 240, 16):
        scene.alpha_composite(made['ledge_tile'], (x, 150))
    for cx in light_x:
        g = made['glow']
        scene.alpha_composite(g, (int(cx - g.width / 2), int(light_y - 16 - g.height / 2)))
        f = made['light_0']
        scene.alpha_composite(f, (int(cx - f.width / 2), int(light_y - f.height)))
    scene.resize((w * 3, H * 3), Image.NEAREST).convert('RGB').save(path)


def main():
    lights = {'frost_ossuary': ((70, 300), 150), 'molten_forge': ((110, 290), 150), 'storm_spire': ((80, 260), 140)}
    for world, fn in WORLDS.items():
        out = os.path.join(ROOT, world)
        os.makedirs(out, exist_ok=True)
        made = fn()
        for name, im in made.items():
            im.save(os.path.join(out, name + '.png'))
        if '--preview' in sys.argv:
            d = sys.argv[sys.argv.index('--preview') + 1]
            os.makedirs(d, exist_ok=True)
            preview(made, os.path.join(d, world + '.png'), *lights[world])
        print('wrote', out)


if __name__ == '__main__':
    main()
