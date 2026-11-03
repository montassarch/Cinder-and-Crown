# Draws the five weapon icons as 32x32 pixel art (diagonal, lit from the top left, dark outline), for weapon pickups.
#   python3 game/tools/art/weapon_icons.py
# Output: game/art/weapon_icons/<weapon>.png
from PIL import Image, ImageDraw
import math, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'art', 'weapon_icons')
INK = (12, 8, 18, 255)
STEEL_L, STEEL, STEEL_D = (236, 236, 244, 255), (168, 172, 188, 255), (96, 100, 120, 255)
GOLD, GOLD_D = (232, 186, 78, 255), (150, 104, 36, 255)
WOOD, WOOD_D = (150, 98, 56, 255), (92, 58, 34, 255)
LEATHER = (80, 46, 40, 255)
RUBY = (220, 40, 60, 255)
EMBER = (255, 150, 40, 255)
VIOLET, VIOLET_L = (140, 80, 230, 255), (210, 180, 255, 255)
IRON, IRON_L, IRON_D = (110, 116, 134, 255), (170, 176, 196, 255), (58, 60, 74, 255)


def line(d, a, b, col, w=1):
    d.line([a, b], fill=col, width=w)


def outline(img):
    src = img.load(); out = img.copy(); dst = out.load()
    for y in range(32):
        for x in range(32):
            if src[x, y][3] == 0 and any(0 <= x + dx < 32 and 0 <= y + dy < 32 and src[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[x, y] = INK
    return out


def sword(d):
    for i in range(16):                                   # blade from the guard up to the tip (bottom-left to top-right)
        x, y = 10 + i, 21 - i
        d.point((x, y), STEEL_L); d.point((x + 1, y), STEEL); d.point((x + 1, y + 1), STEEL_D)
    d.point((26, 5), STEEL_L)
    line(d, (6, 18), (13, 25), GOLD, 2)                    # crossguard
    line(d, (7, 18), (13, 24), GOLD_D)
    line(d, (5, 26), (9, 22), LEATHER, 2)                  # grip
    d.rectangle((3, 27, 4, 28), fill=RUBY)                 # pommel gem


def spear(d):
    line(d, (3, 28), (21, 10), WOOD, 2)                    # shaft
    line(d, (4, 28), (21, 11), WOOD_D)
    d.polygon([(20, 8), (26, 3), (24, 10), (21, 13)], fill=STEEL)   # leaf head
    line(d, (21, 10), (26, 3), STEEL_L)
    d.rectangle((19, 11, 20, 12), fill=GOLD)               # socket
    d.point((18, 13), EMBER); d.point((19, 13), EMBER)    # ember ribbon


def bow(d):
    pts = [(9 + 14 * math.sin(math.radians(a)) * 0.55, 16 - 13 * math.cos(math.radians(a))) for a in range(0, 181, 15)]
    for a, b in zip(pts, pts[1:]):
        line(d, a, b, WOOD, 2)
    line(d, (9, 3), (9, 29), (220, 220, 210, 255))         # string
    d.rectangle((15, 14, 17, 18), fill=GOLD_D)             # grip
    line(d, (4, 16), (27, 16), WOOD_D)                     # nocked arrow
    d.polygon([(27, 14), (30, 16), (27, 18)], fill=(150, 240, 130, 255))
    d.point((4, 15), (230, 230, 230, 255)); d.point((4, 17), (230, 230, 230, 255))


def wand(d):
    line(d, (5, 27), (19, 13), (70, 64, 70, 255), 2)       # ash-dark staff
    line(d, (4, 28), (8, 24), LEATHER, 2)
    line(d, (18, 15), (22, 11), GOLD, 2)                   # claws
    d.polygon([(23, 4), (27, 8), (24, 13), (20, 9)], fill=VIOLET)   # crystal
    d.polygon([(23, 4), (24, 13), (20, 9)], fill=VIOLET_L)
    d.point((26, 3), (255, 255, 255, 255)); d.point((28, 5), VIOLET_L)


def gauntlet(d):
    d.rectangle((6, 14, 15, 24), fill=IRON)                # vambrace
    d.rectangle((6, 14, 15, 15), fill=IRON_L)
    d.rectangle((15, 10, 25, 22), fill=IRON)               # fist
    d.rectangle((15, 10, 25, 11), fill=IRON_L)
    d.rectangle((24, 11, 26, 21), fill=GOLD)               # knuckle plate
    for y in (12, 16, 20):                                 # spikes
        d.polygon([(26, y - 1), (29, y), (26, y + 1)], fill=STEEL_L)
    line(d, (8, 19), (13, 19), EMBER); line(d, (17, 15), (22, 15), EMBER)   # glowing runes
    d.rectangle((6, 23, 15, 24), fill=IRON_D)


ICONS = {'sword': sword, 'spear': spear, 'bow': bow, 'wand': wand, 'gauntlet': gauntlet}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name, draw in ICONS.items():
        img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        draw(ImageDraw.Draw(img))
        outline(img).save(os.path.join(OUT, name + '.png'))
        print('icon', name)
