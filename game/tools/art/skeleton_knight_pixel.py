# Turns the Blender renders (skeleton_knight_render.py) into the game's pixel-art frames.
#   python3 game/tools/art/skeleton_knight_pixel.py <raw_dir> [--preview out.png]
# raw: <raw_dir>/<AnimDir>/<n>.png (800x576).  Output: game/art/skeleton_knight/{plain,masked}/<AnimDir>/SkeletonKnight_<AnimDir>_<n>.png
# Every frame is shrunk 8x (100x72), hard-edged, mapped onto one shared 28-colour palette, and given a dark outline.
# "masked" is the brief hurt flash after a hit (the game swaps to it for a moment): the same frame washed red.
from PIL import Image, ImageEnhance
import glob, json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'art', 'skeleton_knight')
SHRINK = 8
COLOURS = 28
OUTLINE = (10, 6, 16)


def load(path):
    im = Image.open(path).convert('RGBA')
    small = im.resize((im.width // SHRINK, im.height // SHRINK), Image.BOX)
    a = small.getchannel('A').point(lambda v: 255 if v > 96 else 0)
    rgb = small.convert('RGB')
    rgb = ImageEnhance.Contrast(rgb).enhance(1.3)
    rgb = ImageEnhance.Color(rgb).enhance(1.2)
    rgb = ImageEnhance.Brightness(rgb).enhance(1.1)
    return rgb, a


def outline(img):
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    X, Y = x + dx, y + dy
                    if 0 <= X < w and 0 <= Y < h and src[X, Y][3] == 255:
                        dst[x, y] = OUTLINE + (255,)
                        break
    return out


def flash(img):
    red = Image.new('RGBA', img.size, (230, 40, 50, 255))
    washed = Image.blend(img, red, 0.4)
    washed.putalpha(img.getchannel('A'))
    return washed


def write_blades(raw):
    # src/player/hero_blade.gd: where the sword is in each frame (guard x, y, tip x, y), measured in Blender
    path = os.path.join(raw, 'blade.json')
    if not os.path.exists(path):
        return
    data = json.load(open(path))
    anims = {k.lower(): v for k, v in data.items()}
    anims['storm'] = [anims['attack1'][i] for i in (0, 1, 1, 1, 1, 1)]
    anims['rend'] = [anims['attack3'][i] for i in (1, 2, 3, 4, 5, 6)]
    anims['parry'] = [anims['attack3'][i] for i in (5, 6, 6, 6, 6, 7)]
    order = ['idle', 'run', 'jump', 'fall', 'roll', 'hurt', 'death', 'attack1', 'attack2', 'attack3', 'storm', 'parry', 'rend']
    lines = []
    for k in order:
        vs = ', '.join('Vector4(%.1f, %.1f, %.1f, %.1f)' % tuple(v) for v in anims[k])
        lines.append('\t&"%s": [%s],' % (k, vs))
    target = os.path.join(HERE, '..', '..', 'src', 'player', 'hero_blade.gd')
    src = open(target).read()
    head = src.split('const SEGMENTS := {')[0]
    tail = '}' + src.split('\n}\n', 1)[1].join(['', '']) if False else src[src.index('\n}\n') + 1:]
    open(target, 'w').write(head + 'const SEGMENTS := {\n' + '\n'.join(lines) + '\n' + tail)


def main():
    raw = sys.argv[1]
    frames = {}
    for d in sorted(os.listdir(raw)):
        files = sorted(glob.glob(os.path.join(raw, d, '*.png')), key=lambda p: int(os.path.basename(p)[:-4]))
        frames[d] = [load(f) for f in files]
    # one palette for everything: sample every opaque pixel into a strip and median-cut it
    pixels = []
    for lst in frames.values():
        for rgb, a in lst:
            px, ap = rgb.load(), a.load()
            for y in range(rgb.height):
                for x in range(rgb.width):
                    if ap[x, y]:
                        pixels.append(px[x, y])
    strip = Image.new('RGB', (len(pixels), 1))
    strip.putdata(pixels)
    pal = strip.quantize(colors=COLOURS, method=Image.MEDIANCUT, dither=Image.NONE)
    for variant in ('plain', 'masked'):
        shutil.rmtree(os.path.join(OUT, variant), ignore_errors=True)
    n = 0
    for d, lst in frames.items():
        for i, (rgb, a) in enumerate(lst):
            q = rgb.quantize(palette=pal, dither=Image.NONE).convert('RGB')
            img = outline(Image.merge('RGBA', (*q.split(), a)))
            for variant in ('plain', 'masked'):
                folder = os.path.join(OUT, variant, d)
                os.makedirs(folder, exist_ok=True)
                out = img if variant == 'plain' else flash(img)
                out.save(os.path.join(folder, f'SkeletonKnight_{d}_{i}.png'))
            n += 1
    write_blades(raw)
    print('frames', n, 'palette', COLOURS)
    if '--preview' in sys.argv:
        path = sys.argv[sys.argv.index('--preview') + 1]
        cols = max(len(l) for l in frames.values())
        sheet = Image.new('RGBA', (cols * 100, len(frames) * 72), (46, 42, 58, 255))
        for r, (d, lst) in enumerate(frames.items()):
            for c in range(len(lst)):
                sheet.alpha_composite(Image.open(os.path.join(OUT, 'plain', d, f'SkeletonKnight_{d}_{c}.png')), (c * 100, r * 72))
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(path)


main()
