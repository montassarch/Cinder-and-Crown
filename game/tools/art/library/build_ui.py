# Builds the UI library (game/art/library/ui/*) from licence-checked downloads.
#   python3 -I game/tools/art/library/build_ui.py <downloads dir>
# - game-icons.net: a curated set of white SVG icons (CC-BY 3.0, every author credited) rendered with rsvg-convert to
#   32 px and 64 px PNG (tint them in Godot with modulate), plus a gold-on-dark "boon card" version at 48 px.
# - Tiny RPG Dark Dwellers GUI (CC0): 9-slice frames, buttons, bars, cursors, portrait frames - copied as is (pixel art).
# - 496 RPG icons (public domain), Kenney game icons (CC0), Ravenmore icons (CC-BY 3.0) - copied / shrunk.
import glob, os, shutil, subprocess, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from PIL import Image, ImageDraw

DL = sys.argv[1]

ICONS = {   # icon name -> what the game could use it for
    'broadsword': 'sword weapon', 'two-handed-sword': 'greatsword', 'spear-head': 'spear weapon', 'gauntlet': 'gauntlet weapon',
    'pocket-bow': 'bow weapon', 'wizard-staff': 'wand / staff weapon', 'crossed-swords': 'combat / duel', 'sword-clash': 'parry',
    'sword-break': 'guard break', 'broken-shield': 'stagger', 'checked-shield': 'block', 'shield-reflect': 'riposte',
    'dodging': 'dodge roll', 'sprint': 'dash', 'heavy-fall': 'plunge attack', 'jump-across': 'double jump',
    'campfire': 'bonfire / rest', 'flame': 'fire boon', 'fire-ray': 'fire beam', 'fireball': 'fire bolt', 'lightning-bolt': 'lightning boon',
    'lightning-frequency': 'chain lightning', 'snowflake-1': 'frost boon', 'frozen-orb': 'ice orb', 'ice-spell-cast': 'frost cast',
    'drop': 'blood / bleed', 'bleeding-wound': 'bleed status', 'poison-bottle': 'poison', 'death-skull': 'death', 'skull-crossed-bones': 'danger',
    'crowned-skull': 'boss', 'crown': 'the crown / victory', 'crowned-heart': 'max health', 'heart-plus': 'heal', 'health-potion': 'flask',
    'heart-bottle': 'estus-like flask', 'shining-heart': 'regen', 'coins': 'cells / currency', 'two-coins': 'shop price', 'key': 'key',
    'locked-chest': 'chest', 'open-treasure-chest': 'loot', 'scroll-unfurled': 'lore', 'book-cover': 'codex', 'hourglass': 'timer',
    'stopwatch': 'cooldown', 'candle-flame': 'checkpoint candle', 'candle-light': 'light', 'holy-grail': 'relic', 'church': 'cathedral world',
    'tombstone': 'graveyard', 'coffin': 'crypt', 'ghost': 'ghost', 'spectre': 'phantom', 'raise-skeleton': 'summon skeletons',
    'skeleton': 'undead', 'bat-wing': 'bat', 'imp': 'imp', 'horned-skull': 'demon', 'anvil': 'forge / upgrade', 'anvil-impact': 'forge world',
    'hammer-drop': 'slam', 'thunder-struck': 'storm world', 'tornado': 'whirlwind', 'whirlwind': 'spin attack', 'magic-swirl': 'magic',
    'all-seeing-eye': 'reveal', 'evil-eyes': 'enemy aware', 'visored-helm': 'armour', 'barbute': 'knight helm', 'mailed-fist': 'strength',
    'muscle-up': 'power', 'run': 'speed', 'boot-stomp': 'stomp', 'angel-wings': 'holy', 'bolt-shield': 'ward', 'cracked-shield': 'shield break',
    'burning-skull': 'fire skull', 'flaming-trident': 'fire spear', 'pentagram-rose': 'curse', 'death-zone': 'hazard', 'pause-button': 'pause',
    'settings-knobs': 'settings', 'exit-door': 'quit', 'trophy': 'achievement', 'swap-bag': 'inventory', 'card-random': 'random boon',
}


def game_icons():
    root = glob.glob(os.path.join(DL, 'game_icons/x/icons/icons/ffffff/transparent/1x1'))[0]
    d = lib.out_dir('ui', 'game_icons')
    found, credits = {}, {}
    for name, use in ICONS.items():
        hits = sorted(glob.glob(os.path.join(root, '*', name + '.svg')))
        if not hits: continue
        svg = hits[0]; author = os.path.basename(os.path.dirname(svg))
        for px in (32, 64):
            out = os.path.join(d, f'{px}', name + '.png'); os.makedirs(os.path.dirname(out), exist_ok=True)
            subprocess.run(['rsvg-convert', '-w', str(px), '-h', str(px), '-o', out, svg], check=True)
        lib.keep_source(d, svg)
        found[name] = dict(author=author, use=use)
        credits.setdefault(author, []).append(name)
    # boon-card style: gold glyph on a dark rounded tile (48 px)
    cards = []
    for name in found:
        g = Image.open(os.path.join(d, '64', name + '.png')).convert('RGBA').resize((36, 36), Image.LANCZOS)
        tile = Image.new('RGBA', (48, 48)); dr = ImageDraw.Draw(tile)
        dr.rounded_rectangle((1, 1, 46, 46), 6, fill=(26, 20, 28, 255), outline=(120, 90, 50, 255), width=2)
        gold = Image.new('RGBA', g.size, (236, 196, 112, 255)); gold.putalpha(g.getchannel('A'))
        tile.alpha_composite(gold, (6, 6)); lib.save(tile, os.path.join(d, 'card48', name + '.png')); cards.append(tile)
    lib.write_meta(d, name='game_icons', licence='CC-BY 3.0 (game-icons.net)', url='https://game-icons.net',
                   credit='Icons made by ' + ', '.join(sorted(credits)) + ' from game-icons.net, CC-BY 3.0',
                   icons=found, authors=credits, notes='White glyphs: tint with modulate. card48/ = gold-on-dark boon tiles.')
    lib.contact_sheet([('card48 (%d icons)' % len(cards), cards)], os.path.join(d, 'preview.png'), zoom=1, max_cols=16, max_rows=8)
    print('game_icons', len(found), sorted(credits))


