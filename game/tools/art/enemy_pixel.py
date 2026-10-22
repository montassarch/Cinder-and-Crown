# Turns the Blender renders of one enemy (enemy_render.py) into game pixel art.
#   python3 game/tools/art/enemy_pixel.py <raw_dir> <enemy_id> [--preview out.png]
# raw: <raw_dir>/<enemy_id>/<Anim>/<n>.png (8x game size) + eyes.json.
# Output: game/art/enemies/<enemy_id>/<Anim>_<n>.png  (every frame shrunk 8x, hard-edged, one shared 24-colour palette,
# dark outline) and a 2-pixel glowing eye painted where the eye is, so every enemy reads as a face at 40 px and the
# test suite can measure which way it looks.
from PIL import Image, ImageEnhance
import glob, json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'art', 'enemies')
SHRINK = 8
COLOURS = 24
OUTLINE = (10, 6, 16)


def load(path):
    im = Image.open(path).convert('RGBA')
    small = im.resize((im.width // SHRINK, im.height // SHRINK), Image.BOX)
    a = small.getchannel('A').point(lambda v: 255 if v > 96 else 0)
    rgb = small.convert('RGB')
    rgb = ImageEnhance.Contrast(rgb).enhance(1.35)
    rgb = ImageEnhance.Color(rgb).enhance(1.4)
    rgb = ImageEnhance.Brightness(rgb).enhance(0.95)
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


def write_art_data():
    # src/enemies/enemy_art_data.gd: every enemy's canvas size, eye colour and frame counts (read by EnemyVisual)
    lines = []
    for enemy in sorted(os.listdir(OUT)):
        path = os.path.join(OUT, enemy, 'art.json')
        if not os.path.exists(path):
            continue
        d = json.load(open(path))
        anims = ', '.join('"%s": %d' % (k, v) for k, v in d['anims'].items())
        lines.append('\t"%s": {"canvas": Vector2i(%d, %d), "eye": Color8(%d, %d, %d), "anims": {%s}},' % (enemy, d['canvas'][0], d['canvas'][1], *d['eye'], anims))
    target = os.path.join(HERE, '..', '..', 'src', 'enemies', 'enemy_art_data.gd')
    open(target, 'w').write('class_name EnemyArtData\n## Written by tools/art/enemy_pixel.py: canvas size, eye colour and frame counts of every enemy sprite set.\n\nconst ENTRIES := {\n' + '\n'.join(lines) + '\n}\n')


def main():
    raw, enemy = sys.argv[1], sys.argv[2]
    meta = json.load(open(os.path.join(raw, enemy, 'eyes.json')))
    eye_colour = tuple(meta['eye_colour'])
    frames = {}
    for d in sorted(os.listdir(os.path.join(raw, enemy))):
        folder = os.path.join(raw, enemy, d)
        if not os.path.isdir(folder):
            continue
        files = sorted(glob.glob(os.path.join(folder, '*.png')), key=lambda p: int(os.path.basename(p)[:-4]))
        frames[d] = [load(f) for f in files]
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
    target = os.path.join(OUT, enemy)
    shutil.rmtree(target, ignore_errors=True)
    os.makedirs(target)
    n = 0
    for d, lst in frames.items():
        for i, (rgb, a) in enumerate(lst):
            q = rgb.quantize(palette=pal, dither=Image.NONE).convert('RGB')
            img = outline(Image.merge('RGBA', (*q.split(), a)))
            ex, ey = meta['eyes'][d][i]
            for dx in (0, 1):
                X, Y = int(ex) + dx, int(ey)
                if 0 <= X < img.width and 0 <= Y < img.height:
                    img.putpixel((X, Y), eye_colour + (255,))
            img.save(os.path.join(target, f'{d}_{i}.png'))
            n += 1
    counts = {d: len(lst) for d, lst in frames.items()}
    json.dump({'canvas': meta['canvas'], 'eye': list(eye_colour), 'anims': counts}, open(os.path.join(target, 'art.json'), 'w'))
    write_art_data()
    print(enemy, 'frames', n)
    if '--preview' in sys.argv:
        path = sys.argv[sys.argv.index('--preview') + 1]
        cols = max(len(l) for l in frames.values())
        cw, ch = meta['canvas']
        sheet = Image.new('RGBA', (cols * cw, len(frames) * ch), (46, 42, 58, 255))
        for r, (d, lst) in enumerate(frames.items()):
            for c in range(len(lst)):
                sheet.alpha_composite(Image.open(os.path.join(target, f'{d}_{c}.png')), (c * cw, r * ch))
        sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(path)


main()
