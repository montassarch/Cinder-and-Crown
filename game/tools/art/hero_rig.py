# SPIKE v2: the hero as a 2D skeleton, keyframed and interpolated, drawn as pixel art.
# Dead Cells-style approach in miniature: pose a rig, render every frame crisp.
#   python3 game/tools/art/hero_rig.py [out.png] [--preview DIR]
# Sheet: 112x96 cells, feet on y=90, body anchored at x=44. One row per animation (see ANIMS).
from PIL import Image, ImageDraw
import math, sys, os

P = {
 'K': (13, 9, 12), 'D': (34, 24, 28), 'd': (52, 36, 42), 'm': (66, 46, 50), 'r': (92, 20, 26),
 'A': (42, 40, 48), 'a': (72, 68, 80), 'B': (214, 182, 118), 'b': (140, 110, 70),
 'L': (86, 58, 44), 'l': (112, 78, 58), 'F': (58, 40, 32), 'f': (74, 52, 40),
 'S': (178, 136, 110), 's': (118, 80, 66), 'H': (22, 16, 20),
 'E': (255, 130, 50), 'e': (200, 70, 30), 'W': (96, 92, 104), 'w': (176, 170, 182), 'T': (190, 176, 150),
 'X': (236, 222, 196), 'x': (150, 120, 96),
}
CW, CH, FEET_X, GROUND = 112, 96, 44, 90
THIGH, SHIN, TORSO, UPPER, FORE, BLADE = 11, 11, 14, 8, 8, 30

def d(a):
    """Unit vector for an angle in degrees: 0 points down, +90 forward (right), 180 up."""
    r = math.radians(a)
    return (math.sin(r), math.cos(r))

def add(p, v, k=1.0): return (p[0] + v[0] * k, p[1] + v[1] * k)

def lerp(a, b, t): return a + (b - a) * t

def smooth(t): return t * t * (3 - 2 * t)

def catmull(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return 0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)

def sample_loop(keys, t):
    """keys: [(t, value)] over [0,1); smooth periodic Catmull-Rom interpolation."""
    n = len(keys)
    for i in range(n):
        t0, v0 = keys[i]
        t1, v1 = keys[(i + 1) % n]
        span = (t1 - t0) % 1.0 or 1.0
        local = ((t - t0) % 1.0) / span
        if local <= 1.0 and ((t - t0) % 1.0) <= span:
            vm = keys[(i - 1) % n][1]
            vp = keys[(i + 2) % n][1]
            return catmull(vm, v0, v1, vp, local)
    return keys[0][1]

# ---------------------------------------------------------------- pose -> joints
def joints(pose):
    """pose: dict of angles. Returns joint positions with the pelvis at (0,0)."""
    j = {'pelvis': (0.0, 0.0)}
    s = pose.get('spine', 0.0)
    up = (math.sin(math.radians(s)), -math.cos(math.radians(s)))
    j['up'] = up
    j['chest'] = add(j['pelvis'], up, 8)
    j['shoulder'] = add(j['pelvis'], up, 12)
    j['neck'] = add(j['pelvis'], up, TORSO)
    j['head'] = add(j['neck'], up, 4.5)
    for side in ('near', 'far'):
        h, k = pose[side + '_hip'], pose[side + '_knee']
        hip = add(j['pelvis'], (1.0 if side == 'near' else -1.0, 0))
        knee = add(hip, d(h), THIGH)
        ankle = add(knee, d(h - k), SHIN)
        toe = add(ankle, d(h - k + 90 - pose.get(side + '_foot', 0)), 4)
        j[side + '_hipj'], j[side + '_kneej'], j[side + '_ankle'], j[side + '_toe'] = hip, knee, ankle, toe
        a1, a2 = pose[side + '_arm'], pose[side + '_elbow']
        sh = add(j['shoulder'], (1.5 if side == 'near' else -1.5, 0))
        el = add(sh, d(a1), UPPER)
        hand = add(el, d(a2), FORE)
        j[side + '_sh'], j[side + '_el'], j[side + '_hand'] = sh, el, hand
    j['sword'] = pose['sword']
    return j

def rotate_all(j, pivot, deg):
    r = math.radians(deg); c, s_ = math.cos(r), math.sin(r)
    out = {}
    for k, v in j.items():
        if isinstance(v, tuple) and k != 'up':
            x, y = v[0] - pivot[0], v[1] - pivot[1]
            out[k] = (pivot[0] + x * c - y * s_, pivot[1] + x * s_ + y * c)
        else:
            out[k] = v
    out['up'] = (j['up'][0] * c - j['up'][1] * s_, j['up'][0] * s_ + j['up'][1] * c)
    out['sword'] = j['sword'] - deg
    return out

