# Builds the audio library (game/art/library/audio/{sfx,ambience,music}/...) from licence-checked downloads.
#   python3 -I game/tools/art/library/build_audio.py <downloads dir>
# Everything becomes Ogg Vorbis (Godot imports it as a streamable AudioStreamOggVorbis):
#   sfx      mono 44.1 kHz q4, leading/trailing silence trimmed, peak-normalised to -1 dBFS
#   ambience mono 44.1 kHz q2 (loops left untouched apart from the level)
#   music    stereo 44.1 kHz q2 (about 96 kbit/s)
# ffmpeg only reads the sound files; nothing in a download is executed.
import glob, json, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib

DL = sys.argv[1]
OUT = os.path.join(lib.LIB, 'audio')
META = {}


def peak(path):
    r = subprocess.run(['ffmpeg', '-hide_banner', '-i', path, '-af', 'volumedetect', '-f', 'null', '-'], capture_output=True, text=True)
    m = re.search(r'max_volume: (-?[\d.]+) dB', r.stderr)
    return float(m.group(1)) if m else 0.0


def conv(src, dst, kind):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    gain = -1.0 - peak(src)
    af = []
    if kind == 'sfx':
        af.append('silenceremove=start_periods=1:start_threshold=-55dB,areverse,silenceremove=start_periods=1:start_threshold=-55dB,areverse')
    af.append(f'volume={gain:.2f}dB')
    ch, q = {'sfx': ('1', '4'), 'ambience': ('1', '2'), 'music': ('2', '2')}[kind]
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', src, '-af', ','.join(af), '-ac', ch, '-ar', '44100',
                    '-c:a', 'libvorbis', '-q:a', q, dst], check=True)
    r = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', dst], capture_output=True, text=True)
    return round(float(r.stdout.strip() or 0), 2)


