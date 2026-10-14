# SPIKE: draws the hero sprite sheet procedurally from moving parts.
# Run: python3 game/tools/art/hero_sheet.py  ->  game/art/hero/hero_sheet.png
# Layout (64x64 cells, feet on y=58, hip at x=26):
#   row 0 idle x8 | row 1 run x8 | row 2 jump, fall, hurt | row 3 attack x4 | row 4 roll x4
from PIL import Image, ImageDraw
import math, random, sys

P = {
 'K': (13, 9, 12), 'D': (34, 24, 28), 'd': (52, 36, 42), 'm': (66, 46, 50), 'r': (92, 20, 26),
 'A': (42, 40, 48), 'a': (72, 68, 80), 'B': (214, 182, 118), 'b': (140, 110, 70),
 'L': (86, 58, 44), 'l': (112, 78, 58), 'F': (60, 40, 32),
 'S': (178, 136, 110), 's': (118, 80, 66), 'H': (22, 16, 20),
 'E': (255, 130, 50), 'e': (200, 70, 30), 'W': (96, 92, 104), 'w': (170, 164, 176), 'T': (190, 176, 150),
}
CW, CH, GROUND, HIP_Y = 64, 64, 58, 38

def frame(bob=0.0, lean=0.0, near_foot=(0, 20), far_foot=(0, 20), cloak_phase=0.0, cloak_trail=0.0,
          sword_angle=62.0, back_arm=0.0, flicker=0, grip=(33, 32)):
    img = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    g = ImageDraw.Draw(img)
    hip = (26.0, HIP_Y + bob)

    def up(x, y):
        """Upper-body point (authored with hip at (26,38)); applies bob and lean."""
        y2 = y + bob
        return (x + lean * (HIP_Y - y) / 22.0, y2)
    def poly(pts, c, upper=True):
        g.polygon([up(*p) if upper else p for p in pts], fill=P[c])
    def line(a, b, c, w=1, upper=True):
        if upper: a, b = up(*a), up(*b)
        g.line([a, b], fill=P[c], width=w)
    def px(x, y, c, upper=True):
        x, y = up(x, y) if upper else (x, y)
        if 0 <= x < CW and 0 <= y < CH: img.putpixel((int(round(x)), int(round(y))), P[c] + (255,))

    def leg(foot_off, thigh_c, shin_c, boot_c):
        fx, fy = hip[0] + foot_off[0], hip[1] + foot_off[1]
        fy = min(fy, GROUND - 3)
        L = 11.0
        dx, dy = fx - hip[0], fy - hip[1]
        d = min(math.hypot(dx, dy), 2 * L - 0.01)
        base = math.atan2(dy, dx)
        off = math.acos(d / (2 * L))
        knees = [(hip[0] + L * math.cos(base + s * off), hip[1] + L * math.sin(base + s * off)) for s in (-1, 1)]
        knee = max(knees, key=lambda k: k[0])            # knees bend forward
        g.line([hip, knee], fill=P[thigh_c], width=4)
        g.line([knee, (fx, fy)], fill=P[shin_c], width=3)
        g.ellipse((knee[0]-1.5, knee[1]-1.5, knee[0]+1.5, knee[1]+1.5), fill=P['a'])
        g.polygon([(fx-2, fy-1), (fx+4, fy-1), (fx+5, fy+2), (fx-2, fy+2)], fill=P[boot_c])

    # cloak: anchored at the shoulders, hem ripples and trails behind
    hem = []
    for i in range(8):
        t = i / 7.0
        x = 22 - 4 - t * 12 - cloak_trail * (0.4 + t) * 6
        y = 58 - abs(math.sin(cloak_phase + i * 1.3)) * 2 - cloak_trail * t * 7 + (i % 2) * 3
        hem.append((x, y))
    cloak = [(22, 18), (17, 22), (14, 30)] + list(reversed(hem)) + [(22, 40), (23, 26)]
    poly(cloak, 'D')
    line((18, 24), (hem[3][0], hem[3][1] - 4), 'd')
    line((20, 26), (hem[1][0], hem[1][1] - 4), 'd')
    for j, (x, y) in enumerate(hem[::2]):
        px(x + 1, y - 1, 'e' if (j + flicker) % 2 else 'r')

    leg(far_foot, 'F', 'F', 'K')                          # far leg, shaded darker

    # back arm swings opposite the near leg
    sh = (22, 23); hand = (22 + back_arm * 5, 34)
    line(sh, hand, 'A', 3); px(hand[0], hand[1] + 1, 'S'); px(hand[0], hand[1], 'T')

    # torso, skirt, belt, pouch
    poly([(21, 21), (29, 21), (28, 33), (22, 33)], 'A')
    for y in (24, 27, 30):
        line((24, y), (27, y), 'B'); line((22, y), (23, y), 'b')
    poly([(21, 33), (29, 33), (30, 40), (20, 40)], 'L')
    line((21, 36), (29, 36), 'l')
    line((21, 33), (29, 33), 'b'); px(25, 33, 'B')
    poly([(28, 34), (31, 34), (31, 37), (28, 37)], 'b')

    leg(near_foot, 'L', 'L', 'K')                         # near leg on top

    # mantle over the shoulders
    poly([(19, 17), (31, 17), (33, 21), (32, 25), (30, 23), (29, 26), (27, 23), (25, 26), (23, 23), (21, 25), (19, 22)], 'm')
    line((20, 18), (30, 18), 'd')

    # head
    poly([(24, 10), (28, 10), (28, 15), (25, 16)], 'S')
    line((25, 11), (27, 14), 's')
    px(27, 12, 'E' if flicker % 2 == 0 else 'e'); px(28, 12, 'e')
    poly([(22, 8), (28, 8), (28, 10), (26, 10), (24, 13), (23, 15), (22, 12)], 'H')
    for a, b in [((22, 8), (21, 6)), ((24, 8), (24, 6)), ((26, 8), (27, 6)), ((28, 9), (29, 8)), ((22, 10), (20, 10)), ((22, 12), (21, 14))]:
        line(a, b, 'H')
    line((24, 16), (27, 16), 's')

    # front arm to the grip, then the greatsword hanging forward-down
    shoulder = (29, 22)
    line(shoulder, grip, 'a', 3)
    gx, gy = up(*grip)
    rad = math.radians(sword_angle)
    dx, dy = math.cos(rad), math.sin(rad)
    nx, ny = -dy, dx
    base = (gx + dx * 2, gy + dy * 2)
    tip = (gx + dx * 30, gy + dy * 30)
    g.polygon([(base[0] + nx * 2, base[1] + ny * 2), (base[0] - nx * 2, base[1] - ny * 2),
               (tip[0] - nx * 1.5, tip[1] - ny * 1.5), (tip[0] + nx * 1, tip[1] + ny * 1)], fill=P['W'])
    g.line([(base[0] - nx * 2, base[1] - ny * 2), (tip[0] - nx * 1.5, tip[1] - ny * 1.5)], fill=P['w'])
    for k in range(6):
        t = 5 + k * 4
        ex, ey = gx + dx * t + nx * 0.5, gy + dy * t + ny * 0.5
        if 0 <= ex < CW and 0 <= ey < CH:
            img.putpixel((int(ex), int(ey)), P['E' if (k + flicker) % 2 else 'e'] + (255,))
    g.line([(gx - nx * 3, gy - ny * 3), (gx + nx * 3, gy + ny * 3)], fill=P['B'])
    g.ellipse((gx - 1.5, gy - 1.5, gx + 1.5, gy + 1.5), fill=P['S'])

    # 1px outline
    src = img.copy()
    for y in range(CH):
        for x in range(CW):
            if src.getpixel((x, y))[3] == 0:
                for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx2, ny2 = x + ddx, y + ddy
                    if 0 <= nx2 < CW and 0 <= ny2 < CH and src.getpixel((nx2, ny2))[3]:
                        img.putpixel((x, y), P['K'] + (255,)); break
    return img


