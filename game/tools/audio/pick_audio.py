# Picks the game's music, ambience and sound effects out of the free library (art/library/audio, see its audio.json for
# authors and licences) and re-encodes them small for a phone download: music Vorbis ~64 kb/s stereo (long tracks cut
# to a few minutes with a fade), ambience and effects mono.
#   python3 game/tools/audio/pick_audio.py
# Output: game/audio/{music,ambience,sfx}/*.ogg and game/audio/CREDITS.md
import json, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, '..', '..')
LIB = os.path.join(GAME, 'art', 'library', 'audio')
OUT = os.path.join(GAME, 'audio')

# out name: (library file, seconds to keep or None, fade-out seconds)
MUSIC = {
    'cathedral': ('music/isao_dark_solemn_choral_organ/dark_solemn_choral_with_organ.ogg', None, 0),
    'ossuary': ('music/umplix_cathedral/cathedral.ogg', None, 0),
    'forge': ('music/foxsynergy_chapel_of_hate/chapel_of_hate.ogg', 150, 4),
    'spire': ('music/matthewpablo_dark_descent/dark_descent.ogg', None, 0),
    'boss': ('music/nene_boss_battle_2_metal/boss_battle_2_opening.ogg', None, 0),
    'final_boss': ('music/matthewpablo_heroic_demise/heroic_demise.ogg', 180, 4),
    'victory': ('music/cesisco_fantasy_choir/fantasy_choir_1.ogg', None, 0),
    'fallen': ('music/cesisco_fantasy_choir/fantasy_choir_3.ogg', None, 0),
}
AMBIENCE = {
    'cathedral': ('ambience/yd_dungeon/dungeon002_0.ogg', 40, 2),
    'ossuary': ('ambience/wortmann_dark_cavern/dark_cavern_ambient_001.ogg', 40, 2),
    'forge': ('ambience/pagdev_fireplace/fire.ogg', None, 0),
    'spire': ('ambience/kindland_forgotten_tomb/forgoten_tombs_1.ogg', 40, 2),
}
S = 'sfx/'
SFX = {
    'swing_1': S + 'artisticdude_swishes/swish_1.ogg', 'swing_2': S + 'artisticdude_swishes/swish_2.ogg',
    'swing_3': S + 'artisticdude_swishes/swish_3.ogg', 'swing_heavy_1': S + 'artisticdude_swishes/swish_8.ogg',
    'swing_heavy_2': S + 'artisticdude_swishes/swish_10.ogg', 'roll_1': S + 'artisticdude_swishes/swish_12.ogg',
    'hit_1': S + 'starninjas_swords/sword_1.ogg', 'hit_2': S + 'starninjas_swords/sword_3.ogg', 'hit_3': S + 'starninjas_swords/sword_5.ogg',
    'punch_1': S + 'remaxim_melee/melee_sound.ogg', 'claw_1': S + 'remaxim_melee/animal_melee_sound.ogg',
    'clash_1': S + 'starninjas_swords/sword_clash_1.ogg', 'clash_2': S + 'starninjas_swords/sword_clash_3.ogg',
    'block_1': S + 'vehicle_weapons_apparel/sword_knife_clash_02.ogg',
    'step_1': S + 'haeldb_footsteps/step_lth1.ogg', 'step_2': S + 'haeldb_footsteps/step_lth2.ogg',
    'jump_1': S + 'vehicle_weapons_apparel/boots_leather_jump_01.ogg', 'land_1': S + 'vehicle_weapons_apparel/boots_leather_step_02.ogg',
    'draw_1': S + 'vehicle_weapons_apparel/seax_unsheathe_01.ogg', 'bow_1': S + 'vehicle_weapons_apparel/arrow_grab_from_quiver_01.ogg',
    'hero_hurt_1': S + 'rubberduck_creatures/grunt_01.ogg', 'hero_hurt_2': S + 'rubberduck_creatures/grunt_03.ogg',
    'enemy_hurt_1': S + 'rubberduck_rpg/creature_hurt_01.ogg', 'enemy_hurt_2': S + 'rubberduck_rpg/creature_hurt_02.ogg',
    'enemy_die_1': S + 'rubberduck_rpg/creature_die_01.ogg', 'roar_1': S + 'rubberduck_rpg/creature_roar_01.ogg',
    'roar_2': S + 'rubberduck_creatures/roar_02.ogg',
    'magic_1': S + 'jaggedstone_magic/magical_1_0.ogg', 'magic_2': S + 'jaggedstone_magic/magical_3.ogg', 'magic_3': S + 'jaggedstone_magic/magical_5.ogg',
    'fire_1': S + 'rubberduck_rpg/spell_fire_01.ogg', 'fire_2': S + 'rubberduck_rpg/spell_fire_04.ogg', 'blast_1': S + 'rubberduck_rpg/spell_fire_06.ogg',
    'stones_1': S + 'rubberduck_rpg/stones_01.ogg', 'stones_2': S + 'rubberduck_rpg/stones_03.ogg',
    'gate_1': S + 'rubberduck_rpg/chain_02.ogg', 'gem_1': S + 'rubberduck_rpg/item_gem_01.ogg', 'coins_1': S + 'rubberduck_rpg/item_coins_02.ogg',
    'drink_1': S + 'jaggedstone_magic/magical_2.ogg',
}


def encode(src, dst, keep=None, fade=0, mono=False, quality='0'):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-i', src]
    filters = []
    if keep:
        cmd += ['-t', str(keep)]
        if fade:
            filters.append(f'afade=t=out:st={keep - fade}:d={fade}')
    if filters:
        cmd += ['-af', ','.join(filters)]
    if mono:
        cmd += ['-ac', '1']
    # a quality ending in k is a target bitrate (Vorbis' quality scale stops at -1, which is not small enough for music)
    cmd += ['-c:a', 'libvorbis'] + (['-b:a', quality] if quality.endswith('k') else ['-q:a', quality]) + [dst]
    subprocess.run(cmd, check=True)


def main():
    meta = json.load(open(os.path.join(LIB, 'audio.json')))
    used = {}
    for name, (rel, keep, fade) in MUSIC.items():
        encode(os.path.join(LIB, rel), os.path.join(OUT, 'music', name + '.ogg'), keep, fade, False, '48k')
        used.setdefault(os.path.dirname(rel), []).append('music/' + name)
    for name, (rel, keep, fade) in AMBIENCE.items():
        encode(os.path.join(LIB, rel), os.path.join(OUT, 'ambience', name + '.ogg'), keep, fade, True, '32k')
        used.setdefault(os.path.dirname(rel), []).append('ambience/' + name)
    for name, rel in SFX.items():
        encode(os.path.join(LIB, rel), os.path.join(OUT, 'sfx', name + '.ogg'), None, 0, True, '2')
        used.setdefault(os.path.dirname(rel), []).append('sfx/' + name)
    lines = ['# Audio credits', '', 'Picked from the free library (art/library/audio, licences checked there) by tools/audio/pick_audio.py.', '',
             '| Used as | Source | Licence | Credit |', '|---|---|---|---|']
    for pack, names in sorted(used.items()):
        m = meta[pack]
        lines.append('| %s | %s | %s | %s |' % (', '.join(names), m.get('url', ''), m['licence'], m['credit']))
    open(os.path.join(OUT, 'CREDITS.md'), 'w').write('\n'.join(lines) + '\n')
    print('done')


main()