# ---------------------------------------------------------------- cloak cloth
class Cloak:
    """A hanging chain of points pinned at the upper back; verlet with gravity and wind."""
    N, SEG = 7, 5.6
    def __init__(self, anchor):
        self.p = [(anchor[0] - i * 0.5, anchor[1] + i * self.SEG) for i in range(self.N)]
        self.o = list(self.p)
    def step(self, anchor, wind=(0.0, 0.0), dt=1.0):
        g = (wind[0], 0.55 + wind[1])
        for i in range(1, self.N):
            x, y = self.p[i]; ox, oy = self.o[i]
            nx, ny = x + (x - ox) * 0.86 + g[0] * dt, y + (y - oy) * 0.86 + g[1] * dt
            self.o[i] = (x, y); self.p[i] = (nx, ny)
        self.p[0] = anchor; self.o[0] = anchor
        for _ in range(6):
            for i in range(1, self.N):
                ax, ay = self.p[i - 1]; bx, by = self.p[i]
                dx, dy = bx - ax, by - ay
                dist = math.hypot(dx, dy) or 1e-6
                k = (dist - self.SEG) / dist
                if i - 1 == 0:
                    self.p[i] = (bx - dx * k, by - dy * k)
                else:
                    self.p[i - 1] = (ax + dx * k * 0.5, ay + dy * k * 0.5)
                    self.p[i] = (bx - dx * k * 0.5, by - dy * k * 0.5)
            for i in range(1, self.N):          # cloak can't pass through the ground
                x, y = self.p[i]
                if y > GROUND - 1: self.p[i] = (x, GROUND - 1)

