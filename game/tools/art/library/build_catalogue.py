# Writes the per-asset tables of Design/Assets/CATALOGUE.md from every meta.json in game/art/library.
#   python3 -I game/tools/art/library/build_catalogue.py
# The hand-written parts (top picks, how to use, not-taken list, AI tools) live in Design/Assets/catalogue_intro.md and
# catalogue_outro.md and are pasted around the generated tables.
import glob, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib

REPO = os.path.normpath(os.path.join(lib.GAME, '..'))
DES = os.path.join(REPO, 'Design', 'Assets')


def rel(p):
    return os.path.relpath(p, REPO).replace(os.sep, '/')


def link(p):
    return f'[{os.path.basename(p)}](../../{rel(p)})'


def size_kb(d):
    t = 0
    for dp, dn, fn in os.walk(d):
        if os.path.basename(dp) == 'source': continue
        t += sum(os.path.getsize(os.path.join(dp, f)) for f in fn)
    return t // 1024


def esc(s):
    return str(s).replace('|', '/').replace('\n', ' ')


out = []
# ---------------- characters
out.append('## Characters (`game/art/library/characters/`)\n')
out.append('Frames are `<Anim>_<n>.png` like `game/art/enemies/*`; `meta.json` has canvas, feet anchor and frame counts. '
           'kk_* sets also use the enemy animation names (Idle, Move, Dash, Windup, Strike, Recover, Stun, Death) and carry per-frame eye positions.\n')
out.append('| Asset | Author / licence | Canvas | Animations (frames) | Could be used for | Preview | Size |\n|---|---|---|---|---|---|---|')
for m in sorted(glob.glob(os.path.join(lib.LIB, 'characters', '*', 'meta.json'))):
    d = json.load(open(m)); folder = os.path.dirname(m)
    an = ', '.join(f'{k} {v}' for k, v in d.get('anims', {}).items())
    who = f"{esc(d.get('author', ''))} - {esc(d.get('licence', ''))}"
    out.append(f"| `{os.path.basename(folder)}` | {who} | {d['canvas'][0]}x{d['canvas'][1]} | {an} | {esc(d.get('use', ''))} | {link(os.path.join(folder, 'preview.png'))} | {size_kb(folder)} KB |")
# ---------------- vfx
out.append('\n## Effects (`game/art/library/vfx/<pack>/<effect>/<n>.png`)\n')
out.append('Each pack has `meta.json` (per effect: frames, size, fps, pivot, blend `add`/`mix`, `draw_scale`) and `preview.png`.\n')
for m in sorted(glob.glob(os.path.join(lib.LIB, 'vfx', '*', 'meta.json'))):
    d = json.load(open(m)); folder = os.path.dirname(m); name = os.path.basename(folder)
    local = ' **(local only - not in git, see licence)**' if name.startswith('xyezawr') else ''
    out.append(f"### `{name}`{local}\n\n{esc(d.get('author'))} - {esc(d.get('licence'))} - <{d.get('url')}>  \nCredit: {esc(d.get('credit'))}  \n"
               f"{esc(d.get('notes', ''))} Preview: {link(os.path.join(folder, 'preview.png'))} - {size_kb(folder)} KB\n")
    out.append('| Effect | Frames | Size | fps | Blend | Use |\n|---|---|---|---|---|---|')
    for k, e in d['effects'].items():
        out.append(f"| `{k}` | {e['frames']} | {e['size'][0]}x{e['size'][1]} | {e['fps']} | {e['blend']}{' x' + str(e['draw_scale']) if e.get('draw_scale', 1) != 1 else ''} | {esc(e.get('use', ''))} |")
    out.append('')
# ---------------- environments / props / weapons / ui / textures
for cat, title in (('environments', 'Environments, tilesets and parallax layers'), ('props', 'Props'), ('weapons', 'Weapons'),
                   ('ui', 'UI'), ('textures', 'Textures (seamless pixel tiles)')):
    ms = sorted(glob.glob(os.path.join(lib.LIB, cat, '*', 'meta.json')))
    if not ms: continue
    out.append(f'\n## {title} (`game/art/library/{cat}/`)\n')
    out.append('| Asset | Author / licence | What is inside | Could be used for | Preview | Size |\n|---|---|---|---|---|---|')
    for m in ms:
        d = json.load(open(m)); folder = os.path.dirname(m)
        files = d.get('files') or d.get('objects') or d.get('icons') or {}
        inside = f"{len(files)} files" if files else ''
        if cat == 'ui': inside = f"{len([f for f in os.listdir(folder) if f.endswith('.png')]) or len(files)} images" if not files else f"{len(files)} icons"
        out.append(f"| `{os.path.basename(folder)}` | {esc(d.get('author', ''))} - {esc(d.get('licence', ''))} | {inside}. {esc(d.get('notes', ''))} | "
                   f"{esc(d.get('use', ''))} | {link(os.path.join(folder, 'preview.png'))} | {size_kb(folder)} KB |")
# ---------------- audio
au = os.path.join(lib.LIB, 'audio', 'audio.json')
if os.path.exists(au):
    A = json.load(open(au))
    out.append('\n## Audio (`game/art/library/audio/`)\n')
    out.append('All Ogg Vorbis (sfx mono q4 trimmed and peak-normalised to -1 dBFS; ambience mono q2; music stereo q2).\n')
    out.append('| Folder | Author / licence | Files (seconds) | Use | Credit |\n|---|---|---|---|---|')
    for k, e in A.items():
        files = ', '.join(f"{n[:-4]} ({s})" for n, s in list(e['files'].items())[:12]) + (f" ... +{len(e['files']) - 12} more" if len(e['files']) > 12 else '')
        out.append(f"| `{k}` | {esc(e['author'])} - {esc(e['licence'])} | {files} | {esc(e['use'])} | {esc(e['credit'])} <{e['url']}> |")

intro = open(os.path.join(DES, 'catalogue_intro.md')).read() if os.path.exists(os.path.join(DES, 'catalogue_intro.md')) else '# Art library catalogue\n'
outro = open(os.path.join(DES, 'catalogue_outro.md')).read() if os.path.exists(os.path.join(DES, 'catalogue_outro.md')) else ''
open(os.path.join(DES, 'CATALOGUE.md'), 'w').write(intro.rstrip() + '\n\n' + '\n'.join(out) + '\n\n' + outro)
print('catalogue lines', len(out))