def G(pattern):
    return sorted(glob.glob(os.path.join(DL, pattern)), key=lambda f: [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', f)])


def group(kind, name, files, *, author, licence, credit, url, use, rename=None, limit=None):
    files = files[:limit] if limit else files
    d = os.path.join(OUT, kind, name)
    entry = dict(author=author, licence=licence, credit=credit, url=url, use=use, files={})
    for i, f in enumerate(files):
        base = rename(i, f) if rename else re.sub(r'[^a-z0-9_]+', '_', os.path.splitext(os.path.basename(f))[0].lower()).strip('_')
        dur = conv(f, os.path.join(d, base + '.ogg'), 'sfx' if kind == 'sfx' else kind)
        entry['files'][base + '.ogg'] = dur
    with open(os.path.join(d, 'meta.json'), 'w') as fh: json.dump(entry, fh, indent=1)
    META[f'{kind}/{name}'] = entry
    print(kind, name, len(files))


CC0 = 'CC0 1.0'


def sfx():
    group('sfx', 'starninjas_swords', G('a_swords_starninjas/x/*/*/sword.*.ogg') + G('a_swords_starninjas/x/*/sword_clash.*.ogg'), author='StarNinjas',
          licence=CC0, credit='StarNinjas (credit optional)', url='https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes',
          use='10 sword attacks (swing+hit) and 10 clashes: hits, parries, shield blocks')
    group('sfx', 'vehicle_weapons_apparel', G('a_weapons_apparel/x/*/sfx/sword-knife-clash-0[1-9].wav') + G('a_weapons_apparel/x/*/sfx/*unsheathe*.wav')
          + G('a_weapons_apparel/x/*/sfx/*-sheathe-0[1-3].wav') + G('a_weapons_apparel/x/*/sfx/boots-leather-*.wav') + G('a_weapons_apparel/x/*/sfx/arrow-grab*0[1-3].wav')
          + G('a_weapons_apparel/x/*/sfx/belt-buckle-0[1-2].wav'), author='Vehicle (Jan Schupke)', licence=CC0, credit='Vehicle / Jan Schupke (credit optional)',
          url='https://opengameart.org/content/fantasy-weapons-and-apparel-sfx-library',
          use='metal-on-metal clashes, weapon draw / sheathe (weapon swap), leather boot steps and jumps, arrow draw (bow), buckles (equip)')
    group('sfx', 'artisticdude_swishes', G('a_swishes/x/*/*/swish-*.wav'), author='artisticdude', licence=CC0, credit='artisticdude (credit optional)',
          url='https://opengameart.org/content/swishes-sound-pack', use='13 whooshes (4 light, 9 heavy): swings that miss, dodge roll, spear thrust')
    group('sfx', 'remaxim_melee', G('a_melee3/x/*/*/*.wav'), author='remaxim', licence=CC0, credit='remaxim (credit optional)',
          url='https://opengameart.org/content/3-melee-sounds', use='sword / blunt / claw melee whooshes')
    rpg = [f for f in G('a_rpg80/x/*/*.ogg') if re.search(r'/(blade|metal|chain|spell|creature_(die|hurt|roar|monster)|item_coins|item_gem|lock|book|stones|wood)_', f)]
    group('sfx', 'rubberduck_rpg', rpg, author='rubberduck', licence=CC0, credit='rubberduck (credit optional)', url='https://opengameart.org/content/80-cc0-rpg-sfx',
          use='blades, metal, chains (gates, hanging cages), fire spells, creature hurt/die/roar, coins and gems (cells pickup), locks, books, stones, wood')
    cr = [f for f in G('a_creature80/x/*/*.ogg') if re.search(r'/(monster|roar|troll|grunt|hurt|scream|howl|breath|weird)_?', f)]
    group('sfx', 'rubberduck_creatures', cr, author='rubberduck', licence=CC0, credit='rubberduck (credit optional)', url='https://opengameart.org/content/80-cc0-creature-sfx',
          use='monster growls, roars, troll grunts, hurt and scream sounds, a howl (hell hound), breath (ghost)')
    group('sfx', 'haeldb_footsteps', G('a_footsteps_armor/x/*/*/*.ogg'), author='HaelDB', licence='CC0 1.0 (dual-licensed CC0 / OGA-BY 3.0; used under CC0)',
          credit='HaelDB (credit optional)', url='https://opengameart.org/content/footsteps-leather-cloth-armor', use='leather, cloth and metal-armour footsteps')
    group('sfx', 'jaggedstone_magic', G('a_magic_jagged/*.ogg'), author='JaggedStone', licence=CC0, credit='JaggedStone (credit optional)',
          url='https://opengameart.org/content/magic-spell-sfx', use='7 magic casts (wand, boons, shrine)')
    group('sfx', 'antumdeluge_fire', G('a_fire_crackling/*.ogg'), author='AntumDeluge', licence=CC0, credit='AntumDeluge (credit optional)',
          url='https://opengameart.org/content/fire-crackling', use='short fire crackle (torch lit, fire hit)')


def ambience():
    group('ambience', 'pagdev_fireplace', G('a_fireplace/*.wav'), author='PagDev', licence=CC0, credit='PagDev (credit optional)',
          url='https://opengameart.org/content/fireplace-sound-loop', use='fireplace loop: bonfire / brazier / Molten Forge bed')
    group('ambience', 'yd_dungeon', G('a_amb_dungeon_yd/*.ogg'), author='yd', licence=CC0, credit='yd (credit optional)',
          url='https://opengameart.org/content/dungeon-ambience', use='dark dungeon exploration bed')
    group('ambience', 'wortmann_dark_cavern', G('a_amb_cavern/*.ogg'), author='Paul Wortmann', licence=CC0, credit='Paul Wortmann (credit optional)',
          url='https://opengameart.org/content/dark-cavern-ambient', use='looping cavern drones: Frost Ossuary / crypt')
    group('ambience', 'jaggedstone_dungeon_loop', G('a_amb_loop_dungeon/*.ogg'), author='JaggedStone', licence=CC0, credit='JaggedStone (credit optional)',
          url='https://opengameart.org/content/loopable-dungeon-ambience', use='loopable dungeon ambience')
    group('ambience', 'ogrebane_dark', G('a_amb_ogrebane/x/*/*/*.wav'), author='Ogrebane', licence=CC0, credit='Ogrebane (credit optional)',
          url='https://opengameart.org/content/dark-ambiences', use='5 dark ambiences: cathedral hall, boss arena tension')
    group('ambience', 'kindland_forgotten_tomb', G('a_amb_tomb/*.mp3'), author='kindland', licence=CC0, credit='kindland (credit optional)',
          url='https://opengameart.org/content/forgoten-tomb-ambience', use='forgotten-tomb ambience: crypt rooms')


def music():
    group('music', 'isao_dark_solemn_choral_organ', G('m_solemn_choral/*.mp3'), author='ISAo', licence='OGA-BY 3.0',
          credit='"Dark Solemn Choral with Organ" (Beyond Redemption, demo) by ISAo - https://airyluvs.com/ - OGA-BY 3.0',
          url='https://opengameart.org/content/dark-solemn-choral-with-organ', use='THE dark choir + organ theme: title screen, cathedral, Hollow Bishop',
          rename=lambda i, f: 'dark_solemn_choral_with_organ')
    group('music', 'cesisco_fantasy_choir', G('m_fantasy_choir/x/*/*.wav'), author='cesisco', licence=CC0, credit='cesisco (credit optional)',
          url='https://opengameart.org/content/fantasy-choir-3-orchestral-pieces', use='3 orchestral choir pieces: boss intros, victory, between-runs hub')
    group('music', 'umplix_cathedral', G('m_cathedral_umplix/*.wav'), author='Umplix', licence=CC0, credit='Umplix (credit optional)',
          url='https://opengameart.org/content/cathedral-0', use='"Cathedral": slow emotional theme for the Cathedral world / game over')
    group('music', 'yubatake_fugue_b_minor', G('m_fugue/x/*/*.flac'), author='Yubatake', licence='CC-BY 4.0',
          credit='"Fugue in B Minor" by Yubatake (OpenGameArt.org), CC-BY 4.0', url='https://opengameart.org/content/fugue-in-b-minor',
          use='pipe-organ fugue: cathedral exploration, organ boss', rename=lambda i, f: 'fugue_in_b_minor')
    group('music', 'yubatake_elegy_dm', G('m_elegy/*.ogg'), author='Yubatake', licence='CC-BY 4.0', credit='"Elegy Dm" by Yubatake (OpenGameArt.org), CC-BY 4.0',
          url='https://opengameart.org/content/elegy-dm', use='sacred strings adagio with choir: run end / credits', rename=lambda i, f: 'elegy_dm')
    group('music', 'nene_boss_battle_2_metal', G('m_boss_metal/x/*/*.wav'), author='nene', licence=CC0, credit='nene (credit optional)',
          url='https://opengameart.org/content/boss-battle-2-symphonic-metal', use='symphonic metal boss fight (opening + loop; the pack swaps the names, see the page)',
          rename=lambda i, f: 'boss_battle_2_' + ('loop' if 'opening' in f else 'opening'))
    group('music', 'matthewpablo_dark_descent', G('m_dark_descent/*.mp3'), author='Matthew Pablo', licence='CC-BY 3.0',
          credit='"Dark Descent" by Matthew Pablo (http://www.matthewpablo.com), CC-BY 3.0', url='https://opengameart.org/content/dark-descent',
          use='orchestral dread with choir: descending into a world', rename=lambda i, f: 'dark_descent')
    group('music', 'matthewpablo_heroic_demise', G('m_heroic_demise/*.mp3'), author='Matthew Pablo', licence='CC-BY 3.0',
          credit='"Heroic Demise" by Matthew Pablo (http://www.matthewpablo.com), CC-BY 3.0', url='https://opengameart.org/content/heroic-demise-updated-version',
          use='epic battle / final boss', rename=lambda i, f: 'heroic_demise')
    group('music', 'foxsynergy_chapel_of_hate', G('m_chapel_of_hate/*.mp3'), author='FoxSynergy', licence='CC-BY 3.0',
          credit='"Chapel of Hate" by FoxSynergy, CC-BY 3.0', url='https://opengameart.org/content/chapel-of-hate',
          use='dark chapel organ-rock: cathedral combat', rename=lambda i, f: 'chapel_of_hate')


if __name__ == '__main__':
    sfx(); ambience(); music()
    with open(os.path.join(OUT, 'audio.json'), 'w') as fh: json.dump(META, fh, indent=1)