# ---------------------------------------------------------------- drawing
def render(j, origin, cloak_pts=None, smear=None, flicker=0, hair_wind=0.0):
    img = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    g = ImageDraw.Draw(img)
    ox, oy = origin
    def T(p): return (p[0] + ox, p[1] + oy)
    def line(a, b, c, w=1): g.line([T(a), T(b)], fill=P[c], width=w)
    def poly(pts, c): g.polygon([T(p) for p in pts], fill=P[c])
    def dot(p, r, c):
        x, y = T(p); g.ellipse((x - r, y - r, x + r, y + r), fill=P[c])
    def px(p, c):
        x, y = T(p)
        if 0 <= x < CW and 0 <= y < CH: img.putpixel((int(round(x)), int(round(y))), P[c] + (255,))
    up = j['up']; right = (-up[1], up[0])

    # cloak ribbon
    if cloak_pts:
        left_edge, right_edge = [], []
        n = len(cloak_pts)
        for i, p in enumerate(cloak_pts):
            a = cloak_pts[max(i - 1, 0)]; b = cloak_pts[min(i + 1, n - 1)]
            tx, ty = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(tx, ty) or 1
            nx, ny = -ty / ln, tx / ln
            w = lerp(3.0, 7.5, i / (n - 1))
            left_edge.append((p[0] + nx * w, p[1] + ny * w)); right_edge.append((p[0] - nx * w, p[1] - ny * w))
        last = cloak_pts[-1]
        hem = []
        for k in range(7):                      # ragged burned hem
            t = k / 6
            hx = lerp(right_edge[-1][0], left_edge[-1][0], t); hy = lerp(right_edge[-1][1], left_edge[-1][1], t)
            hem.append((hx, hy + (2.5 if k % 2 else 0)))
        poly(left_edge + hem[::-1][:0] + list(reversed(right_edge)), 'D')
        poly([right_edge[-1]] + hem + [left_edge[-1]], 'D')
        for i in range(1, n - 1):
            line(cloak_pts[i], cloak_pts[i + 1], 'd')
        for k, hp in enumerate(hem[1::2]):
            px((hp[0], hp[1] - 1), 'e' if (k + flicker) % 2 else 'r')

    def leg(side, thigh_c, shin_c):
        hip, knee, ankle, toe = j[side + '_hipj'], j[side + '_kneej'], j[side + '_ankle'], j[side + '_toe']
        line(hip, knee, thigh_c, 4); dot(knee, 1.6, thigh_c)
        line(knee, ankle, shin_c, 3)
        dot(knee, 1.3, 'a' if side == 'near' else 'A')
        line(ankle, toe, 'K', 3); dot(ankle, 1.6, 'K')
        line(add(ankle, d(0), -2.5), add(toe, d(0), -2.5), 'A' if side == 'near' else 'K', 1)

    def arm(side, col):
        sh, el, hand = j[side + '_sh'], j[side + '_el'], j[side + '_hand']
        line(sh, el, col, 3); dot(el, 1.3, col)
        line(el, hand, col, 3)
        mid = add(el, ((hand[0] - el[0]) * 0.5, (hand[1] - el[1]) * 0.5))
        dot(mid, 1.0, 'T')
        dot(hand, 1.4, 'S')

    def sword():
        hand = j['near_hand']; a = j['sword']
        v = d(a); n = (-v[1], v[0])
        line(add(hand, v, -3), add(hand, v, 1), 'b', 2)               # grip
        line(add(add(hand, v, 1.5), n, 3.5), add(add(hand, v, 1.5), n, -3.5), 'B', 1)   # crossguard
        base = add(hand, v, 2.5); tip = add(hand, v, BLADE)
        poly([add(base, n, 2.2), add(base, n, -2.2), add(tip, n, -1.0), add(tip, n, 0.6)], 'W')
        line(add(base, n, -2.2), add(tip, n, -1.0), 'w')
        for k in range(5):
            t = 6 + k * 5
            px(add(add(hand, v, t), n, 0.3), 'E' if (k + flicker) % 2 else 'e')
        for k in range(4):
            t = 8 + k * 6
            px(add(add(hand, v, t), n, 2.4), 'K')
        dot(hand, 1.5, 'S')

    leg('far', 'F', 'f')
    arm('far', 'A')
    # torso: waist to chest, bands
    pel, sh = j['pelvis'], j['shoulder']
    poly([add(pel, right, 3.5), add(pel, right, -3.0), add(sh, right, -4.5), add(sh, right, 5.0)], 'A')
    for k, t in enumerate((0.35, 0.6, 0.85)):
        c = add(pel, up, 12 * t)
        line(add(c, right, 0.5), add(c, right, 3.5), 'B'); line(add(c, right, -2.5), add(c, right, -0.5), 'b')
    # tunic skirt and belt
    poly([add(pel, right, 4), add(pel, right, -3.5), add(add(pel, up, -6), right, -4.5), add(add(pel, up, -6), right, 5)], 'L')
    line(add(pel, right, 4), add(pel, right, -3.5), 'b'); px(add(pel, right, 1), 'B')
    line(add(add(pel, up, -3), right, 3), add(add(pel, up, -3), right, -3), 'l')
    leg('near', 'L', 'l')
    # mantle over the shoulders, ragged
    m_top = add(sh, up, 1.5)
    rag = [add(add(sh, up, -6), right, x) for x in (7, 5, 3, 1, -1, -3, -5, -6)]
    rag = [add(p, up, (1.5 if i % 2 else 0)) for i, p in enumerate(rag)]
    poly([add(m_top, right, -6), add(m_top, right, 7)] + rag, 'm')
    line(add(m_top, right, -5), add(m_top, right, 6), 'd')
    # head
    hc = j['head']
    face = [add(add(hc, right, 0), up, 3), add(add(hc, right, 4), up, 3), add(add(hc, right, 4), up, -2.5), add(add(hc, right, 1), up, -3.5)]
    poly(face, 'S')
    line(add(add(hc, right, 1), up, 2), add(add(hc, right, 3), up, -1), 's')
    px(add(add(hc, right, 3.2), up, 1), 'E' if flicker % 3 else 'e')
    hair = [add(add(hc, right, -3.5), up, 5), add(add(hc, right, 4), up, 5), add(add(hc, right, 4), up, 3.2), add(add(hc, right, 1.5), up, 3),
            add(add(hc, right, 0), up, 0), add(add(hc, right, -0.5), up, -3), add(add(hc, right, -3.5), up, -1)]
    poly(hair, 'H')
    for bx, by, l in ((-3.5, 5, 3), (-1, 5.5, 3), (1.5, 5.5, 3), (3.5, 5, 2), (-3.5, 2, 3), (-3, -1, 3)):
        base = add(add(hc, right, bx), up, by)
        tipv = add(add(base, up, 1.2 if by > 3 else 0), right, -l - hair_wind)
        line(base, tipv, 'H')
    line(add(add(hc, right, 1), up, -3.8), add(add(hc, right, 3.5), up, -3), 's')
    arm('near', 'a')
    sword()

    src = img.copy()
    for y in range(CH):
        for x in range(CW):
            if src.getpixel((x, y))[3] == 0:
                for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx2, ny2 = x + ddx, y + ddy
                    if 0 <= nx2 < CW and 0 <= ny2 < CH and src.getpixel((nx2, ny2))[3]:
                        img.putpixel((x, y), P['K'] + (255,)); break
    if smear:
        # Dead Cells-style smear: a bright translucent crescent along the blade's path.
        layer = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
        lg = ImageDraw.Draw(layer)
        hand = j['near_hand']; a0, a1 = smear
        steps = 12
        outer = [T(add(hand, d(lerp(a0, a1, k / steps)), BLADE + 1)) for k in range(steps + 1)]
        inner = [T(add(hand, d(lerp(a0, a1, k / steps)), BLADE - 7 - 5 * (k / steps))) for k in range(steps + 1)]
        lg.polygon(outer + inner[::-1], fill=(236, 222, 196, 150))
        lg.line(outer, fill=(255, 246, 228, 235), width=2)
        img.alpha_composite(layer)
    return img

