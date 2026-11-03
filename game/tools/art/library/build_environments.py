# Builds the environment / prop library (game/art/library/environments/*, props/*) from licence-checked downloads.
#   python3 -I game/tools/art/library/build_environments.py <downloads dir> [name ...]
# Gothicvania layers and tilesets are already drawn for a 384x224 view with 16 px tiles, so they are kept at 1x.
# Colourful sets also get an `ashen/` copy (desaturated, cool shadows, warm highlights) that sits better next to the
# Cinder & Crown palette. Prop sheets are cut into one PNG per object (islands of opaque pixels).
import glob, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from PIL import Image

DL = sys.argv[1]
ONLY = set(sys.argv[2:])


def P(*parts):
    hits = sorted(glob.glob(os.path.join(DL, *parts)))
    if not hits: raise FileNotFoundError(os.path.join(DL, *parts))
    return hits[0]


def islands(img, gap=3, min_px=12):
    """Bounding boxes of groups of opaque pixels (pixels closer than `gap` join the same group)."""
    a = img.getchannel('A')
    w, h = a.size
    sw, sh = (w + gap - 1) // gap, (h + gap - 1) // gap
    small = a.resize((sw, sh), Image.BOX).load()
    seen = set(); boxes = []
    for y in range(sh):
        for x in range(sw):
            if small[x, y] == 0 or (x, y) in seen: continue
            stack = [(x, y)]; seen.add((x, y)); x0 = x1 = x; y0 = y1 = y
            while stack:
                cx, cy = stack.pop()
                x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < sw and 0 <= ny < sh and (nx, ny) not in seen and small[nx, ny] > 0:
                            seen.add((nx, ny)); stack.append((nx, ny))
            box = (x0 * gap, y0 * gap, min(w, (x1 + 1) * gap), min(h, (y1 + 1) * gap))
            sub = img.crop(box); bb = sub.getchannel('A').getbbox()
            if not bb: continue
            box = (box[0] + bb[0], box[1] + bb[1], box[0] + bb[2], box[1] + bb[3])
            if (box[2] - box[0]) * (box[3] - box[1]) >= min_px: boxes.append(box)
    boxes.sort(key=lambda b: (b[1] // 24, b[0]))
    return boxes


def colour_key(img, key=None):
    img = img.convert('RGBA'); key = key or img.getpixel((0, 0))[:3]
    px = [(r, g, b, 0) if (r, g, b) == key else (r, g, b, a) for r, g, b, a in img.getdata()]
    out = Image.new('RGBA', img.size); out.putdata(px); return out


class Env:
    def __init__(self, cat, name, *, author, licence, credit, url, use, notes=''):
        self.skip = bool(ONLY) and name not in ONLY
        self.name, self.rows = name, []
        self.meta = dict(name=name, author=author, licence=licence, credit=credit, url=url, use=use, notes=notes, files={})
        if not self.skip: self.d = lib.out_dir(cat, name)

    def put(self, rel, img, what='', ashen=False, preview=True):
        if self.skip: return
        lib.save(img, os.path.join(self.d, rel))
        self.meta['files'][rel] = dict(size=list(img.size), what=what)
        if ashen:
            g = lib.ashen(img, sat=0.45, val=0.85)
            lib.save(g, os.path.join(self.d, 'ashen', rel))
            self.meta['files']['ashen/' + rel] = dict(size=list(img.size), what=what + ' (ashen grade)')
        if preview: self.rows.append((rel + ' %dx%d' % img.size, [img] + ([lib.ashen(img, sat=0.45, val=0.85)] if ashen else [])))

    def cut(self, prefix, sheet, what, gap=3, names=None, ashen=False):
        if self.skip: return
        objs = [sheet.crop(b) for b in islands(sheet, gap)]
        for i, o in enumerate(objs):
            nm = names[i] if names and i < len(names) else f'{prefix}_{i:02d}'
            lib.save(o, os.path.join(self.d, 'objects', nm + '.png'))
            self.meta['files']['objects/' + nm + '.png'] = dict(size=list(o.size), what=what)
            if ashen: lib.save(lib.ashen(o, sat=0.45, val=0.85), os.path.join(self.d, 'ashen', 'objects', nm + '.png'))
        self.rows.append((f'{prefix}: {len(objs)} objects', objs))

    def done(self, zoom=1, max_cols=6):
        if self.skip: return
        lib.write_meta(self.d, **self.meta)
        lib.contact_sheet(self.rows, os.path.join(self.d, 'preview.png'), zoom=zoom, max_cols=max_cols)
        print(self.name, len(self.meta['files']), 'files')


GV = dict(author='Luis Zuno (ansimuz)', licence='CC0 1.0 (public domain)', credit='Luis Zuno (@ansimuz) (credit optional)')


def gothicvania():
    c = 'gv_church/x/*/*/ENVIRONMENT'
    e = Env('environments', 'gv_church', url='https://opengameart.org/content/gothicvania-church-pack',
            use='cathedral interior: purple stone tiles, balustrade, altar, gothic window, skull column - the Cathedral world', **GV)
    e.put('tileset.png', lib.rgba(P(c, 'tileset.png')), '16 px tileset (stone floors, walls, altar, balustrade, arch)', ashen=True)
    bg = lib.rgba(P(c, 'backgrounds.png'))
    for i, b in enumerate(islands(bg, gap=2, min_px=400)):
        e.put(f'background_{i}.png', bg.crop(b), 'background wall panel (window, skull pillar, altar, gargoyle, torch)', ashen=True)
    e.put('column.png', lib.rgba(P(c, 'column.png')), 'big foreground column', ashen=True)
    e.done(zoom=2)

    m = 'gv_cemetery/x/*/*/PNG/Environment'
    e = Env('environments', 'gv_cemetery', url='https://opengameart.org/content/gothicvania-cemetery-pack',
            use='graveyard under a blood moon: parallax sky/mountains/graves, grassy tiles, dead trees, statue, tombstones', **GV)
    for f, w in (('background.png', 'sky with the moon (far layer)'), ('mountains.png', 'mountains (repeat horizontally)'), ('graveyard.png', 'graves (near layer)'),
                 ('tileset.png', '16 px tileset')):
        e.put(f, lib.rgba(P(m, f)), w, ashen=True)
    for f in sorted(glob.glob(os.path.join(DL, m, 'sliced-objects', '*.png'))):
        e.put('objects/' + os.path.basename(f), lib.rgba(f), 'prop', ashen=True, preview=True)
    e.done(zoom=1)

    t = 'gv_town/x/*/*/PNG/environment'
    e = Env('environments', 'gv_town', url='https://opengameart.org/content/gothicvania-town',
            use='ruined night town: sky, far town, tiles, houses, carts, crates, well, lamp post - a hub / between-runs village', **GV)
    for f, w in (('layers/background.png', 'sky (far layer)'), ('layers/middleground.png', 'distant town (mid layer)'), ('layers/tileset.png', '16 px tileset')):
        e.put(os.path.basename(f), lib.rgba(P(t, f)), w, ashen=True)
    e.cut('house', lib.rgba(P(t, 'props/houses.png')), 'house facade', gap=4, ashen=True)
    e.cut('prop', lib.rgba(P(t, 'props/props.png')), 'street prop', gap=3, ashen=True)
    e.done(zoom=1)

    s = 'gv_swamp/x/*/*/Evironment'
    e = Env('environments', 'gv_swamp', url='https://opengameart.org/content/gotthicvania-swamp',
            use='overgrown swamp with skull ground: a poison / sunken world', **GV)
    for f, w in (('background.png', 'sky strip (repeat)'), ('mid-layer-01.png', 'far trees (repeat)'), ('mid-layer-02.png', 'near trees (repeat)'),
                 ('tileset.png', '16 px tileset'), ('trees.png', 'big trees'), ('props.png', 'small props')):
        e.put(f, lib.rgba(P(s, f)), w, ashen=True)
    e.done(zoom=1)

    g = 'gv_patreon/x/*/*'
    e = Env('environments', 'gv_gothic_castle', url='https://opengameart.org/content/gothicvania-patreons-collection',
            use='castle hall with stained windows, chandeliers, gargoyles and gold stairs: a castle / throne world', **GV)
    e.put('background.png', lib.rgba(P(g, 'Gothic-Castle-Files/PNG/layers/gothic-castle-background.png')), 'hall wall (repeat)')
    e.put('tileset.png', lib.rgba(P(g, 'Gothic-Castle-Files/PNG/layers/gothic-castle-tileset.png')), '16 px tileset')
    e.put('preview_scene.png', lib.rgba(P(g, 'Gothic-Castle-Files/PNG/gothic-castle-preview.png')), 'how the author put it together')
    e.done(zoom=1)
    e = Env('environments', 'gv_old_dark_castle', url='https://opengameart.org/content/gothicvania-patreons-collection',
            use='mossy dungeon interior with a stained-glass window, arches and stairs: crypt / Frost Ossuary variant', **GV)
    e.put('background.png', lib.rgba(P(g, 'Old-dark-Castle-tileset-Files/PNG/old-dark-castle-interior-background.png')), 'interior wall (far layer)')
    e.put('tileset.png', lib.rgba(P(g, 'Old-dark-Castle-tileset-Files/PNG/old-dark-castle-interior-tileset.png')), '16 px tileset')
    e.put('preview_scene.png', lib.rgba(P(g, 'Old-dark-Castle-tileset-Files/PNG/preview-old-dark-castle-interior-tileset.png')), 'example scene')
    e.done(zoom=1)
    e = Env('environments', 'gv_gothic_horror', url='https://opengameart.org/content/gothicvania-patreons-collection',
            use='brick ruins against a cloudy town skyline', **GV)
    for f in ('clouds.png', 'town.png', 'tiles.png'):
        e.put(f, lib.rgba(P(g, 'Gothic-Horror-Files/PNG/layers', f)), 'layer', ashen=True)
    e.done(zoom=1)
    e = Env('environments', 'gv_night_town_bg', url='https://opengameart.org/content/gothicvania-patreons-collection',
            use='7-layer night parallax: sky, clouds, mountains (+ lit windows), forest, far buildings, town', **GV)
    for f in sorted(glob.glob(os.path.join(DL, g, 'night-town-background-files/layers/*.png'))):
        e.put(os.path.basename(f).replace('night-town-background-', ''), lib.rgba(f), 'parallax layer', ashen=True)
    e.done(zoom=1)


def misc_cc0():
    e = Env('props', 'ettingrinder_dark_fantasy', author='ETTiNGRiNDER', licence='CC0 1.0', credit='ETTiNGRiNDER (credit optional)',
            url='https://opengameart.org/content/misc-dark-fantasy-scenery-sprites and https://opengameart.org/content/dark-fantasy-item-sprites',
            use='candelabras, a hanging gibbet cage, chains with hooks, impaled heads, skulls, gargoyle statues, sword-in-stone, '
                'armour/shield/weapon/potion/key/tome icons. Background dressing and pickup / shop icons.')
    e.cut('scenery', lib.rgba(P('scenery_ettingrinder/misc_scenery.png')), 'scenery sprite', gap=2)
    e.cut('item', lib.rgba(P('items_ettingrinder/00_items.png')), 'item sprite (pickups, shop icons)', gap=2)
    e.done(zoom=2, max_cols=12)

    e = Env('environments', 'gothic_window_tiles', author='Max Johnson (Shoehorn)', licence='CC0 1.0 (public domain)',
            credit='Max Johnson (credit optional)', url='https://opengameart.org/content/gothic-window-tileset',
            use='modular stained-glass tracery (lead lines) - lay over a coloured glow for huge cathedral windows')
    d = 'gothic_window/x/*/Gothic_Window_Tileset'
    e.put('gothic_window_sheet.png', lib.rgba(P(d, 'gothic_window_sprite_sheet.png')), '128 px tracery tiles')
    stained = lib.rgba(P(d, 'Jesus_Stained_Glass.png'))
    e.put('stained_glass_figure.png', stained, 'stained glass figure panel (religious figure; swap for a saint/knight if preferred)')
    e.done(zoom=1)

    j = 'castle_platformer/x/working-title-assets/untitled_folder'
    e = Env('environments', 'jetrel_castle', author='Jetrel', licence='CC0 1.0', credit='Jetrel (credit optional)',
            url='https://opengameart.org/content/castle-platformer', use='green-stone castle tiles with a big gothic column, spikes; interior parallax',
            notes='The sheets had a flat background colour; it is keyed out to transparency.')
    e.put('twilight_tiles.png', colour_key(Image.open(P(j, 'twilight-tiles.png'))), '16 px tiles + column + spikes', ashen=True)
    for f in ('parallaxBG-interior1.png', 'parallaxBG-interior2.png'):
        e.put(f, Image.open(P(j, f)).convert('RGBA'), 'interior parallax layer')
    e.done(zoom=1)


if __name__ == '__main__':
    gothicvania(); misc_cc0()
