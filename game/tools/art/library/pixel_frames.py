# Turns 8x Blender renders (render_kaykit.py / render_objects.py) into game pixel art in the library - the same look as
# game/tools/art/enemy_pixel.py: BOX shrink 8x, hard alpha, a little contrast, one shared palette, dark outline,
# optional 2-pixel glowing eye and the "ashen" grade.
#   python3 -I game/tools/art/library/pixel_frames.py characters <raw_dir> <id> [--colours 24] [--ashen] [--meta key=value ...]
#   python3 -I game/tools/art/library/pixel_frames.py objects <raw_dir> <set> [--colours 32]
# characters: <raw_dir>/<id>/<Anim>/<n>.png + eyes.json  ->  game/art/library/characters/<id>/<Anim>_<n>.png, meta.json, preview.png
# objects:    <raw_dir>/<set>/<name>.png + objects.json  ->  game/art/library/<category from objects.json>/<set>/<name>.png ...
import glob, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from PIL import Image, ImageEnhance

SHRINK = 8


def shrink(path, contrast=1.3, colour=1.25, bright=1.0, cut=96):
    im = Image.open(path).convert('RGBA')
    small = im.resize((im.width // SHRINK, im.height // SHRINK), Image.BOX)
    a = small.getchannel('A').point(lambda v: 255 if v > cut else 0)
    rgb = small.convert('RGB')
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = ImageEnhance.Color(rgb).enhance(colour)
    rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    out = rgb.convert('RGBA'); out.putalpha(a); return out


def opt(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        return sys.argv[i + 1] if i + 1 < len(sys.argv) and not sys.argv[i + 1].startswith('--') else True
    return default


def characters(raw, cid):
    meta = json.load(open(os.path.join(raw, cid, 'eyes.json')))
    order = ['Idle', 'Move', 'Dash', 'Windup', 'Strike', 'Recover', 'Stun', 'Death']
    anims = sorted([d for d in os.listdir(os.path.join(raw, cid)) if os.path.isdir(os.path.join(raw, cid, d))],
                   key=lambda a: (order.index(a) if a in order else 99, a))
    frames = {}
    for a in anims:
        files = sorted(glob.glob(os.path.join(raw, cid, a, '*.png')), key=lambda p: int(os.path.basename(p)[:-4]))
        frames[a] = [shrink(f) for f in files]
    flat = [f for v in frames.values() for f in v]
    flat = lib.quantize_set(flat, int(opt('--colours', 24)))
    if opt('--ashen'): flat = [lib.ashen(f, sat=0.6, val=0.95) for f in flat]
    i = 0
    eye = meta.get('eye_colour')
    for a in frames:
        n = len(frames[a]); out = []
        for k, f in enumerate(flat[i:i + n]):
            f = lib.outline(f)
            if eye:
                ex, ey = meta['eyes'][a][k]
                for dx in (0, 1):
                    X, Y = int(ex) + dx, int(ey)
                    if 0 <= X < f.width and 0 <= Y < f.height and f.getpixel((X, Y))[3]: f.putpixel((X, Y), tuple(eye) + (255,))
            out.append(f)
        frames[a] = out; i += n
    d = lib.out_dir('characters', cid)
    counts = lib.write_frames(d, frames)
    extra = {}
    for kv in sys.argv:
        if '=' in kv and not kv.startswith('--'): k, v = kv.split('=', 1); extra[k] = v
    lib.write_meta(d, name=cid, canvas=meta['canvas'], feet=[round(meta['canvas'][0] * 0.4), meta['canvas'][1] - 2], anims=counts, fps=10,
                   eye=eye, eyes=meta['eyes'], **extra)
    lib.contact_sheet([(f'{k} ({len(v)})', v) for k, v in frames.items()], os.path.join(d, 'preview.png'), zoom=2)
    print(cid, counts)


def objects(raw, set_name):
    info = json.load(open(os.path.join(raw, set_name, 'objects.json')))
    d = lib.out_dir(info['category'], set_name)
    shr = {}
    for name in info['objects']:
        shr[name] = shrink(os.path.join(raw, set_name, name + '.png'), contrast=1.25, colour=1.1, cut=110)
    names = list(shr)
    q = lib.quantize_set([shr[n] for n in names], int(opt('--colours', 32)))
    rows = []
    for n, f in zip(names, q):
        box = f.getchannel('A').getbbox()
        if not box: continue
        f = lib.outline(f).crop((max(0, box[0] - 1), max(0, box[1] - 1), min(f.width, box[2] + 1), min(f.height, box[3] + 1)))
        if info.get('ashen'): f = lib.ashen(f, sat=0.65, val=0.95)
        lib.save(f, os.path.join(d, n + '.png')); rows.append(f)
        info['objects'][n]['size'] = list(f.size)
    lib.write_meta(d, **info)
    lib.contact_sheet([(f'{set_name} ({len(rows)})', rows)], os.path.join(d, 'preview.png'), zoom=2, max_cols=10, max_rows=10)
    print(set_name, len(rows))


if __name__ == '__main__':
    kind, raw, name = sys.argv[1], sys.argv[2], sys.argv[3]
    characters(raw, name) if kind == 'characters' else objects(raw, name)