def ground_origin(j):
    """Shift so the lowest foot point rests on the ground line."""
    low = max(j['near_ankle'][1] + 1.5, j['near_toe'][1] + 1.5, j['far_ankle'][1] + 1.5, j['far_toe'][1] + 1.5)
    return (FEET_X, GROUND - low)

# ---------------------------------------------------------------- animations
BASE = dict(spine=4, near_hip=12, near_knee=6, far_hip=-12, far_knee=8,
            near_arm=18, near_elbow=40, far_arm=-6, far_elbow=8, sword=62)

def blend(a, b, t):
    out = dict(a)
    for k in b: out[k] = lerp(a.get(k, b[k]), b[k], t)
    return out

def anim_idle(n=10):
    frames, cloak = [], None
    for warm in range(2):
        for i in range(n):
            t = i / n
            br = (1 - math.cos(t * 2 * math.pi)) / 2
            pose = dict(BASE, spine=4 + br * 1.5, near_arm=18 + br * 2, near_elbow=40 + br * 3, far_arm=-6 + br * 3,
                        near_knee=6 + br * 4, far_knee=8 + br * 4, sword=62 + br * 2)
            j = joints(pose); o = ground_origin(j)
            anchor = add(add(j['shoulder'], j['up'], -1), (-3, 0)); anchor = (anchor[0] + o[0], anchor[1] + o[1])
            cloak = cloak or Cloak(anchor)
            cloak.step(anchor, wind=(-0.05 - 0.05 * math.sin(t * 2 * math.pi), 0))
            if warm: frames.append(render(j, o, [(p[0] - o[0], p[1] - o[1]) for p in cloak.p], flicker=i // 2, hair_wind=0.3 * br))
    return frames

RUN_NEAR_HIP = [(0.00, 40), (0.10, 26), (0.25, 2), (0.40, -30), (0.50, -40), (0.65, -16), (0.80, 32), (0.92, 48)]
RUN_NEAR_KNEE = [(0.00, 6), (0.10, 28), (0.25, 16), (0.40, 6), (0.50, 40), (0.65, 105), (0.80, 85), (0.92, 22)]
def anim_run(n=12):
    frames, cloak = [], None
    for warm in range(3):
        for i in range(n):
            t = i / n
            nh, nk = sample_loop(RUN_NEAR_HIP, t), max(0, sample_loop(RUN_NEAR_KNEE, t))
            fh, fk = sample_loop(RUN_NEAR_HIP, (t + 0.5) % 1), max(0, sample_loop(RUN_NEAR_KNEE, (t + 0.5) % 1))
            swing = math.sin(t * 2 * math.pi)
            pose = dict(spine=14 + 2 * math.sin(t * 4 * math.pi), near_hip=nh, near_knee=nk, far_hip=fh, far_knee=fk,
                        near_foot=-10 if nk > 50 else 0, far_foot=-10 if fk > 50 else 0,
                        near_arm=-28 - 12 * swing, near_elbow=-38 - 12 * swing, far_arm=40 * swing, far_elbow=40 * swing + 70,
                        sword=-72 - 5 * swing)
            j = joints(pose); o = ground_origin(j)
            anchor = add(add(j['shoulder'], j['up'], -1), (-3, 0)); anchor = (anchor[0] + o[0], anchor[1] + o[1])
            cloak = cloak or Cloak(anchor)
            cloak.step(anchor, wind=(-0.9, -0.12))
            if warm == 2: frames.append(render(j, o, [(p[0] - o[0], p[1] - o[1]) for p in cloak.p], flicker=i, hair_wind=2.0))
    return frames

def keyed(keys, wind, smear_frames=(), origin_override=None):
    """keys: list of poses, one per frame. smear_frames: {frame: (from_angle, to_angle)}"""
    frames = []
    j0 = joints(keys[0]); o0 = ground_origin(j0)
    a0 = add(add(j0['shoulder'], j0['up'], -1), (-3, 0)); cloak = Cloak((a0[0] + o0[0], a0[1] + o0[1]))
    for _ in range(8):
        cloak.step((a0[0] + o0[0], a0[1] + o0[1]), wind=wind[0])
    for i, pose in enumerate(keys):
        j = joints(pose); o = origin_override(i, j) if origin_override else ground_origin(j)
        if 'rot' in pose:
            j = rotate_all(j, (0, -10), pose['rot'])
        anchor = add(add(j['shoulder'], j['up'], -1), (-3, 0)); anchor = (anchor[0] + o[0], anchor[1] + o[1])
        cloak.step(anchor, wind=wind[min(i, len(wind) - 1)])
        cloak.step(anchor, wind=wind[min(i, len(wind) - 1)])
        frames.append(render(j, o, [(p[0] - o[0], p[1] - o[1]) for p in cloak.p], smear=dict(smear_frames).get(i), flicker=i))
    return frames

STANCE = dict(near_hip=24, near_knee=18, far_hip=-22, far_knee=14, far_arm=-20, far_elbow=10)
def anim_slash():                       # 1: diagonal slash over the top, down-forward
    k = [dict(STANCE, spine=-8, near_arm=-140, near_elbow=-165, sword=-122),
         dict(STANCE, spine=-12, near_arm=-150, near_elbow=-176, sword=-134),
         dict(STANCE, spine=12, near_arm=62, near_elbow=82, sword=95, near_hip=30, near_knee=24),
         dict(STANCE, spine=17, near_arm=72, near_elbow=76, sword=58, near_hip=32, near_knee=28),
         dict(STANCE, spine=15, near_arm=58, near_elbow=52, sword=38, near_hip=30, near_knee=26),
         dict(STANCE, spine=9, near_arm=28, near_elbow=36, sword=50),
         dict(BASE, spine=5)]
    return keyed(k, [(-0.1, 0), (-0.1, 0), (-0.6, 0), (-0.5, 0), (-0.3, 0), (-0.2, 0), (-0.1, 0)], {2: (226, 95)})
def anim_uppercut():                    # 2: rising cut from low-front to high
    k = [dict(STANCE, spine=12, near_arm=42, near_elbow=30, sword=22, near_knee=26, far_knee=24),
         dict(STANCE, spine=14, near_arm=34, near_elbow=22, sword=12, near_knee=30, far_knee=28),
         dict(STANCE, spine=-6, near_arm=150, near_elbow=166, sword=172, near_knee=8, far_knee=6),
         dict(STANCE, spine=-11, near_arm=164, near_elbow=176, sword=198, near_knee=6, far_knee=6),
         dict(STANCE, spine=-7, near_arm=150, near_elbow=160, sword=192),
         dict(STANCE, spine=0, near_arm=64, near_elbow=74, sword=112),
         dict(BASE, spine=4)]
    return keyed(k, [(-0.1, 0), (-0.1, 0), (-0.4, 0.4), (-0.3, 0.3), (-0.2, 0), (-0.1, 0), (-0.1, 0)], {2: (12, 172)})
def anim_slam():                        # 3: heavy overhead slam into the ground
    deep = dict(near_hip=34, near_knee=46, far_hip=-34, far_knee=34)
    k = [dict(STANCE, spine=-10, near_arm=166, near_elbow=174, sword=188),
         dict(STANCE, spine=-16, near_arm=184, near_elbow=200, sword=214),
         dict(STANCE, spine=-17, near_arm=186, near_elbow=204, sword=220),
         dict(STANCE, **deep, spine=20, near_arm=84, near_elbow=94, sword=104),
         dict(STANCE, **deep, spine=28, near_arm=62, near_elbow=50, sword=28),
         dict(STANCE, **deep, spine=29, near_arm=60, near_elbow=48, sword=26),
         dict(STANCE, spine=20, near_arm=48, near_elbow=44, sword=32, near_knee=30, far_knee=24),
         dict(STANCE, spine=11, near_arm=28, near_elbow=38, sword=48),
         dict(BASE, spine=5)]
    return keyed(k, [(-0.1, -0.2), (-0.1, -0.3), (-0.1, -0.3), (-0.4, 0.5), (-0.2, 0.2), (-0.1, 0), (-0.1, 0), (-0.1, 0), (-0.1, 0)], {3: (220, 104)})
def anim_roll():                        # tumble: crouch, full turn, rise
    tuck = dict(near_hip=95, near_knee=135, far_hip=80, far_knee=130, near_arm=70, near_elbow=120, far_arm=60, far_elbow=110, sword=-120)
    k = [dict(BASE, spine=30, near_hip=55, near_knee=80, far_hip=30, far_knee=70, near_arm=40, near_elbow=60, sword=-110),
         dict(tuck, spine=40, rot=60), dict(tuck, spine=40, rot=140), dict(tuck, spine=40, rot=220),
         dict(tuck, spine=40, rot=300),
         dict(BASE, spine=26, near_hip=50, near_knee=70, far_hip=20, far_knee=60, near_arm=30, near_elbow=55, sword=-100)]
    def org(i, j):
        if 1 <= i <= 4: return (FEET_X + 2, GROUND - 13)
        return ground_origin(j)
    return keyed(k, [(-0.8, 0)] * 6, origin_override=org)
def anim_air():
    rise = dict(spine=10, near_hip=70, near_knee=95, far_hip=-20, far_knee=50, near_arm=-60, near_elbow=-30, far_arm=60, far_elbow=110, sword=-125)
    apex = dict(spine=8, near_hip=55, near_knee=100, far_hip=20, far_knee=90, near_arm=-40, near_elbow=-10, far_arm=40, far_elbow=90, sword=-115)
    fall = dict(spine=4, near_hip=18, near_knee=20, far_hip=-12, far_knee=35, near_arm=-80, near_elbow=-60, far_arm=80, far_elbow=120, sword=-140)
    hurt = dict(spine=-20, near_hip=14, near_knee=20, far_hip=-30, far_knee=24, near_arm=-50, near_elbow=-70, far_arm=-90, far_elbow=-60, sword=-60)
    air = lambda i, j: (FEET_X, GROUND - 6)
    out = keyed([rise, apex, fall], [(-0.2, 0.9), (-0.2, 0.2), (-0.2, -1.2)], origin_override=air)
    out += keyed([hurt, hurt], [(0.6, 0), (0.4, 0)])
    return out

ANIMS = [('idle', anim_idle), ('run', anim_run), ('slash', anim_slash), ('uppercut', anim_uppercut),
         ('slam', anim_slam), ('roll', anim_roll), ('air', anim_air)]

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else os.path.join(os.path.dirname(__file__), '..', '..', 'art', 'hero', 'hero_sheet.png')
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
    rows = [(name, fn()) for name, fn in ANIMS]
    cols = max(len(r) for _, r in rows)
    sheet = Image.new('RGBA', (CW * cols, CH * len(rows)), (0, 0, 0, 0))
    for r, (name, frames) in enumerate(rows):
        for c, f in enumerate(frames):
            sheet.alpha_composite(f, (c * CW, r * CH))
        print(name, len(frames))
    sheet.save(out)
    if preview:
        os.makedirs(preview, exist_ok=True)
        bg = Image.new('RGBA', sheet.size, (40, 12, 16, 255)); bg.alpha_composite(sheet)
        bg.resize((sheet.size[0] * 2, sheet.size[1] * 2), Image.NEAREST).save(os.path.join(preview, 'sheet.png'))
        for name, frames in rows:
            big = []
            for f in frames:
                c = Image.new('RGBA', f.size, (40, 12, 16, 255)); c.alpha_composite(f)
                big.append(c.convert('RGB').resize((CW * 4, CH * 4), Image.NEAREST))
            ms = {'idle': 110, 'run': 45, 'roll': 55, 'air': 160}.get(name, 55)
            big[0].save(os.path.join(preview, name + '.gif'), save_all=True, append_images=big[1:], duration=ms, loop=0)
    print('wrote', out)
