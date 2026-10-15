# Paints the ruined cathedral hall: four parallax layers, fog, floor and ledge tiles, flames.
#   python3 game/tools/art/cathedral.py [--preview out.png]
# Output: game/art/cathedral/*.png (all drawn at game pixel scale, 216 px tall).
# Palette idea: cold blue-grey stone and haze, orange torch light, blood-red glass.
# The hero is near-black, so the band behind the walking line is kept hazy and lit.
from PIL import Image, ImageDraw
import math, os, random, sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'art', 'cathedral')
H = 216
GROUND_Y = 192   # top of the floor, in px (12 tiles)

def lerp(a, b, t): return a + (b - a) * t
def mix(c1, c2, t): return tuple(int(lerp(c1[i], c2[i], t)) for i in range(3))
def rng(seed): return random.Random(seed)

def arch(draw, cx, base_y, w, h, fill, outline=None):
    """Pointed gothic arch: straight sides up to the spring line, two arcs to the apex."""
    spring = base_y - (h - w * 0.9)
    pts = [(cx - w / 2, base_y), (cx - w / 2, spring)]
    for i in range(1, 9):
        t = i / 8
        pts.append((cx - w / 2 + w / 2 * t, spring - (h - (base_y - spring)) * math.sin(t * math.pi / 2) ** 1.4))
    for i in range(7, 0, -1):
        t = i / 8
        pts.append((cx + w / 2 - w / 2 * t, spring - (h - (base_y - spring)) * math.sin(t * math.pi / 2) ** 1.4))
    pts += [(cx + w / 2, spring), (cx + w / 2, base_y)]
    draw.polygon(pts, fill=fill, outline=outline)

def haze_gradient(img, top, mid, bottom, mid_at=0.62):
    d = ImageDraw.Draw(img)
    for y in range(img.size[1]):
        t = y / (img.size[1] - 1)
        c = mix(top, mid, t / mid_at) if t < mid_at else mix(mid, bottom, (t - mid_at) / (1 - mid_at))
        d.line([(0, y), (img.size[0], y)], fill=c + (255,))

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

def dither_band(img, y0, y1, color, alpha_top, alpha_bottom, seed):
    """Ordered (Bayer) dither: a clean, regular fade instead of random speckle."""
    px = img.load()
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        a = lerp(alpha_top, alpha_bottom, t)
        for x in range(img.size[0]):
            if (BAYER[y % 4][x % 4] + 0.5) / 16.0 < a:
                px[x, y] = color + (255,)

def layer_far():
    W = 384
    img = Image.new('RGBA', (W, H))
    haze_gradient(img, (16, 18, 34), (46, 52, 78), (86, 92, 120))
    d = ImageDraw.Draw(img)
    # distant hall: tall arch openings with a cold glow inside
    for i in range(0, W, 96):
        cx = i + 48
        arch(d, cx, 176, 54, 150, (34, 38, 60))
        arch(d, cx, 176, 38, 124, (62, 72, 108))
        arch(d, cx, 176, 22, 96, (92, 104, 142))
    for x in range(0, W + 1, 96):                                 # distant pillars (one at each edge so it tiles)
        d.rectangle((x - 3, 0, x + 3, 190), fill=(30, 34, 54))
    dither_band(img, 130, 200, (120, 128, 156), 0.0, 0.5, 3)      # fog thickening toward the floor
    return img

def layer_mid_far():
    W = 384
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in range(0, W + 1, 96):                                  # one pillar at each edge so the layer tiles
        d.rectangle((x - 9, 18, x + 9, 188), fill=(34, 38, 58, 255))
        d.rectangle((x - 9, 18, x - 7, 188), fill=(52, 58, 84, 255))             # lit left edge
        d.rectangle((x - 13, 10, x + 13, 20), fill=(40, 44, 68, 255))            # capital
        d.rectangle((x - 12, 184, x + 12, 192), fill=(40, 44, 68, 255))          # base
        for y in range(30, 184, 14):
            d.line([(x - 9, y), (x + 9, y)], fill=(28, 32, 50, 255))             # drum joints
        # ribs springing from the capital into vaults
        for k in range(1, 6):
            d.line([(x + 13, 12 + k * 2), (x + 13 + k * 8, 12 - k * 2 + 4)], fill=(36, 40, 62, 255))
    d.rectangle((0, 0, W, 12), fill=(26, 28, 46, 255))                          # ceiling band
    return img