def dark_dwellers():
    src = glob.glob(os.path.join(DL, 'gui_darkdwellers/x/*'))[0]
    d = lib.out_dir('ui', 'tiny_rpg_dark_dwellers_gui')
    rows = {}
    for f in sorted(glob.glob(os.path.join(src, '*.png'))):
        base = os.path.basename(f)[8:]          # drop the date prefix
        shutil.copyfile(f, os.path.join(d, base))
        kind = 'frames' if 'Frame' in base or 'Slices' in base or 'portrait' in base else 'buttons/bars/cursors'
        rows.setdefault(kind, []).append(lib.rgba(f))
    shutil.copyfile(os.path.join(src, 'README.html'), os.path.join(d, 'README.html'))
    lib.write_meta(d, name='tiny_rpg_dark_dwellers_gui', author='Gabriel "tiopalada" Lima', licence='CC0 1.0', credit='tiopalada (credit optional)',
                   url='https://opengameart.org/content/tiny-rpg-dark-dwellers-gui',
                   notes='Pixel-art dark GUI: *9Slices* are NinePatchRect frames (96 px, 32 px corners), *-Sheet are button / cursor state strips.')
    lib.contact_sheet([(k, v) for k, v in rows.items()], os.path.join(d, 'preview.png'), zoom=2, max_cols=8)
    print('dark dwellers', sum(len(v) for v in rows.values()))


def icons_496():
    src = glob.glob(os.path.join(DL, 'icons_496/x/496_RPG_icons'))[0]
    d = lib.out_dir('ui', 'rpg_icons_496')
    ims = []
    for f in sorted(glob.glob(os.path.join(src, '*.png'))):
        shutil.copyfile(f, os.path.join(d, os.path.basename(f))); ims.append(lib.rgba(f))
    lib.write_meta(d, name='rpg_icons_496', author='Henrique Lazarini (7Soul1), repacked by gnola14', licence='Public domain (CC0 on OpenGameArt; the artist\'s own page says public domain)',
                   credit='Henrique Lazarini (7Soul1) (credit optional)', url='https://opengameart.org/content/496-pixel-art-icons-for-medievalfantasy-rpg',
                   notes='34 px pixel icons: weapons (W_), armour (A_), potions (P_), skills (S_), items (I_), etc. Good for boons, shop items, pickups.')
    lib.contact_sheet([('496 icons (first 192)', ims[:192])], os.path.join(d, 'preview.png'), zoom=1, max_cols=24, max_rows=8)
    print('496 icons', len(ims))


def kenney_icons():
    src = glob.glob(os.path.join(DL, 'kenney_gameicons/x/*/PNG/White/1x'))
    src = src[0] if src else glob.glob(os.path.join(DL, 'kenney_gameicons/x/*/PNG/*'))[0]
    d = lib.out_dir('ui', 'kenney_game_icons')
    ims = []
    for f in sorted(glob.glob(os.path.join(src, '*.png'))):
        shutil.copyfile(f, os.path.join(d, os.path.basename(f))); ims.append(lib.rgba(f))
    lib.write_meta(d, name='kenney_game_icons', author='Kenney', licence='CC0 1.0', credit='Kenney (credit optional)',
                   url='https://opengameart.org/content/game-icons', notes='Menu / system icons (pause, settings, audio, arrows, gamepad...), white 1x.')
    lib.contact_sheet([('kenney game icons', ims)], os.path.join(d, 'preview.png'), zoom=1, max_cols=20, max_rows=8)
    print('kenney icons', len(ims), src)


def ravenmore():
    src = glob.glob(os.path.join(DL, 'icons_ravenmore/x/*/64'))[0]
    d = lib.out_dir('ui', 'ravenmore_icons')
    ims = []
    for f in sorted(glob.glob(os.path.join(src, '*.png'))):
        shutil.copyfile(f, os.path.join(d, os.path.basename(f))); ims.append(lib.rgba(f))
    lib.write_meta(d, name='ravenmore_icons', author='Ravenmore', licence='CC-BY 3.0', credit='Fantasy Icon Pack by Ravenmore (http://ravenmore.itch.io), CC-BY 3.0',
                   url='https://opengameart.org/content/fantasy-icon-pack-by-ravenmore-0', notes='Hand-painted 64 px item icons for a dark background (128/512 px versions exist in the download).')
    lib.contact_sheet([('ravenmore 64 px', ims)], os.path.join(d, 'preview.png'), zoom=1, max_cols=14)
    print('ravenmore', len(ims))


if __name__ == '__main__':
    game_icons(); dark_dwellers(); icons_496(); kenney_icons(); ravenmore()
