# Builds the effects library (game/art/library/vfx/<pack>/<effect>/<n>.png) from licence-checked downloads.
#   python3 -I game/tools/art/library/build_fx.py <downloads dir> [pack ...]
# Pixel-art effects keep their native size. Painted / rendered (HD) effects are shrunk so their longest side is about
# 2x the size they should cover in the 384x216 view (draw them at scale 0.5, like game/art/fx_painted).
# Every effect is trimmed to the union of its visible pixels; meta.json records frames, fps, the original pivot
# (moved into the trimmed frame), suggested blend mode and draw scale.
import glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from PIL import Image

DL = sys.argv[1]
ONLY = set(sys.argv[2:])


def P(*parts):
    hits = sorted(glob.glob(os.path.join(DL, *parts)))
    if not hits: raise FileNotFoundError(os.path.join(DL, *parts))
    return hits[0]


def natsort(files):
    return sorted(files, key=lambda f: [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', os.path.basename(f))])


def subsample(frames, n):
    if n is None or len(frames) <= n: return frames
    return [frames[round(i * (len(frames) - 1) / (n - 1))] for i in range(n)]


def fit(frames, longest=None, scale=None):
    """trim to the union bbox; optionally shrink so the longest side <= longest (BOX filter keeps soft glows soft)."""
    box = lib.union_bbox(frames)
    if not box: return frames, (0, 0), (0, 0)
    fr = [f.crop(box) for f in frames]
    s = scale or 1.0
    if longest:
        s = min(1.0, longest / max(fr[0].width, fr[0].height))
    if s != 1.0:
        fr = [f.resize((max(1, round(f.width * s)), max(1, round(f.height * s))), Image.BOX) for f in fr]
    return fr, box, s


class Pack:
    def __init__(self, name, *, author, licence, credit, url, notes=''):
        self.name, self.meta, self.rows = name, dict(pack=name, author=author, licence=licence, credit=credit, url=url, notes=notes, effects={}), []
        self.skip = bool(ONLY) and name not in ONLY
        if not self.skip: self.d = lib.out_dir('vfx', name)

    def add(self, effect, frames, *, fps=12, longest=None, scale=None, pivot=None, blend='mix', draw_scale=1.0, use='', n=None):
        if self.skip: return
        frames = subsample(lib.drop_empty(frames) if n != 'keep' else frames, None if n == 'keep' else n)
        src_size = frames[0].size
        fr, box, s = fit(frames, longest, scale)
        pv = pivot or (src_size[0] / 2, src_size[1] / 2)
        pv = [round((pv[0] - box[0]) * s, 1), round((pv[1] - box[1]) * s, 1)]
        for i, f in enumerate(fr):
            lib.save(f, os.path.join(self.d, effect, f'{i}.png'))
        self.meta['effects'][effect] = dict(frames=len(fr), size=list(fr[0].size), fps=fps, pivot=pv, blend=blend,
                                            draw_scale=draw_scale if s == 1.0 else round(draw_scale, 2), use=use)
        self.rows.append((f'{effect} ({len(fr)}) {fr[0].width}x{fr[0].height}', fr))

    def done(self, zoom=2, source=()):
        if self.skip: return
        lib.write_meta(self.d, **self.meta)
        lib.contact_sheet(self.rows, os.path.join(self.d, 'preview.png'), zoom=zoom, max_cols=12)
        if source: lib.keep_source(self.d, *source)
        print(self.name, len(self.meta['effects']), 'effects')


# ------------------------------------------------------------------ PVFX Foundry (nerijs, CC0) - 96x96 pixel effects
def pvfx():
    root = P('pvfx/x/pvfx-foundry-thirteen-spritesheets')
    pk = Pack('pvfx_foundry', author='nerijs', licence='CC0 1.0', credit='PVFX Foundry by nerijs (credit optional)',
              url='https://nerijs.itch.io/pvfx-foundry', notes='Pixel-art effects at native size, 20 fps. Pivots come from the pack manifests.')
    pick = {'crescent-slash': 'sword arc for heavy attacks', 'electric-impact': 'Storm Spire hit spark / lightning weapon',
            'warm-explosion': 'powder keg / fire bomb blast', 'smoke-puff': 'death puff, dodge-roll trail', 'landing-dust': 'jump landing / boss slam dust',
            'void-implosion': 'dark magic / boss summon', 'ember-jet': 'forge vent, fire breath', 'arcane-parry': 'parry flash',
            'earth-rupture': 'ground slam shockwave', 'focus-charge': 'charged attack wind-up', 'solar-shrapnel': 'crit hit burst',
            'frost-nova': 'Frost Ossuary ice burst', 'rift-portal': 'level exit / boss arrival portal', 'radiant-heal': 'heal / bonfire rest',
            'magical-projectile': 'wand bolt', 'beam-cutoff-burst': 'beam end burst', 'resonant-break': 'guard break', 'hush-lock': 'silence / seal ward',
            'counterfall': 'counter-attack burst', 'mass-release': 'big release / boss phase change', 'spectral-bloom': 'soul pickup bloom',
            'suturelight': 'holy light seam', 'harvest-seal': 'magic circle seal on the floor', 'acid-splash': 'poison splash',
            'dripping-runoff': 'blood/water drip', 'choir-moths': 'ambient moths around candles'}
    for eff, use in pick.items():
        man = json.load(open(os.path.join(root, 'effects', eff, 'grid', 'manifest.json')))
        sheet = lib.rgba(os.path.join(root, 'effects', eff, 'grid', 'sprite-sheet.png'))
        fr = []
        for f in man['frames']:
            s = f['sheet']; fr.append(sheet.crop((s['x'], s['y'], s['x'] + s['width'], s['y'] + s['height'])))
        loop = man.get('loop_mode', 'none')
        pk.add(eff.replace('-', '_'), fr, fps=20, pivot=man['pivot'], blend='mix', use=use + ('' if loop == 'none' else ' (loops)'), n='keep')
    pk.done()


# ------------------------------------------------------------------ CodeManu Free Pixel Effects Pack (CC-BY 4.0 on itch; credit CodeManu)
def codemanu():
    root = P('codemanu/x/Free_Pixel_Effects_Pack')
    pk = Pack('codemanu_pixel_fx', author='CodeManu', licence='CC-BY 4.0 (itch.io licence field; the page text says public domain - we credit to be safe)',
              credit='"Free Pixel Effects Pack" by CodeManu (https://codemanu.itch.io/pixelart-effect-pack), CC-BY 4.0',
              url='https://codemanu.itch.io/pixelart-effect-pack', notes='100x100 grid sheets, empty cells dropped, subsampled to 16 frames max.')
    uses = {'weaponhit': 'weapon hit spark', 'fire': 'fire column', 'phantom': 'ghost / soul burst', 'felspell': 'curse cast', 'midnight': 'dark burst',
            'flamelash': 'fire whip slash', 'firespin': 'fire vortex', 'brightfire': 'holy fire', 'magickahit': 'magic impact', 'casting': 'cast glyph',
            'protectioncircle': 'ward circle', 'sunburn': 'sun flare', 'freezing': 'ice burst', 'vortex': 'void vortex', 'nebula': 'mist cloud',
            'bluefire': 'soul fire', 'magicspell': 'spell burst', 'magic8': 'rune ring'}
    for f in natsort(glob.glob(os.path.join(root, '*_spritesheet.png'))):
        key = re.sub(r'^\d+_|_spritesheet\.png$', '', os.path.basename(f))
        if key not in uses: continue
        fr = lib.grid(lib.rgba(f), 100, 100)
        pk.add(key, fr, fps=16, use=uses[key], n=16, blend='add' if key not in ('midnight', 'phantom', 'felspell') else 'mix')
    pk.done()


# ------------------------------------------------------------------ Cethiel "Weapon Slash - Effect" (CC0) - glowing slash arcs
def cethiel():
    root = P('slash_cethiel/x/Everything_0')
    pk = Pack('cethiel_slashes', author='Cethiel', licence='CC0 1.0', credit='Cethiel (credit optional)',
              url='https://opengameart.org/content/weapon-slash-effect',
              notes='5 slash shapes x 4 colours, 6 frames each, shrunk to half size (draw at 1.0 for a ~60 px arc, these are already game scale).')
    for col, folder in (('gold', 'Classic'), ('violet', 'Alternative_1'), ('blue', 'Alternative_2'), ('fire', 'Alternative_3')):
        for k in range(1, 6):
            files = natsort(glob.glob(os.path.join(root, folder, str(k), '*.png')))
            fr = [lib.rgba(f) for f in files]
            W = max(f.width for f in fr); H = max(f.height for f in fr)
            fr = [_pad(f, W, H) for f in fr]
            pk.add(f'{col}_{k}', fr, fps=20, scale=0.5, blend='add', use='slash arc behind the swing (shape %d)' % k, n='keep')
    pk.done()


def _pad(f, W, H):
    c = Image.new('RGBA', (W, H)); c.alpha_composite(f, ((W - f.width) // 2, (H - f.height) // 2)); return c


# ------------------------------------------------------------------ small CC0 pixel slashes, sparks, lightning
def pixel_misc():
    pk = Pack('pixel_misc_cc0', author='several (see each effect)', licence='CC0 1.0', credit='tbbk, 13rice, Luis Zuno (ansimuz), Reactorcore (all optional)',
              url='see effects', notes='Small CC0 pixel effects gathered from OpenGameArt.')
    t = lib.rgba(P('slash_tbbk/pixel_art_sword_slash_sprites.png'))
    pk.add('tbbk_slash', lib.grid(t, 64, 47), fps=18, use='pixel sword slash (tbbk, https://opengameart.org/content/pixel-art-sword-slash-effect)', n='keep')
    r = lib.rgba(P('lightning_13rice/pixelated_tilesheet.png'))
    pk.add('13rice_radial_spark_pixel', lib.grid(r, 64, 64), fps=16, blend='add', use='radial lightning hit (13rice, https://opengameart.org/content/radial-lightning-effect)', n='keep')
    r = lib.rgba(P('lightning_13rice/spark_radial_spritesheet_13rice.png'))
    pk.add('13rice_radial_spark_hd', lib.grid(r, 256, 256), fps=16, longest=96, blend='add', draw_scale=0.5,
           use='radial spark, smooth (13rice); white - tint it', n='keep')
    m = 'gv_magic9/x/*/*/sprites'
    for eff, use in (('DarkBolt', 'falling dark bolt'), ('FireBomb', 'fire bomb burst'), ('Lightning', 'lightning strike from above'), ('spark', 'small spark')):
        fr = [lib.rgba(f) for f in natsort(glob.glob(os.path.join(DL, m, eff, '*.png')))]
        pk.add('gv_' + eff.lower(), fr, fps=14, use=use + ' (Gothicvania Magic Pack 9, ansimuz, https://opengameart.org/content/gothicvania-magic-pack-9)', n='keep')
    c = 'gv_church/x/*/*/SPRITES/fx'
    for eff, folder in (('gv_enemy_death', 'enemy-death/enemy-death-sprites'), ('gv_fireball', 'fireball/fireball-sprites')):
        fr = [lib.rgba(f) for f in natsort(glob.glob(os.path.join(DL, c, folder, '*.png')))]
        pk.add(eff, fr, fps=12, use='Gothicvania Church (ansimuz) ' + eff[3:].replace('_', ' '), n='keep')
    s = 'gv_swamp/x/*/*/Sprites'
    pk.add('gv_explosion', [lib.rgba(f) for f in natsort(glob.glob(os.path.join(DL, s, 'Enemy-Death/Explosion', '*.png')))], fps=12,
           use='enemy death pop (Gothicvania Swamp, ansimuz)', n='keep')
    g = 'gore_reactorcore/x/*/*/Sprites'
    for eff, f, fw in (('rc_blood_splat', 'Blood1_Splat_RefSheet.png', 10), ('rc_blood_burst', 'Blood2_Burst_RefSheet.png', 20),
                       ('rc_blood_blast', 'Blood3_Blast_RefSheet.png', 34)):
        im = lib.rgba(P(g, f))
        pk.add(eff, lib.strip(im, fw=fw), fps=14, use='pixel blood (Reactorcore, https://opengameart.org/content/gore-blood-gibs-meat-chunks)', n='keep')
    gibs = [lib.rgba(f) for f in natsort(glob.glob(os.path.join(DL, g, 'meat_gib_*.png')))]
    W = max(f.width for f in gibs); H = max(f.height for f in gibs)
    pk.add('rc_gibs', [_pad(f, W, H) for f in gibs], fps=1, use='single gib particles (one per frame) for a GPUParticles2D burst', n='keep')
    pk.done(zoom=3)


# ------------------------------------------------------------------ rendered / painted effects (HD -> shrunk)
def rendered():
    pk = Pack('rendered_cc0', author='several (see each effect)', licence='CC0 1.0',
              credit='para, Sinestesia, Mikodrak, Beast, rubberduck, Limphands, Luke.RUSTLTD (all optional)', url='see effects',
              notes='Blender-rendered / painted effects, shrunk so they stay light; draw_scale 0.5 means draw at half size for a sharp phone image.')
    para1 = 'particles_para1/x/para_CC0_particlefx-1'
    for k, eff, use in (('01', 'para_fire_ring', 'fire ring shockwave'), ('02', 'para_smoke_burst', 'dust/smoke burst'),
                        ('06', 'para_fire_ring_ground', 'fire ring on the ground'), ('07', 'para_spirit_ring', 'blue spirit ring')):
        fr = lib.grid(lib.rgba(P(para1, f'particlefx_{k}.png')), 128, 128)
        pk.add(eff, fr, fps=24, longest=96, n=16, blend='add' if 'smoke' not in eff else 'mix', draw_scale=0.5, use=use + ' (para, https://opengameart.org/content/animated-particle-effects-1)')
    para2 = 'particles_para2/x/para_CC0_particlefx-2'
    for f, eff in (('fire_01.png', 'para_fire'), ('blood_hit_01.png', 'para_blood_hit_1'), ('blood_hit_05.png', 'para_blood_hit_2')):
        im = lib.rgba(P(para2, f)); cell = 128
        fr = lib.grid(im, cell, cell)
        pk.add(eff, fr, fps=24, longest=96, n=16, blend='add' if 'fire' in eff else 'mix', draw_scale=0.5,
               use=('looping fire' if 'fire' in eff else 'blood hit spray') + ' (para, https://opengameart.org/content/animated-particle-effects-2)')
    for f, eff in (('0_16.png', 'sinestesia_hit'), ('1_128.png', 'sinestesia_blood'), ('2_75.png', 'sinestesia_hit_blood')):
        fr = lib.grid(lib.rgba(P('blood_sinestesia', f)), 512, 512)
        pk.add(eff, fr, fps=24, longest=128, blend='mix', draw_scale=0.5, use='painted hit flash / blood splash (Sinestesia, https://opengameart.org/content/animations-blood-hit-and-both-d)', n='keep')
    mk = 'spell_mikodrak/x/FX'
    for folder, eff, use in (('fx10_blackExplosion', 'mikodrak_black_explosion', 'black smoke burst'), ('fx2_swordFire', 'mikodrak_sword_fire', 'flaming sword trail'),
                             ('fx4_sign_of_fire', 'mikodrak_sign_of_fire', 'fire sigil'), ('fx5_fire_scissors', 'mikodrak_fire_scissors', 'crossed fire slash'),
                             ('fx6_eaterFire', 'mikodrak_eater_fire', 'devouring fire'), ('fx8_lighteningBall', 'mikodrak_lightning_ball', 'ball lightning'),
                             ('fx1_blue_topEffect', 'mikodrak_blue_pillar', 'blue light pillar')):
        files = natsort(glob.glob(os.path.join(DL, mk, folder, '*.png')))
        fr = [lib.rgba(f) for f in files]
        W = max(f.width for f in fr); H = max(f.height for f in fr); fr = [_pad(f, W, H) for f in fr]
        pk.add(eff, fr, fps=18, longest=128, n=16, blend='add' if 'black' not in eff else 'mix', draw_scale=0.5,
               use=use + ' (Mikodrak, https://opengameart.org/content/2d-spell-effects)')
    smoke = natsort(glob.glob(os.path.join(DL, 'smoke_aura/x/Smoke/*.png')))
    pk.add('beast_smoke_aura', [lib.rgba(f) for f in smoke], fps=20, longest=96, n=24, blend='mix', draw_scale=0.5,
           use='looping swirl of smoke: dark aura around a boss when tinted black (Beast, https://opengameart.org/content/smoke-aura)')
    rd = 'vol_rubberduck/x/blender-volumetric-particles-effects/effect-images'
    for kind, var, eff in (('explosion', 'fire+smoke', 'rubberduck_explosion'), ('flame', 'fire', 'rubberduck_flame'),
                           ('flame', 'blueish_flame', 'rubberduck_soul_flame'), ('flat_effect', 'fire+smoke', 'rubberduck_ground_burst'),
                           ('ring', 'fire', 'rubberduck_fire_ring'), ('shockwave', 'blueish_smoke', 'rubberduck_shockwave')):
        fr = [lib.rgba(f) for f in natsort(glob.glob(os.path.join(DL, rd, kind, var, '*.png')))]
        pk.add(eff, fr, fps=24, longest=96, n=16, blend='add' if 'smoke' not in var else 'mix', draw_scale=0.5,
               use='%s, volumetric render (rubberduck, https://opengameart.org/content/25-special-effects-rendered-with-blender)' % kind)
    ps1 = lib.rgba(P('ps1_fire/x/Fire_Spritesheet/Fire_Spritesheet.png'))
    pk.add('limphands_ps1_fire', lib.grid(ps1, 256, 256), fps=24, longest=64, n=24, blend='mix', draw_scale=1.0,
           use='looping camp/brazier fire, PS1 look (Limphands, https://limphands.itch.io/ps1-fire)')
    pk.done(zoom=1)


# ------------------------------------------------------------------ static textures: magic circles + Kenney particle sprites
def textures():
    pk = Pack('magic_circles', author='Luke.RUSTLTD', licence='CC0 1.0', credit='Luke.RUSTLTD (credit optional)',
              url='https://opengameart.org/content/4-summoning-circles', notes='Single images (spin / scale them in code). 128 px; tint with modulate.')
    for f in natsort(glob.glob(os.path.join(DL, 'circles_rustltd/x/summoning_circles/*.png'))):
        im = lib.rgba(f)
        pk.add(os.path.splitext(os.path.basename(f))[0], [im], fps=1, longest=128, blend='add', use='summoning / boss floor circle, ward under the player', n='keep')
    pk.done(zoom=1)
    pk = Pack('kenney_particles', author='Kenney (www.kenney.nl)', licence='CC0 1.0', credit='Kenney (credit optional)',
              url='https://opengameart.org/content/particle-pack-80-sprites', notes='Particle textures for GPUParticles2D / CPUParticles2D, shrunk to 64 px.')
    for f in natsort(glob.glob(os.path.join(DL, 'kenney_particles/x/kenney_particlePack/PNG/*.png'))):
        key = os.path.splitext(os.path.basename(f))[0]
        if not re.match(r'(fire|flame|smoke|spark|light|magic|scorch|star|trace|twirl|muzzle|slash|circle|dirt|window|scratch|symbol|flare)', key): continue
        pk.add(key, [lib.rgba(f)], fps=1, longest=64, blend='add', use='particle texture', n='keep')
    pk.done(zoom=1)


if __name__ == '__main__':
    pvfx(); codemanu(); cethiel(); pixel_misc(); rendered(); textures()