def layer_mid():
    W = 384
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = rng(11)
    # back wall of masonry between the pillars
    wall = (54, 58, 80, 255)
    d.rectangle((0, 40, W, 190), fill=wall)
    for y in range(40, 190, 10):
        off = 0 if (y // 10) % 2 == 0 else 14
        for x in range(-28 + off, W, 28):
            shade = r.randint(-5, 5)
            d.rectangle((x + 1, y + 1, x + 26, y + 8), fill=(wall[0] + shade, wall[1] + shade, wall[2] + shade, 255))
    # stained-glass windows: red, blue, red (pointed arches with leading)
    for cx, glass, glow in ((64, (150, 34, 44), (230, 80, 70)), (192, (46, 82, 150), (110, 160, 235)), (320, (150, 34, 44), (230, 80, 70))):
        arch(d, cx, 140, 40, 100, (22, 22, 36, 255))
        arch(d, cx, 138, 32, 92, glass + (255,))
        arch(d, cx, 120, 14, 56, glow + (255,))
        for y in range(70, 138, 11):
            d.line([(cx - 16, y), (cx + 16, y)], fill=(22, 22, 36, 255))
        d.line([(cx, 52), (cx, 138)], fill=(22, 22, 36, 255))
    # tall pillars at the seams of the 128px bays
    for x in (0, 128, 256, 384):
        d.rectangle((x - 13, 0, x + 13, 192), fill=(70, 74, 98, 255))
        d.rectangle((x - 13, 0, x - 10, 192), fill=(96, 100, 128, 255))
        d.rectangle((x + 10, 0, x + 13, 192), fill=(46, 48, 68, 255))
        d.rectangle((x - 17, 24, x + 17, 36), fill=(82, 86, 112, 255))
        d.rectangle((x - 16, 180, x + 16, 192), fill=(82, 86, 112, 255))
        for y in range(48, 178, 16):
            d.line([(x - 13, y), (x + 13, y)], fill=(56, 60, 82, 255))
    # braziers on stone plinths in the bays beside the red windows
    for cx in (96, 352 % W if False else 352):
        d.rectangle((cx - 9, 176, cx + 9, 192), fill=(62, 64, 88, 255))
        d.rectangle((cx - 11, 172, cx + 11, 177), fill=(86, 88, 116, 255))
        d.polygon([(cx - 9, 160), (cx + 9, 160), (cx + 6, 172), (cx - 6, 172)], fill=(34, 34, 48, 255))
        d.rectangle((cx - 10, 158, cx + 10, 161), fill=(70, 72, 96, 255))
    # skulls and rubble at the foot of the wall
    for cx in (30, 170, 228, 300):
        d.ellipse((cx - 4, 184, cx + 4, 192), fill=(176, 172, 164, 255))
        d.rectangle((cx - 2, 186, cx - 1, 187), fill=(30, 28, 36, 255))
        d.rectangle((cx + 1, 186, cx + 2, 187), fill=(30, 28, 36, 255))
        d.rectangle((cx - 2, 190, cx + 2, 192), fill=(150, 146, 140, 255))
    return img

def layer_near():
    W = 768
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = rng(5)
    ink = (10, 10, 18, 255)
    # hanging chains and roots from the vault
    for x in range(30, W, 70):
        length = r.randint(26, 70)
        for y in range(0, length, 4):
            d.rectangle((x + (2 if (y // 4) % 2 else 0), y, x + 2 + (2 if (y // 4) % 2 else 0), y + 3), fill=ink)
    # torn red banners hanging from the vault (colour, and nothing near-black at walking height)
    for cx in range(110, W, 256):
        d.rectangle((cx - 12, 0, cx + 12, 4), fill=(60, 50, 40, 255))
        top = 4
        h = r.randint(70, 96)
        pts = [(cx - 11, top), (cx + 11, top), (cx + 11, top + h)]
        for k in range(5):
            pts.append((cx + 11 - (k + 1) * 4.4, top + h - 8 + (8 if k % 2 == 0 else 0)))
        pts.append((cx - 11, top + h))
        d.polygon(pts, fill=(132, 26, 36, 255))
        d.line([(cx - 11, top), (cx - 11, top + h)], fill=(176, 50, 56, 255))
        d.rectangle((cx - 3, top + 18, cx + 3, top + 34), fill=(210, 176, 110, 255))
        d.rectangle((cx - 1, top + 22, cx + 1, top + 30), fill=(132, 26, 36, 255))
    img.alpha_composite(Image.new('RGBA', img.size, (0, 0, 0, 0)))
    return img

def fog():
    W = 384
    img = Image.new('RGBA', (W, 80), (0, 0, 0, 0))
    r = rng(9)
    px = img.load()
    for y in range(80):
        t = y / 79
        a = math.sin(t * math.pi) ** 1.5
        for x in range(W):
            # wrap the wave so the layer tiles: frequencies are whole multiples of 2*pi/W
            v = (math.sin(x * 2 * math.pi * 8 / W + y * 0.11) + math.sin(x * 2 * math.pi * 3 / W - y * 0.07) + 2) / 4
            if (BAYER[y % 4][x % 4] + 0.5) / 16.0 < a * (0.15 + 0.5 * v):
                px[x, y] = (150, 158, 190, 120)
    return img

def ground_tile():
    # 32x16 stone slab course: lit top edge, joints, speckle
    img = Image.new('RGBA', (32, 16), (58, 62, 84, 255))
    d = ImageDraw.Draw(img)
    r = rng(21)
    d.line([(0, 0), (31, 0)], fill=(210, 120, 70, 255))                 # torch-lit top edge
    d.line([(0, 1), (31, 1)], fill=(120, 96, 100, 255))
    d.line([(0, 7), (31, 7)], fill=(30, 32, 48, 255))
    d.line([(0, 15), (31, 15)], fill=(30, 32, 48, 255))
    for x in (15, 7):
        d.line([(x, 8), (x, 14)], fill=(30, 32, 48, 255))
    d.line([(24, 1), (24, 6)], fill=(30, 32, 48, 255))
    for _ in range(26):
        d.point((r.randint(0, 31), r.randint(2, 14)), fill=(r.choice([(76, 80, 104, 255), (44, 48, 68, 255)])))
    return img

def ledge_tile():
    # 16x8 broken stone ledge for the one-way platforms
    img = Image.new('RGBA', (16, 8), (66, 70, 94, 255))
    d = ImageDraw.Draw(img)
    d.line([(0, 0), (15, 0)], fill=(232, 150, 90, 255))
    d.line([(0, 1), (15, 1)], fill=(130, 110, 112, 255))
    d.line([(0, 7), (15, 7)], fill=(34, 36, 52, 255))
    d.line([(7, 2), (7, 6)], fill=(34, 36, 52, 255))
    d.point((3, 4), fill=(90, 94, 120, 255)); d.point((11, 5), fill=(46, 48, 68, 255))
    return img

FLAME = [  # 4 frames, 14x22, drawn from row strings: . transparent, r red-orange, o orange, y yellow, w white-hot
 ["......rr......", ".....rrrr.....", ".....rorr.....", "....rroorr....", "....roooor....", "...rroooorr...", "...roooyoor...", "..rooyyyoor...", "..rooyyyyoor..", "..rooyywyoor..", "..rooyywwyor..", "..rrooywwyor..", "...rooyywyor..", "...rrooyyoor..", "....rrooooor..", "....rrrooorr..", ".....rrrrrr..."],
 [".......r......", "......rrr.....", ".....rrorr....", ".....rooor....", "....rroooor...", "....roooooor..", "...rroooyoor..", "...rooyyyoor..", "..rooyyyyoor..", "..rooyywyoor..", "..rrooywwyor..", "...rooywwyor..", "...rooyywyor..", "...rrooyyoor..", "....rrooooor..", "....rrrooorr..", ".....rrrrrr..."],
 ["....r.........", ".....rr.......", ".....rorr.....", "....rrooor....", "....rooooor...", "...rroooooor..", "...roooyyoor..", "..rooyyyyoor..", "..rooyyyyoor..", "..rooyywyoor..", "..rrooywyyor..", "..rrooywwyor..", "...rooyywyor..", "...rrooyyoor..", "....rrooooor..", "....rrrooorr..", ".....rrrrrr..."],
 ["......r.......", ".....rrr......", "....rrorr.....", "....rooor.....", "...rroooor....", "...rooooor....", "..rrooyyoor...", "..rooyyyoor...", "..rooyyyyoor..", "..rooyywyoor..", "..rrooywyyor..", "...rooywwyor..", "...rooyywyor..", "...rrooyyoor..", "....rrooooor..", "....rrrooorr..", ".....rrrrrr..."],
]
FLAME_COL = {'r': (200, 50, 28, 255), 'o': (250, 130, 40, 255), 'y': (255, 200, 80, 255), 'w': (255, 244, 200, 255)}

def flame_frame(rows):
    img = Image.new('RGBA', (14, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in FLAME_COL: img.putpixel((x, y), FLAME_COL[ch])
    return img

def glow():
    size = 96
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            dist = math.hypot(x - size / 2, y - size / 2) / (size / 2)
            if dist < 1:
                a = (1 - dist) ** 2
                px[x, y] = (255, 150, 60, int(200 * a))
    return img

def main():
    os.makedirs(OUT, exist_ok=True)
    made = {
        'layer_far': layer_far(), 'layer_mid_far': layer_mid_far(), 'layer_mid': layer_mid(), 'layer_near': layer_near(),
        'fog': fog(), 'ground_tile': ground_tile(), 'ledge_tile': ledge_tile(), 'glow': glow(),
    }
    for i, rows in enumerate(FLAME):
        made['flame_%d' % i] = flame_frame(rows)
    for name, im in made.items():
        im.save(os.path.join(OUT, name + '.png'))
    if '--preview' in sys.argv:
        path = sys.argv[sys.argv.index('--preview') + 1]
        W = 468
        scene = Image.new('RGBA', (W, H), (0, 0, 0, 255))
        for name, scale in (('layer_far', 1), ('layer_mid_far', 1), ('layer_mid', 1), ('layer_near', 1)):
            im = made[name]
            for x in range(0, W, im.size[0]):
                scene.alpha_composite(im, (x, 0))
        for x in range(0, W, 384):
            scene.alpha_composite(made['fog'], (x, 130))
        d = ImageDraw.Draw(scene)
        for x in range(0, W, 32):
            scene.alpha_composite(made['ground_tile'], (x, GROUND_Y))
            scene.alpha_composite(made['ground_tile'], (x, GROUND_Y + 16))
        for cx in (96, 352):
            scene.alpha_composite(made['glow'], (cx - 48, 112))
            scene.alpha_composite(made['glow'], (cx - 48, 112))
            scene.alpha_composite(made['flame_0'], (cx - 7, 143))
        scene.resize((W * 3, H * 3), Image.NEAREST).convert('RGB').save(path)
    print('wrote', OUT)

if __name__ == '__main__':
    main()
