# Builds the 2D character library (game/art/library/characters/*) from licence-checked downloads.
#   python3 -I game/tools/art/library/build_characters_2d.py <downloads dir> [only ...]
# <downloads dir> holds one folder per pack, each with the archive extracted under x/ (see Design/Assets/CATALOGUE.md
# for every source URL). Output per character: <Anim>_<n>.png frames (same naming as game/art/enemies), meta.json
# (canvas, feet anchor, frame counts, fps), preview.png (contact sheet) and source/ (the original sheets, when small).
import glob, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from PIL import Image, ImageEnhance

DL = sys.argv[1]
ONLY = set(sys.argv[2:])


def P(*parts):
    hits = glob.glob(os.path.join(DL, *parts))
    if not hits: raise FileNotFoundError(os.path.join(DL, *parts))
    return hits[0]


def frames_from_dir(d, prefix=None):
    files = [f for f in glob.glob(os.path.join(d, '*.png')) if not prefix or os.path.basename(f).startswith(prefix)]
    files.sort(key=lambda f: [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', os.path.basename(f))])
    return [lib.rgba(f) for f in files]


def finish(name, anims, *, credit, licence, url, author, fps=10, grade=None, sources=(), notes='', mult=8, use=''):
    if ONLY and name not in ONLY: return
    d = lib.out_dir('characters', name)
    anims = {k: lib.drop_empty(v) for k, v in anims.items()}
    anims = {k: v for k, v in anims.items() if v}
    anims, size, feet = lib.fit_canvas(anims, mult=mult)
    if grade:
        anims = {k: [lib.ashen(f, **grade) for f in v] for k, v in anims.items()}
    counts = lib.write_frames(d, anims)
    if sources: lib.keep_source(d, *sources)
    lib.write_meta(d, name=name, canvas=list(size), feet=list(feet), anims=counts, fps=fps, author=author, licence=licence,
                   credit=credit, url=url, graded=bool(grade), notes=notes, use=use)
    lib.contact_sheet([(f'{k} ({len(v)})', v) for k, v in anims.items()], os.path.join(d, 'preview.png'), zoom=2)
    print(name, size, counts)


# ------------------------------------------------------------------ LuizMelo (CC0)
LM = dict(licence='CC0 1.0', author='LuizMelo', credit='LuizMelo (credit optional)')
ASH = dict(sat=0.5, val=0.85)


def luizmelo(name, folder, files, fw, fh, url, grade=ASH, use=''):
    anims, srcs = {}, []
    for anim, fn in files.items():
        p = P(folder, fn); srcs.append(p)
        im = lib.rgba(p)
        anims[anim] = lib.strip(im, fw=fw, fh=fh)
    finish(name, anims, url=url, grade=grade, sources=srcs, use=use, **LM)


def build_luizmelo():
    luizmelo('lm_fallen_king', 'lm_king/x/*/*', {'Idle': 'Idle.png', 'Run': 'Run.png', 'Attack1': 'Attack_1.png', 'Attack2': 'Attack_2.png',
             'Hit': 'Hit.png', 'Jump': 'Jump.png', 'Fall': 'Fall.png', 'Death': 'Death.png'}, 155, 155,
             'https://luizmelo.itch.io/medieval-king-pack', use='crowned swordsman: a mini-boss or the Crown Guard captain (ashen-graded)')
    luizmelo('lm_queen_blade', 'lm_king2/x/*/*/Sprites', {'Idle': 'Idle.png', 'Run': 'Run.png', 'Attack1': 'Attack1.png', 'Attack2': 'Attack2.png',
             'Attack3': 'Attack3.png', 'Hit': 'Take_Hit.png', 'HitFlash': 'Take_Hit_-_white_silhouette.png', 'Jump': 'Jump.png', 'Fall': 'Fall.png',
             'Death': 'Death.png'}, 160, 111, 'https://luizmelo.itch.io/medieval-king-pack-2', use='caped royal duellist: rival / mini-boss')
    luizmelo('lm_red_warrior', 'lm_warrior2/x/*/*/Sprites', {'Idle': 'Idle.png', 'Run': 'Run.png', 'Attack1': 'Attack1.png', 'Attack2': 'Attack2.png',
             'Attack3': 'Attack3.png', 'Attack4': 'Attack4.png', 'Hit': 'Take_Hit.png', 'HitFlash': 'Take_Hit_-_white_silhouette.png',
             'Jump': 'Jump.png', 'Fall': 'Fall.png', 'Death': 'Death.png'}, 150, 150, 'https://luizmelo.itch.io/medieval-warrior-pack-2',
             use='sword-and-board soldier: a human enemy or NPC duellist')
    luizmelo('lm_evil_wizard', 'lm_wizard/x/*/*/Sprites', {'Idle': 'Idle.png', 'Move': 'Move.png', 'Attack': 'Attack.png', 'Hit': 'Take_Hit.png',
             'Death': 'Death.png'}, 150, 150, 'https://luizmelo.itch.io/evil-wizard', grade=dict(sat=0.6, val=0.85),
             use='fire-casting sorcerer: caster enemy or the Hollow Bishop stand-in')
    for mon, use in (('Skeleton', 'sword-and-shield skeleton with a block pose: a basic undead enemy'),
                     ('Flying_eye', 'flying eye-bat: replaces or joins the Cinder Bat'),
                     ('Goblin', 'small knife goblin: fast weak enemy')):
        folder = 'lm_monsters/x/*/*/' + mon
        files = {os.path.splitext(os.path.basename(f))[0].replace('Take_Hit', 'Hit'): os.path.basename(f) for f in glob.glob(os.path.join(DL, folder, '*.png'))}
        luizmelo('lm_' + mon.lower(), folder, files, 150, 150, 'https://luizmelo.itch.io/monsters-creatures-fantasy', use=use)


# ------------------------------------------------------------------ Gothicvania (ansimuz / Luis Zuno, CC0)
GV = dict(licence='CC0 1.0 (public domain)', author='Luis Zuno (ansimuz)', credit='Luis Zuno (@ansimuz) (credit optional)')
PAT = 'gv_patreon/x/*/*'


def sheet(path, fw, fh=None, n=None):
    im = lib.rgba(path)
    fr = lib.strip(im, fw=fw, fh=fh or im.height)
    return fr[:n] if n else fr


def build_gothicvania():
    url = 'https://opengameart.org/content/gothicvania-patreons-collection'
    g = lambda *p: P(PAT, *p)
    spec = {
        'gv_reaper_ghost': ({'Idle': (g('Ghost-Files/PNG/ghost-idle.png'), 64), 'Appear': (g('Ghost-Files/PNG/ghost-appears.png'), 48),
                             'Shriek': (g('Ghost-Files/PNG/ghost-shriek.png'), 64), 'Vanish': (g('Ghost-Files/PNG/ghost-vanish.png'), 64)},
                            'hooded wraith that fades in/out and shrieks: a hollow phantom enemy'),
        'gv_fire_skull': ({'Idle': (g('Fire-Skull-Files/PNG/fire-skull.png'), 96), 'NoFire': (g('Fire-Skull-Files/PNG/fire-skull-no-fire.png'), 54)},
                          'flaming skull: an Ember Wisp variant / Molten Forge flyer'),
        'gv_hell_hound': ({'Idle': (g('Hell-Hound-Files/PNG/hell-hound-idle.png'), 64), 'Walk': (g('Hell-Hound-Files/PNG/hell-hound-walk.png'), 64),
                           'Run': (g('Hell-Hound-Files/PNG/hell-hound-run.png'), 67), 'Jump': (g('Hell-Hound-Files/PNG/hell-hound-jump.png'), 65)},
                          'undead hound with ember stripes: fast pouncing enemy'),
        'gv_hell_beast': ({'Idle': (g('Hell-Beast-Files/PNG/without-stroke/hell-beast-idle.png'), 55),
                           'Breath': (g('Hell-Beast-Files/PNG/without-stroke/hell-beast-breath.png'), 64)},
                          'horned brute that breathes fire: Forge Brute alternative'),
        'gv_demon': ({'Idle': (g('demon-Files/PNG/demon-idle.png'), 160), 'Attack': (g('demon-Files/PNG/demon-attack.png'), 240),
                      'AttackNoBreath': (g('demon-Files/PNG/demon-attack-no-breath.png'), 192)},
                     'big winged demon with a blue fire breath: boss (Storm Spire or a secret boss)'),
        'gv_nightmare': ({'Idle': (g('Nightmare-Files/PNG/nightmare-idle.png'), 128), 'Gallop': (g('Nightmare-Files/PNG/nightmare-galloping.png'), 144)},
                         'black spectral horse with blue flame mane: charging mini-boss / mount'),
        'gv_gothic_hero': ({'Idle': (g('Gothic-hero-Files/PNG/gothic-hero-idle.png'), 38), 'Run': (g('Gothic-hero-Files/PNG/gothic-hero-run.png'), 66),
                            'Attack': (g('Gothic-hero-Files/PNG/gothic-hero-attack.png'), 96), 'Jump': (g('Gothic-hero-Files/PNG/gothic-hero-jump.png'), 61),
                            'Hurt': (g('Gothic-hero-p2-Files/PNG/spritesheets/gothic-hero-hurt.png'), 48),
                            'Crouch': (g('Gothic-hero-p2-Files/PNG/spritesheets/gothic-hero-crouch.png'), 48),
                            'CrouchSlash': (g('Gothic-hero-p2-Files/PNG/spritesheets/gothic-hero-crouch-slash.png'), 80),
                            'JumpAttack': (g('Gothic-hero-p2-Files/PNG/spritesheets/gothic-hero-jump-attack.png'), 84)},
                           'red-caped swordsman with a full move set: rival hunter NPC or alternative hero'),
    }
    for name, (anims, use) in spec.items():
        if ONLY and name not in ONLY: continue
        fr = {}; srcs = []
        for k, (path, fw) in anims.items():
            im = lib.rgba(path); srcs.append(path)
            cells = lib.strip(im, fw=fw)
            # every frame keeps its own cell; cells of different widths are centred on one canvas
            fr[k] = cells
        W = max(f.width for v in fr.values() for f in v); Hh = max(f.height for v in fr.values() for f in v)
        for k, v in fr.items():
            out = []
            for f in v:
                c = Image.new('RGBA', (W, Hh)); c.alpha_composite(f, ((W - f.width) // 2, Hh - f.height)); out.append(c)
            fr[k] = out
        finish(name, fr, url=url, sources=srcs, use=use, fps=10, **GV)

    # packs with one PNG per frame
    church = 'gv_church/x/*/*/SPRITES'
    cem = 'gv_cemetery/x/*/*/PNG/Sprites'
    swamp = 'gv_swamp/x/*/*/Sprites'
    per_frame = {
        'gv_burning_ghoul': ({'Walk': P(church, 'burning-ghoul/sprites/v1'), 'WalkAlt': P(church, 'burning-ghoul/sprites/v2')},
                             'https://opengameart.org/content/gothicvania-church-pack', 'shambling ghoul with a burning head: a Molten Forge Shambler'),
        'gv_church_wizard': ({'Idle': P(church, 'wizard/idle-sprites'), 'Cast': P(church, 'wizard/fire-sprites')},
                             'https://opengameart.org/content/gothicvania-church-pack', 'hooded fire caster: a cathedral cultist'),
        'gv_angel': ({'Idle': P(church, 'angel/sprites/idle'), 'Attack': P(church, 'angel/sprites/angel-attack')},
                     'https://opengameart.org/content/gothicvania-church-pack', 'winged fallen angel: cathedral boss or statue that wakes'),
        'gv_skeleton': ({'Walk': P(cem, 'skeleton'), 'Rise': P(cem, 'skeleton-rise')},
                        'https://opengameart.org/content/gothicvania-cemetery-pack', 'skeleton that climbs out of the ground: a summon for bosses'),
        'gv_skeleton_clothed': ({'Walk': P(cem, 'skeleton-clothed'), 'Rise': P(cem, 'skeleton-rise-clothed')},
                                'https://opengameart.org/content/gothicvania-cemetery-pack', 'robed skeleton, same moves'),
        'gv_ghost': ({'Float': P(cem, 'ghost'), 'FloatHalo': P(cem, 'ghost-halo')},
                     'https://opengameart.org/content/gothicvania-cemetery-pack', 'small drifting ghost'),
        'gv_hell_cat': ({'Run': P(cem, 'hell-gato')}, 'https://opengameart.org/content/gothicvania-cemetery-pack', 'flaming hell-cat runner'),
        'gv_swamp_thing': ({'Walk': P(swamp, 'Thing/walk_thing')}, 'https://opengameart.org/content/gotthicvania-swamp', 'mossy swamp creature'),
        'gv_spider': ({'Walk': P(swamp, 'Spider/walk')}, 'https://opengameart.org/content/gotthicvania-swamp', 'crypt spider (crawler enemy)'),
    }
    for name, (dirs, url, use) in per_frame.items():
        if ONLY and name not in ONLY: continue
        fr = {k: frames_from_dir(v) for k, v in dirs.items()}
        W = max(f.width for v in fr.values() for f in v); Hh = max(f.height for v in fr.values() for f in v)
        fr = {k: [_pad(f, W, Hh) for f in v] for k, v in fr.items()}
        finish(name, fr, url=url, use=use, fps=10, **GV)


def _pad(f, W, H):
    c = Image.new('RGBA', (W, H)); c.alpha_composite(f, ((W - f.width) // 2, H - f.height)); return c


# ------------------------------------------------------------------ The Dark Knight (comphonia, CC0) - rendered sheets, shrunk to pixel art
def unity_rects(meta_path):
    t = open(meta_path).read()
    sp = t.split('sprites:', 1)[1]
    out = []
    for m in re.finditer(r'- name: (\S+)\s+rect:\s+serializedVersion: 2\s+x: ([\d.]+)\s+y: ([\d.]+)\s+width: ([\d.]+)\s+height: ([\d.]+)\s+alignment: \d+\s+pivot: \{x: ([-\d.e]+), y: ([-\d.e]+)\}', sp):
        n, x, y, w, h, px, py = m.groups()
        out.append((n, float(x), float(y), float(w), float(h), float(px), float(py)))
    out.sort(key=lambda r: [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', r[0])])
    return out


def build_dark_knight():
    name = 'dark_knight'
    if ONLY and name not in ONLY: return
    base = P('dark_knight_2d/x/Knight_2D/Knight_2D/Sprites')
    # animation -> (sheet, frames kept, sampled evenly)
    want = {'Idle': ('Idle', 6), 'Walk': ('Walk', 8), 'Run': ('Run', 8), 'Attack1': ('Attack1', 8), 'Slash': ('Slash', 9), 'Slash2': ('Slash2', 14),
            'Slash3': ('Slash3', 10), 'Block': ('Block', 4), 'BlockIdle': ('BlockIdle', 4), 'Impact': ('Impact', 4), 'Death': ('Death', 10),
            'Jump': ('Jump', 6), 'Kick': ('Kick', 8), 'Casting': ('Casting2', 8), 'PowerUp': ('PowerUp', 8), 'DrawSword': ('DrawSword', 6)}
    S = 0.30          # the knight is ~160 px tall in the sheets -> ~48 px, like the hero
    raw = {}
    for anim, (sheet_name, step) in want.items():
        im = lib.rgba(os.path.join(base, sheet_name + '.png'))
        allr = unity_rects(os.path.join(base, sheet_name + '.png.meta'))
        rects = [allr[round(i * (len(allr) - 1) / max(1, step - 1))] for i in range(min(step, len(allr)))]
        fr = []
        for n, x, y, w, h, px, py in rects:
            top = im.height - y - h
            cell = im.crop((int(x), int(top), int(x + w), int(top + h)))
            ax, ay = px * w, (1 - py) * h          # pivot in cell pixels (from the top-left)
            c = Image.new('RGBA', (420, 420)); c.alpha_composite(cell, (int(210 - ax), int(300 - ay))); fr.append(c)
        raw[anim] = fr
    allf = [f for v in raw.values() for f in v]
    box = lib.union_bbox(allf)
    out = {}
    for k, v in raw.items():
        small = []
        for f in v:
            f = f.crop(box)
            s = f.resize((max(1, round(f.width * S)), max(1, round(f.height * S))), Image.BOX)
            a = s.getchannel('A').point(lambda q: 255 if q > 100 else 0)
            rgb = ImageEnhance.Contrast(s.convert('RGB')).enhance(1.25)
            rgb = ImageEnhance.Brightness(rgb).enhance(1.6)
            s = rgb.convert('RGBA'); s.putalpha(a); small.append(s)
        out[k] = small
    allf = lib.quantize_set([f for v in out.values() for f in v], 24)
    i = 0
    for k in out:
        n = len(out[k]); out[k] = [lib.outline(f) for f in allf[i:i + n]]; i += n
    finish(name, out, url='https://opengameart.org/content/dark-knight-2d-character-sprites', author='comphonia', licence='CC0 1.0',
           credit='comphonia (comphonia.com) (credit optional)', fps=12,
           notes='Shrunk from 3D-rendered sheets (every 2nd-3rd frame kept), 24 colours, dark outline - the enemy_pixel.py look. '
                 'The full 37-animation sheets (28 MB) are not kept; download again to regenerate.',
           use='the most Souls-like figure in the library: a black-armoured knight with block, parry-able slashes, kick and cast. '
               'An elite enemy, a mirror-knight boss, or an alternative hero')


if __name__ == '__main__':
    build_luizmelo()
    build_gothicvania()
    build_dark_knight()