RUN_FEET = [(7, 20), (4, 20), (0, 20), (-5, 19), (-9, 15), (-6, 11), (0, 12), (6, 16)]
RUN_BOB = [0, 1, 0, -1, 0, 1, 0, -1]

def rows():
    idle = []
    for i in range(8):
        breath = (1 - math.cos(i * math.pi / 4)) / 2
        idle.append(frame(bob=round(breath), near_foot=(5, 20), far_foot=(-5, 20), cloak_phase=i * math.pi / 4,
                          cloak_trail=0.05 + 0.05 * math.sin(i * math.pi / 4),
                          sword_angle=62 + 1.5 * math.sin(i * math.pi / 4), flicker=i // 2))
    run = []
    for i in range(8):
        run.append(frame(bob=RUN_BOB[i], lean=3.0, near_foot=RUN_FEET[i], far_foot=RUN_FEET[(i + 4) % 8],
                         cloak_phase=i * math.pi / 4, cloak_trail=0.6 + 0.15 * math.sin(i * math.pi / 4),
                         sword_angle=48 + 4 * math.sin(i * math.pi / 4), back_arm=-math.sin(i * math.pi / 4) * 0.9,
                         flicker=i))
    air = [
        frame(bob=-1, lean=2.0, near_foot=(4, 13), far_foot=(-5, 16), cloak_phase=0.5, cloak_trail=0.9,
              sword_angle=40, back_arm=-0.6),                                    # jump (rising, legs tucked)
        frame(bob=0, lean=1.0, near_foot=(5, 18), far_foot=(-3, 17), cloak_phase=2.0, cloak_trail=-0.2,
              sword_angle=55, back_arm=0.5),                                     # fall (cloak lifts)
        frame(bob=1, lean=-3.0, near_foot=(3, 20), far_foot=(-6, 20), cloak_phase=1.0, cloak_trail=0.4,
              sword_angle=75, back_arm=-0.8),                                    # hurt (recoil)
    ]
    attack = [
        frame(bob=0, lean=-2.0, near_foot=(6, 20), far_foot=(-6, 20), cloak_trail=0.1, sword_angle=-155, grip=(28, 22), back_arm=0.6),
        frame(bob=1, lean=1.0, near_foot=(7, 20), far_foot=(-6, 20), cloak_trail=0.3, sword_angle=-35, grip=(31, 21), back_arm=0.2),
        frame(bob=1, lean=4.0, near_foot=(8, 20), far_foot=(-7, 20), cloak_trail=0.6, sword_angle=5, grip=(35, 27), back_arm=-0.6),
        frame(bob=1, lean=4.0, near_foot=(8, 20), far_foot=(-7, 20), cloak_trail=0.5, sword_angle=40, grip=(35, 30), back_arm=-0.8),
    ]
    roll = [
        frame(bob=3, lean=5.0, near_foot=(6, 17), far_foot=(-4, 17), cloak_trail=0.8, sword_angle=20, back_arm=-0.5),
        frame(bob=6, lean=7.0, near_foot=(4, 14), far_foot=(-2, 14), cloak_trail=1.0, sword_angle=5, back_arm=0.0),
        frame(bob=6, lean=7.0, near_foot=(1, 14), far_foot=(3, 14), cloak_trail=1.0, sword_angle=0, back_arm=0.3),
        frame(bob=3, lean=4.0, near_foot=(5, 17), far_foot=(-5, 18), cloak_trail=0.7, sword_angle=30, back_arm=-0.3),
    ]
    return [idle, run, air, attack, roll]

if __name__ == '__main__':
    import os
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', '..', 'art', 'hero', 'hero_sheet.png')
    sheet = Image.new('RGBA', (CW * 8, CH * 5), (0, 0, 0, 0))
    for r, row in enumerate(rows()):
        for c, f in enumerate(row):
            sheet.alpha_composite(f, (c * CW, r * CH))
    sheet.save(out)
    print('wrote', out)
