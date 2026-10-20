# Shrinks the Blender lightning renders (lightning_render.py) to game pixels: 10x smaller, hard-edged, snapped to the
# three palette colours (outline, body, core) so every frame is crisp.
#   python3 game/tools/art/lightning_pixel.py <raw_dir> [--preview out.png]
# Output: game/art/lightning/<name>_<n>.png   (bolt_*: 40x160, crackle_*: 32x32, wave_red: 64x48)
from PIL import Image
import os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'art', 'lightning')
SHRINK = 10
PALETTES = {
    'blue': [(8, 16, 60), (60, 210, 255), (255, 252, 230)],
    'red': [(45, 0, 12), (255, 64, 40), (255, 236, 205)],
}


def snap(im, palette):
    small = im.resize((im.width // SHRINK, im.height // SHRINK), Image.BOX)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = px[x, y]
            if a < 110:
                px[x, y] = (0, 0, 0, 0)
                continue
            # un-premultiply the edge blend, then nearest palette colour
            f = 255.0 / a
            c = (min(255, r * f), min(255, g * f), min(255, b * f))
            best = min(palette, key=lambda p: sum((p[i] - c[i]) ** 2 for i in range(3)))
            px[x, y] = best + (255,)
    return small


def main():
    raw = sys.argv[1]
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    made = {}
    for name in sorted(os.listdir(raw)):
        palette = PALETTES['blue' if 'blue' in name else 'red']
        files = sorted(os.listdir(os.path.join(raw, name)), key=lambda f: int(f[:-4]))
        made[name] = []
        for i, f in enumerate(files):
            img = snap(Image.open(os.path.join(raw, name, f)).convert('RGBA'), palette)
            img.save(os.path.join(OUT, f'{name}_{i}.png'))
            made[name].append(img)
    print({k: len(v) for k, v in made.items()})
    if '--preview' in sys.argv:
        path = sys.argv[sys.argv.index('--preview') + 1]
        sheet = Image.new('RGBA', (8 * 70, 175 + 40 * 3 + 120), (30, 26, 40, 255))
        for r, name in enumerate(made):
            for c, img in enumerate(made[name]):
                y = 0 if name.startswith('bolt_blue') else 0
        x = 0
        for name in ('bolt_blue', 'bolt_red'):
            for img in made[name]:
                sheet.alpha_composite(img, (x, 0)); x += 44 if name == 'bolt_blue' else 0
        x = 0
        for name in ('bolt_red',):
            for img in made[name]:
                sheet.alpha_composite(img, (x, 0))
        sheet = Image.new('RGBA', (8 * 70, 175 + 36 * 2 + 52 + 10), (30, 26, 40, 255))
        for k, name in enumerate(('bolt_blue', 'bolt_red')):
            for c, img in enumerate(made[name]):
                sheet.alpha_composite(img, (c * 70 + k * 0, 0)) if k == 0 else sheet.alpha_composite(img, (c * 70 + 36, 0))
        y = 168
        for name in ('crackle_blue', 'crackle_red'):
            for c, img in enumerate(made[name]):
                sheet.alpha_composite(img, (c * 70, y))
            y += 36
        for c, img in enumerate(made['wave_red']):
            sheet.alpha_composite(img, (c * 70 if c < 6 else 0, y))
        sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(path)


main()
