# Art library catalogue

Free, licence-checked art, effects and sound for **Cinder & Crown**, converted for the 384x216 view (16 px tiles, a ~45 px
hero, sprite-frame enemies and effects). Everything lives in `game/art/library/`; the scripts that made it are in
`game/tools/art/library/` and can be re-run from the original downloads (every source URL is listed below).

Generated tables: `python3 -I game/tools/art/library/build_catalogue.py` (it pastes this intro and `catalogue_outro.md`
around tables built from each asset's `meta.json`). Credit lines to ship: [CREDITS.md](CREDITS.md).

## How to use the library

- **Nothing here ships by accident.** `game/art/library/.gdignore` makes Godot skip the whole folder (no import, not in the
  web export). To adopt an asset, copy its folder (without `source/`) to where the game expects it, e.g.
  `game/art/library/characters/dark_knight/` -> `game/art/enemies/dark_knight/`, and add its credit line if it has one.
- **Scale.** Pixel-art sets are kept at 1x: Gothicvania and LuizMelo characters are 40-60 px tall, the same as the hero;
  tiles are 16 px. Rendered sets (`dark_knight`, `kk_*`, props, weapons) were rendered at 8x and shrunk with the
  `enemy_pixel.py` look (24-32 colours, dark outline). Painted / HD effects are stored at about 2x and carry
  `draw_scale: 0.5` in their meta (draw at half size, like `game/art/fx_painted`).
- **Mood.** Bright packs got an `ashen` grade (desaturated, cool shadows, warm highlights; `lib.ashen()`); colourful
  environments carry both the original and an `ashen/` copy.
- **Licences.** Only CC0 / public domain, CC-BY 3.0/4.0, OGA-BY 3.0 and free-for-games licences were taken. The GitHub repo is
  **public**, so packs whose licence forbids redistributing the files (XYEzawr) are built into the library folder locally but
  kept out of git by `vfx/.gitignore`; they may ship inside the game build. See "Licence notes" at the end.
- **Sizes.** The committed library is about 56 MB on disk: audio 26 MB (music 19 MB), effects 14 MB, characters 6 MB,
  UI 6 MB, the rest under 3 MB each. A game build only pays for what it copies out.

## What it could replace or add in the current game

| Game asset now | Library candidates |
|---|---|
| Shambler / Frost Ghoul (`enemies/shambler`, `frost_ghoul`) | `gv_burning_ghoul` (Molten Forge), `kk_skeleton_minion` (rises from the floor), `gv_skeleton` |
| Crown Guard / Storm Knight | `dark_knight` (elite), `kk_ashen_knight`, `lm_red_warrior`, `kk_skeleton_warrior` (has Block) |
| Penitent (shield + spear) | `kk_skeleton_warrior`, `lm_skeleton` (sword + shield, Shield pose) |
| Crown Brute / Forge Brute | `gv_hell_beast` (fire breath), `kk_greatsword_knight` (chop + spin) |
| Ember / Rime / Storm Wisp | `gv_fire_skull`, `gv_ghost`, `gv_reaper_ghost` |
| Cinder Bat / Magma Bat | `lm_flying_eye`, `gv_fire_skull` |
| Bosses (Hollow Bishop, Forge Tyrant, Storm King, Rime Colossus) | `gv_demon`, `gv_angel`, `gv_nightmare`, `lm_fallen_king`, `lm_evil_wizard`, `kk_skeleton_mage` (summons), `dark_knight` as a mirror boss |
| Boss summons / floor hazards | `kk_skeleton_minion` and `gv_skeleton` Rise, `magic_circles`, `pvfx_foundry/harvest_seal`, `pvfx_foundry/earth_rupture` |
| `fx/slash_*`, hit sparks, parry burst | `cethiel_slashes`, `pvfx_foundry/crescent_slash`, `pvfx_foundry/arcane_parry`, `matheusgg28_pixel_fx/impact_*`, `codemanu_pixel_fx/weaponhit` |
| Death puff, dust, landing | `matheusgg28_pixel_fx/dust*`, `pvfx_foundry/landing_dust`, `pvfx_foundry/smoke_puff`, `pixel_misc_cc0/gv_enemy_death` |
| Blood / gore on kill | `pixel_misc_cc0/rc_blood_*` and `rc_gibs` (pixel), `rendered_cc0/sinestesia_*` |
| `fx_painted` fire / frost / lightning | `codemanu_pixel_fx` (fire, flamelash, freezing, bluefire), `rendered_cc0` fire rings, `pixel_misc_cc0/gv_lightning`, XYEzawr fire packs |
| Cathedral backdrop / tiles | `gv_church` (+ `ashen/`), `gothic_window_tiles`, `gv_gothic_castle`, `textures/bricks089` |
| Frost Ossuary | `gv_old_dark_castle` (crypt + stained window), `textures/rocks025`, `yd_statues` |
| Molten Forge | `jetrel_castle` tiles, `kaykit_dungeon_props` (barrels, kegs, rubble), chains and cages from `ettingrinder_dark_fantasy`, `rendered_cc0/limphands_ps1_fire`, `pvfx_foundry/ember_jet` |
| Storm Spire | `gv_night_town_bg`, `gv_gothic_horror` clouds, AI storm-spire far layer (`ai_samples/`) |
| Hub / between-runs shop | `gv_town`, `pagdev_fireplace` loop, `cesisco_fantasy_choir` |
| Boons, shop and HUD | `game_icons` (card48 tiles), `rpg_icons_496`, `tiny_rpg_dark_dwellers_gui` bars and frames |
| Sound (the game has no audio files yet) | sword hits `starninjas_swords`, swings `artisticdude_swishes`, steps `haeldb_footsteps`, ambience `ogrebane_dark`, music `isao_dark_solemn_choral_organ` |

## Top picks (best first)

**Characters / enemies**
1. `dark_knight` (comphonia, CC0) - a black-armoured, Souls-like knight with 16 animations (block, three slashes, kick, cast,
   death, draw sword) shrunk to pixel art at hero scale. Elite enemy, mirror-knight boss or an alternative hero.
2. `gv_reaper_ghost`, `gv_hell_hound`, `gv_demon`, `gv_nightmare`, `gv_fire_skull`, `gv_burning_ghoul`, `gv_angel` (ansimuz, CC0) -
   dark Castlevania-style pixel enemies and bosses that already match the 384x216 scale.
3. `kk_skeleton_warrior/mage/rogue/minion`, `kk_ashen_knight`, `kk_greatsword_knight` (KayKit, CC0) - rigged 3D characters rendered
   with the enemy pipeline and the enemy animation names (Idle Move Dash Windup Strike Recover Stun Death, plus Block,
   Rise, Summon, Taunt, Thrust, Roll, Spin). Chunky chibi proportions - good for hordes and summons.
4. `lm_fallen_king`, `lm_queen_blade`, `lm_red_warrior`, `lm_evil_wizard`, `lm_skeleton` (LuizMelo, CC0) - full move sets with
   built-in slash arcs, ashen-graded.

**Effects**: `pvfx_foundry` (26 effects incl. crescent slash, parry flash, ground rupture, rift portal), `codemanu_pixel_fx`
(owner's pick, 20 effects, CC-BY), `matheusgg28_pixel_fx` (owner's pick: explosions, punch/projectile impacts, dust,
shockwaves), `cethiel_slashes` (20 glowing slash arcs in gold / violet / blue / fire), `rendered_cc0` (fire rings, blood,
smoke aura, PS1 fire), XYEzawr packs (local only).

**Worlds**: `gv_church` (cathedral tiles + wall panels), `gv_gothic_castle`, `gv_old_dark_castle` (crypt with a stained window),
`gv_cemetery` (blood-moon graveyard parallax), `gv_night_town_bg` (7-layer parallax), `gothic_window_tiles`,
`ettingrinder_dark_fantasy` props (gibbet cage, candelabras, chains, impaled heads, gargoyles, sword in stone).

**UI**: `game_icons` (85 icons + gold boon tiles), `tiny_rpg_dark_dwellers_gui` (dark 9-slice frames, buttons, bars),
`rpg_icons_496`.

**Audio**: `isao_dark_solemn_choral_organ` (the dark choir + organ theme), `yubatake_fugue_b_minor` (pipe organ),
`cesisco_fantasy_choir`, `nene_boss_battle_2_metal`, `starninjas_swords` + `vehicle_weapons_apparel` (hits, clashes, draws),
`ogrebane_dark` and `wortmann_dark_cavern` (ambience beds), `pagdev_fireplace` (bonfire loop).

## Characters (`game/art/library/characters/`)

Frames are `<Anim>_<n>.png` like `game/art/enemies/*`; `meta.json` has canvas, feet anchor and frame counts. kk_* sets also use the enemy animation names (Idle, Move, Dash, Windup, Strike, Recover, Stun, Death) and carry per-frame eye positions.

| Asset | Author / licence | Canvas | Animations (frames) | Could be used for | Preview | Size |
|---|---|---|---|---|---|---|
| `dark_knight` | comphonia - CC0 1.0 | 120x80 | Idle 6, Walk 8, Run 8, Attack1 8, Slash 9, Slash2 14, Slash3 10, Block 4, BlockIdle 4, Impact 4, Death 10, Jump 6, Kick 8, Casting 8, PowerUp 8, DrawSword 6 | the most Souls-like figure in the library: a black-armoured knight with block, parry-able slashes, kick and cast. An elite enemy, a mirror-knight boss, or an alternative hero | [preview.png](../../game/art/library/characters/dark_knight/preview.png) | 651 KB |
| `gv_angel` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 104x120 | Idle 8, Attack 3 | winged fallen angel: cathedral boss or statue that wakes | [preview.png](../../game/art/library/characters/gv_angel/preview.png) | 46 KB |
| `gv_burning_ghoul` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 56x56 | Walk 8, WalkAlt 8 | shambling ghoul with a burning head: a Molten Forge Shambler | [preview.png](../../game/art/library/characters/gv_burning_ghoul/preview.png) | 29 KB |
| `gv_church_wizard` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 72x56 | Idle 5, Cast 10 | hooded fire caster: a cathedral cultist | [preview.png](../../game/art/library/characters/gv_church_wizard/preview.png) | 37 KB |
| `gv_demon` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 232x176 | Idle 6, Attack 11, AttackNoBreath 8 | big winged demon with a blue fire breath: boss (Storm Spire or a secret boss) | [preview.png](../../game/art/library/characters/gv_demon/preview.png) | 183 KB |
| `gv_fire_skull` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 96x104 | Idle 8, NoFire 4 | flaming skull: an Ember Wisp variant / Molten Forge flyer | [preview.png](../../game/art/library/characters/gv_fire_skull/preview.png) | 29 KB |
| `gv_ghost` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 40x64 | Float 4, FloatHalo 4 | small drifting ghost | [preview.png](../../game/art/library/characters/gv_ghost/preview.png) | 17 KB |
| `gv_gothic_hero` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 88x80 | Idle 4, Run 12, Attack 6, Jump 5, Hurt 3, Crouch 3, CrouchSlash 4, JumpAttack 6 | red-caped swordsman with a full move set: rival hunter NPC or alternative hero | [preview.png](../../game/art/library/characters/gv_gothic_hero/preview.png) | 113 KB |
| `gv_hell_beast` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 56x64 | Idle 6, Breath 4 | horned brute that breathes fire: Forge Brute alternative | [preview.png](../../game/art/library/characters/gv_hell_beast/preview.png) | 23 KB |
| `gv_hell_cat` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 96x40 | Run 4 | flaming hell-cat runner | [preview.png](../../game/art/library/characters/gv_hell_cat/preview.png) | 10 KB |
| `gv_hell_hound` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 56x48 | Idle 6, Walk 12, Run 5, Jump 6 | undead hound with ember stripes: fast pouncing enemy | [preview.png](../../game/art/library/characters/gv_hell_hound/preview.png) | 43 KB |
| `gv_nightmare` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 128x96 | Idle 4, Gallop 4 | black spectral horse with blue flame mane: charging mini-boss / mount | [preview.png](../../game/art/library/characters/gv_nightmare/preview.png) | 35 KB |
| `gv_reaper_ghost` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 56x72 | Idle 7, Appear 7, Shriek 4, Vanish 7 | hooded wraith that fades in/out and shrieks: a hollow phantom enemy | [preview.png](../../game/art/library/characters/gv_reaper_ghost/preview.png) | 30 KB |
| `gv_skeleton` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 40x48 | Walk 8, Rise 6 | skeleton that climbs out of the ground: a summon for bosses | [preview.png](../../game/art/library/characters/gv_skeleton/preview.png) | 18 KB |
| `gv_skeleton_clothed` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 40x48 | Walk 8, Rise 6 | robed skeleton, same moves | [preview.png](../../game/art/library/characters/gv_skeleton_clothed/preview.png) | 20 KB |
| `gv_spider` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 32x24 | Walk 4 | crypt spider (crawler enemy) | [preview.png](../../game/art/library/characters/gv_spider/preview.png) | 5 KB |
| `gv_swamp_thing` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 32x40 | Walk 4 | mossy swamp creature | [preview.png](../../game/art/library/characters/gv_swamp_thing/preview.png) | 7 KB |
| `kk_ashen_knight` | Kay Lousberg - CC0 1.0 | 112x72 | Idle 6, Move 8, Dash 6, Windup 4, Strike 3, Recover 3, Stun 3, Death 6, Block 3, Jump 6, Roll 5, Thrust 5 | iron knight (tinted dark) with slash, thrust, block, roll and jump: Crown Guard upgrade or a hero test double | [preview.png](../../game/art/library/characters/kk_ashen_knight/preview.png) | 289 KB |
| `kk_greatsword_knight` | Kay Lousberg - CC0 1.0 | 112x72 | Idle 6, Move 8, Dash 6, Windup 4, Strike 3, Recover 3, Stun 3, Death 6, Spin 8 | greatsword knight with a two-hand chop and a spin attack: heavy elite | [preview.png](../../game/art/library/characters/kk_greatsword_knight/preview.png) | 231 KB |
| `kk_skeleton_mage` | Kay Lousberg - CC0 1.0 | 112x72 | Idle 6, Move 8, Dash 6, Windup 4, Strike 3, Recover 3, Stun 3, Death 6, Rise 6, Summon 6, Taunt 4 | staff caster with summon: a necromancer that raises kk_skeleton_minion | [preview.png](../../game/art/library/characters/kk_skeleton_mage/preview.png) | 238 KB |
| `kk_skeleton_minion` | Kay Lousberg - CC0 1.0 | 112x72 | Idle 6, Move 8, Dash 6, Windup 3, Strike 3, Recover 3, Stun 3, Death 6, Rise 6, Taunt 4 | unarmed minion that rises from the ground: swarm / summon | [preview.png](../../game/art/library/characters/kk_skeleton_minion/preview.png) | 155 KB |
| `kk_skeleton_rogue` | Kay Lousberg - CC0 1.0 | 112x72 | Idle 6, Move 8, Dash 5, Windup 4, Strike 3, Recover 3, Stun 3, Death 6, Rise 6, Taunt 4 | hooded dual-blade skeleton with a dodge: fast flanker | [preview.png](../../game/art/library/characters/kk_skeleton_rogue/preview.png) | 189 KB |
| `kk_skeleton_warrior` | Kay Lousberg - CC0 1.0 | 112x72 | Idle 6, Move 8, Dash 6, Windup 4, Strike 3, Recover 3, Stun 3, Death 6, Block 3, Rise 6, Taunt 4 | sword-and-shield skeleton with block, rise-from-the-floor and taunt: the basic hollow undead / boss summon | [preview.png](../../game/art/library/characters/kk_skeleton_warrior/preview.png) | 228 KB |
| `lm_evil_wizard` | LuizMelo - CC0 1.0 | 104x72 | Idle 8, Move 8, Attack 8, Hit 4, Death 5 | fire-casting sorcerer: caster enemy or the Hollow Bishop stand-in | [preview.png](../../game/art/library/characters/lm_evil_wizard/preview.png) | 86 KB |
| `lm_fallen_king` | LuizMelo - CC0 1.0 | 160x112 | Idle 6, Run 8, Attack1 6, Attack2 6, Hit 4, Jump 2, Fall 2, Death 11 | crowned swordsman: a mini-boss or the Crown Guard captain (ashen-graded) | [preview.png](../../game/art/library/characters/lm_fallen_king/preview.png) | 161 KB |
| `lm_flying_eye` | LuizMelo - CC0 1.0 | 64x48 | Flight 8, Death 4, Attack 8, Hit 4 | flying eye-bat: replaces or joins the Cinder Bat | [preview.png](../../game/art/library/characters/lm_flying_eye/preview.png) | 33 KB |
| `lm_goblin` | LuizMelo - CC0 1.0 | 96x48 | Idle 4, Death 4, Run 8, Attack 8, Hit 4 | small knife goblin: fast weak enemy | [preview.png](../../game/art/library/characters/lm_goblin/preview.png) | 51 KB |
| `lm_queen_blade` | LuizMelo - CC0 1.0 | 152x112 | Idle 8, Run 8, Attack1 4, Attack2 4, Attack3 4, Hit 4, HitFlash 4, Jump 2, Fall 2, Death 6 | caped royal duellist: rival / mini-boss | [preview.png](../../game/art/library/characters/lm_queen_blade/preview.png) | 162 KB |
| `lm_red_warrior` | LuizMelo - CC0 1.0 | 120x80 | Idle 8, Run 8, Attack1 4, Attack2 4, Attack3 4, Attack4 4, Hit 4, HitFlash 4, Jump 2, Fall 2, Death 6 | sword-and-board soldier: a human enemy or NPC duellist | [preview.png](../../game/art/library/characters/lm_red_warrior/preview.png) | 107 KB |
| `lm_skeleton` | LuizMelo - CC0 1.0 | 104x64 | Idle 4, Death 4, Walk 4, Shield 4, Attack 8, Hit 4 | sword-and-shield skeleton with a block pose: a basic undead enemy | [preview.png](../../game/art/library/characters/lm_skeleton/preview.png) | 63 KB |

## Effects (`game/art/library/vfx/<pack>/<effect>/<n>.png`)

Each pack has `meta.json` (per effect: frames, size, fps, pivot, blend `add`/`mix`, `draw_scale`) and `preview.png`.

### `cethiel_slashes`

Cethiel - CC0 1.0 - <https://opengameart.org/content/weapon-slash-effect>  
Credit: Cethiel (credit optional)  
5 slash shapes x 4 colours, 6 frames each, shrunk to half size (draw at 1.0 for a ~60 px arc, these are already game scale). Preview: [preview.png](../../game/art/library/vfx/cethiel_slashes/preview.png) - 515 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `gold_1` | 6 | 47x46 | 20 | add | slash arc behind the swing (shape 1) |
| `gold_2` | 6 | 44x43 | 20 | add | slash arc behind the swing (shape 2) |
| `gold_3` | 6 | 62x60 | 20 | add | slash arc behind the swing (shape 3) |
| `gold_4` | 6 | 44x50 | 20 | add | slash arc behind the swing (shape 4) |
| `gold_5` | 6 | 55x54 | 20 | add | slash arc behind the swing (shape 5) |
| `violet_1` | 6 | 47x47 | 20 | add | slash arc behind the swing (shape 1) |
| `violet_2` | 6 | 45x44 | 20 | add | slash arc behind the swing (shape 2) |
| `violet_3` | 6 | 62x60 | 20 | add | slash arc behind the swing (shape 3) |
| `violet_4` | 6 | 44x50 | 20 | add | slash arc behind the swing (shape 4) |
| `violet_5` | 6 | 56x54 | 20 | add | slash arc behind the swing (shape 5) |
| `blue_1` | 6 | 47x46 | 20 | add | slash arc behind the swing (shape 1) |
| `blue_2` | 6 | 43x42 | 20 | add | slash arc behind the swing (shape 2) |
| `blue_3` | 6 | 62x60 | 20 | add | slash arc behind the swing (shape 3) |
| `blue_4` | 6 | 42x50 | 20 | add | slash arc behind the swing (shape 4) |
| `blue_5` | 6 | 54x52 | 20 | add | slash arc behind the swing (shape 5) |
| `fire_1` | 6 | 50x50 | 20 | add | slash arc behind the swing (shape 1) |
| `fire_2` | 6 | 48x48 | 20 | add | slash arc behind the swing (shape 2) |
| `fire_3` | 6 | 62x61 | 20 | add | slash arc behind the swing (shape 3) |
| `fire_4` | 6 | 46x50 | 20 | add | slash arc behind the swing (shape 4) |
| `fire_5` | 6 | 58x58 | 20 | add | slash arc behind the swing (shape 5) |

### `codemanu_pixel_fx`

CodeManu - CC-BY 4.0 (itch.io licence field; the page text says public domain - we credit to be safe) - <https://codemanu.itch.io/pixelart-effect-pack>  
Credit: Free Pixel Effects Pack by CodeManu (CC-BY 4.0)  
100x100 grid sheets, empty cells dropped, subsampled to 16 frames max. Preview: [preview.png](../../game/art/library/vfx/codemanu_pixel_fx/preview.png) - 909 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `magicspell` | 16 | 47x46 | 16 | add | spell burst |
| `magic8` | 16 | 33x59 | 16 | add | figure-eight rune trail |
| `bluefire` | 16 | 45x42 | 16 | add | soul fire |
| `casting` | 16 | 27x51 | 16 | add | cast glyph |
| `magickahit` | 16 | 15x61 | 16 | add | magic impact |
| `flamelash` | 16 | 44x42 | 16 | add | fire whip slash |
| `firespin` | 16 | 38x38 | 16 | add | fire vortex |
| `protectioncircle` | 16 | 34x34 | 16 | add | ward circle |
| `brightfire` | 16 | 16x32 | 16 | add | holy fire |
| `weaponhit` | 16 | 37x37 | 16 | add | weapon hit spark |
| `fire` | 16 | 24x51 | 16 | add | fire column |
| `nebula` | 16 | 75x76 | 16 | add | mist cloud |
| `vortex` | 16 | 76x73 | 16 | add | void vortex |
| `phantom` | 16 | 69x71 | 16 | mix | ghost / soul burst |
| `loading` | 16 | 62x62 | 16 | add | spinner (loading / saving icon) |
| `sunburn` | 16 | 60x56 | 16 | add | sun flare |
| `felspell` | 16 | 71x70 | 16 | mix | curse cast |
| `midnight` | 16 | 56x56 | 16 | mix | dark burst |
| `freezing` | 16 | 80x78 | 16 | add | ice burst |
| `magicbubbles` | 16 | 50x53 | 16 | add | bubbles (poison / swamp) |

### `kenney_particles`

Kenney (www.kenney.nl) - CC0 1.0 - <https://opengameart.org/content/particle-pack-80-sprites>  
Credit: Kenney (credit optional)  
Particle textures for GPUParticles2D / CPUParticles2D, shrunk to 64 px. Preview: [preview.png](../../game/art/library/vfx/kenney_particles/preview.png) - 543 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `circle_01` | 1 | 64x64 | 1 | add | particle texture |
| `circle_02` | 1 | 64x64 | 1 | add | particle texture |
| `circle_03` | 1 | 64x64 | 1 | add | particle texture |
| `circle_04` | 1 | 64x64 | 1 | add | particle texture |
| `circle_05` | 1 | 64x64 | 1 | add | particle texture |
| `dirt_01` | 1 | 64x64 | 1 | add | particle texture |
| `dirt_02` | 1 | 64x64 | 1 | add | particle texture |
| `dirt_03` | 1 | 64x64 | 1 | add | particle texture |
| `fire_01` | 1 | 64x64 | 1 | add | particle texture |
| `fire_02` | 1 | 64x64 | 1 | add | particle texture |
| `flame_01` | 1 | 64x64 | 1 | add | particle texture |
| `flame_02` | 1 | 64x64 | 1 | add | particle texture |
| `flame_03` | 1 | 64x64 | 1 | add | particle texture |
| `flame_04` | 1 | 64x64 | 1 | add | particle texture |
| `flame_05` | 1 | 64x64 | 1 | add | particle texture |
| `flame_06` | 1 | 64x64 | 1 | add | particle texture |
| `flare_01` | 1 | 64x64 | 1 | add | particle texture |
| `light_01` | 1 | 64x64 | 1 | add | particle texture |
| `light_02` | 1 | 64x64 | 1 | add | particle texture |
| `light_03` | 1 | 64x64 | 1 | add | particle texture |
| `magic_01` | 1 | 64x64 | 1 | add | particle texture |
| `magic_02` | 1 | 64x64 | 1 | add | particle texture |
| `magic_03` | 1 | 64x64 | 1 | add | particle texture |
| `magic_04` | 1 | 64x64 | 1 | add | particle texture |
| `magic_05` | 1 | 64x64 | 1 | add | particle texture |
| `muzzle_01` | 1 | 64x64 | 1 | add | particle texture |
| `muzzle_02` | 1 | 64x64 | 1 | add | particle texture |
| `muzzle_03` | 1 | 64x64 | 1 | add | particle texture |
| `muzzle_04` | 1 | 64x64 | 1 | add | particle texture |
| `muzzle_05` | 1 | 64x64 | 1 | add | particle texture |
| `scorch_01` | 1 | 64x64 | 1 | add | particle texture |
| `scorch_02` | 1 | 64x64 | 1 | add | particle texture |
| `scorch_03` | 1 | 64x64 | 1 | add | particle texture |
| `scratch_01` | 1 | 64x64 | 1 | add | particle texture |
| `slash_01` | 1 | 64x64 | 1 | add | particle texture |
| `slash_02` | 1 | 64x64 | 1 | add | particle texture |
| `slash_03` | 1 | 64x64 | 1 | add | particle texture |
| `slash_04` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_01` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_02` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_03` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_04` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_05` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_06` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_07` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_08` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_09` | 1 | 64x64 | 1 | add | particle texture |
| `smoke_10` | 1 | 64x64 | 1 | add | particle texture |
| `spark_01` | 1 | 64x64 | 1 | add | particle texture |
| `spark_02` | 1 | 64x64 | 1 | add | particle texture |
| `spark_03` | 1 | 64x64 | 1 | add | particle texture |
| `spark_04` | 1 | 64x64 | 1 | add | particle texture |
| `spark_05` | 1 | 64x64 | 1 | add | particle texture |
| `spark_06` | 1 | 64x64 | 1 | add | particle texture |
| `spark_07` | 1 | 64x64 | 1 | add | particle texture |
| `star_01` | 1 | 64x64 | 1 | add | particle texture |
| `star_02` | 1 | 64x64 | 1 | add | particle texture |
| `star_03` | 1 | 64x64 | 1 | add | particle texture |
| `star_04` | 1 | 64x64 | 1 | add | particle texture |
| `star_05` | 1 | 64x64 | 1 | add | particle texture |
| `star_06` | 1 | 64x64 | 1 | add | particle texture |
| `star_07` | 1 | 64x64 | 1 | add | particle texture |
| `star_08` | 1 | 64x64 | 1 | add | particle texture |
| `star_09` | 1 | 64x64 | 1 | add | particle texture |
| `symbol_01` | 1 | 64x64 | 1 | add | particle texture |
| `symbol_02` | 1 | 64x64 | 1 | add | particle texture |
| `trace_01` | 1 | 64x64 | 1 | add | particle texture |
| `trace_02` | 1 | 64x64 | 1 | add | particle texture |
| `trace_03` | 1 | 64x64 | 1 | add | particle texture |
| `trace_04` | 1 | 64x64 | 1 | add | particle texture |
| `trace_05` | 1 | 64x64 | 1 | add | particle texture |
| `trace_06` | 1 | 64x64 | 1 | add | particle texture |
| `trace_07` | 1 | 64x64 | 1 | add | particle texture |
| `twirl_01` | 1 | 64x64 | 1 | add | particle texture |
| `twirl_02` | 1 | 64x64 | 1 | add | particle texture |
| `twirl_03` | 1 | 64x64 | 1 | add | particle texture |
| `window_01` | 1 | 64x64 | 1 | add | particle texture |
| `window_02` | 1 | 64x64 | 1 | add | particle texture |
| `window_03` | 1 | 64x64 | 1 | add | particle texture |
| `window_04` | 1 | 64x64 | 1 | add | particle texture |

### `magic_circles`

Luke.RUSTLTD - CC0 1.0 - <https://opengameart.org/content/4-summoning-circles>  
Credit: Luke.RUSTLTD (credit optional)  
Single images (spin / scale them in code). 128 px; tint with modulate. Preview: [preview.png](../../game/art/library/vfx/magic_circles/preview.png) - 120 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `circle4` | 1 | 128x128 | 1 | add | summoning / boss floor circle, ward under the player |
| `circle5` | 1 | 128x128 | 1 | add | summoning / boss floor circle, ward under the player |
| `circle6` | 1 | 128x128 | 1 | add | summoning / boss floor circle, ward under the player |
| `circle7` | 1 | 128x128 | 1 | add | summoning / boss floor circle, ward under the player |

### `matheusgg28_pixel_fx`

MatheusGG28 - itch.io free licence: "Free for personal and commercial use. No credits required." - <https://matheusgg99.itch.io/impact-and-explosion-effects-pack>  
Credit: Pixel FX Pack - 11 Visual Effects by MatheusGG28 (credit optional)  
32x32 pixel effects at native size. The page states no redistribution limit; it also grants no explicit redistribution right. Preview: [preview.png](../../game/art/library/vfx/matheusgg28_pixel_fx/preview.png) - 63 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `explosion_small` | 7 | 23x23 | 14 | mix | small blast / hit pop |
| `explosion_medium` | 7 | 25x26 | 14 | mix | medium blast |
| `explosion_big` | 7 | 31x32 | 14 | mix | big blast (powder keg) |
| `impact_projectile` | 5 | 12x22 | 14 | mix | arrow / bolt impact |
| `impact_projectile_2` | 5 | 12x22 | 14 | mix | magic bolt impact |
| `impact_punch` | 5 | 24x24 | 14 | mix | gauntlet punch / shield bash impact |
| `dust` | 9 | 30x19 | 14 | mix | run / land dust |
| `dust_2` | 9 | 30x19 | 14 | mix | dodge-roll dust |
| `shockwave` | 7 | 32x32 | 14 | mix | slam shockwave |
| `shockwave_2` | 7 | 32x32 | 14 | mix | ring shockwave |
| `shockwave_3` | 7 | 32x32 | 14 | mix | wide shockwave |

### `pixel_misc_cc0`

several (see each effect) - CC0 1.0 - <see effects>  
Credit: tbbk, 13rice, Luis Zuno (ansimuz), Reactorcore (all optional)  
Small CC0 pixel effects gathered from OpenGameArt. Preview: [preview.png](../../game/art/library/vfx/pixel_misc_cc0/preview.png) - 256 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `tbbk_slash` | 9 | 57x37 | 18 | mix | pixel sword slash (tbbk, https://opengameart.org/content/pixel-art-sword-slash-effect) |
| `13rice_radial_spark_pixel` | 8 | 62x64 | 16 | add | radial lightning hit (13rice, https://opengameart.org/content/radial-lightning-effect) |
| `13rice_radial_spark_hd` | 8 | 96x95 | 16 | add x0.5 | radial spark, smooth (13rice); white - tint it |
| `gv_darkbolt` | 12 | 63x83 | 14 | mix | falling dark bolt (Gothicvania Magic Pack 9, ansimuz, https://opengameart.org/content/gothicvania-magic-pack-9) |
| `gv_firebomb` | 15 | 64x64 | 14 | mix | fire bomb burst (Gothicvania Magic Pack 9, ansimuz, https://opengameart.org/content/gothicvania-magic-pack-9) |
| `gv_lightning` | 11 | 56x126 | 14 | mix | lightning strike from above (Gothicvania Magic Pack 9, ansimuz, https://opengameart.org/content/gothicvania-magic-pack-9) |
| `gv_spark` | 8 | 30x30 | 14 | mix | small spark (Gothicvania Magic Pack 9, ansimuz, https://opengameart.org/content/gothicvania-magic-pack-9) |
| `gv_enemy_death` | 9 | 75x66 | 12 | mix | Gothicvania Church (ansimuz) enemy death |
| `gv_fireball` | 3 | 23x23 | 12 | mix | Gothicvania Church (ansimuz) fireball |
| `gv_explosion` | 6 | 39x49 | 12 | mix | enemy death pop (Gothicvania Swamp, ansimuz) |
| `rc_blood_splat` | 8 | 10x10 | 14 | mix | pixel blood (Reactorcore, https://opengameart.org/content/gore-blood-gibs-meat-chunks) |
| `rc_blood_burst` | 9 | 20x20 | 14 | mix | pixel blood (Reactorcore, https://opengameart.org/content/gore-blood-gibs-meat-chunks) |
| `rc_blood_blast` | 13 | 34x34 | 14 | mix | pixel blood (Reactorcore, https://opengameart.org/content/gore-blood-gibs-meat-chunks) |
| `rc_gibs` | 21 | 10x12 | 1 | mix | single gib particles (one per frame) for a GPUParticles2D burst |

### `pvfx_foundry`

nerijs - CC0 1.0 - <https://nerijs.itch.io/pvfx-foundry>  
Credit: PVFX Foundry by nerijs (credit optional)  
Pixel-art effects at native size, 20 fps. Pivots come from the pack manifests. Preview: [preview.png](../../game/art/library/vfx/pvfx_foundry/preview.png) - 853 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `crescent_slash` | 10 | 72x36 | 20 | mix | sword arc for heavy attacks |
| `electric_impact` | 14 | 76x51 | 20 | mix | Storm Spire hit spark / lightning weapon |
| `warm_explosion` | 15 | 69x70 | 20 | mix | powder keg / fire bomb blast |
| `smoke_puff` | 14 | 63x46 | 20 | mix | death puff, dodge-roll trail |
| `landing_dust` | 14 | 81x45 | 20 | mix | jump landing / boss slam dust |
| `void_implosion` | 14 | 69x52 | 20 | mix | dark magic / boss summon |
| `ember_jet` | 14 | 81x48 | 20 | mix | forge vent, fire breath |
| `arcane_parry` | 16 | 85x78 | 20 | mix | parry flash |
| `earth_rupture` | 20 | 88x59 | 20 | mix | ground slam shockwave |
| `focus_charge` | 14 | 69x57 | 20 | mix | charged attack wind-up |
| `solar_shrapnel` | 14 | 77x67 | 20 | mix | crit hit burst |
| `frost_nova` | 13 | 75x53 | 20 | mix | Frost Ossuary ice burst |
| `rift_portal` | 16 | 69x69 | 20 | mix | level exit / boss arrival portal (loops) |
| `radiant_heal` | 14 | 61x67 | 20 | mix | heal / bonfire rest |
| `magical_projectile` | 12 | 84x39 | 20 | mix | wand bolt |
| `beam_cutoff_burst` | 14 | 88x50 | 20 | mix | beam end burst |
| `resonant_break` | 34 | 73x75 | 20 | mix | guard break |
| `hush_lock` | 36 | 81x59 | 20 | mix | silence / seal ward |
| `counterfall` | 40 | 59x55 | 20 | mix | counter-attack burst (loops) |
| `mass_release` | 30 | 81x77 | 20 | mix | big release / boss phase change |
| `spectral_bloom` | 16 | 69x57 | 20 | mix | soul pickup bloom |
| `suturelight` | 36 | 31x46 | 20 | mix | holy light seam |
| `harvest_seal` | 36 | 82x62 | 20 | mix | magic circle seal on the floor |
| `acid_splash` | 14 | 69x64 | 20 | mix | poison splash |
| `dripping_runoff` | 16 | 47x83 | 20 | mix | blood/water drip (loops) |
| `choir_moths` | 60 | 71x64 | 20 | mix | ambient moths around candles (loops) |

### `rendered_cc0`

several (see each effect) - CC0 1.0 - <see effects>  
Credit: para, Sinestesia, Mikodrak, Beast, rubberduck, Limphands, Luke.RUSTLTD (all optional)  
Blender-rendered / painted effects, shrunk so they stay light; draw_scale 0.5 means draw at half size for a sharp phone image. Preview: [preview.png](../../game/art/library/vfx/rendered_cc0/preview.png) - 4432 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `para_fire_ring` | 16 | 86x96 | 24 | add x0.5 | fire ring shockwave (para, https://opengameart.org/content/animated-particle-effects-1) |
| `para_smoke_burst` | 16 | 96x96 | 24 | mix x0.5 | dust/smoke burst (para, https://opengameart.org/content/animated-particle-effects-1) |
| `para_fire_ring_ground` | 16 | 89x96 | 24 | add x0.5 | fire ring on the ground (para, https://opengameart.org/content/animated-particle-effects-1) |
| `para_spirit_ring` | 16 | 96x96 | 24 | add x0.5 | blue spirit ring (para, https://opengameart.org/content/animated-particle-effects-1) |
| `para_fire` | 16 | 96x96 | 24 | add x0.5 | looping fire (para, https://opengameart.org/content/animated-particle-effects-2) |
| `para_blood_hit_1` | 15 | 92x96 | 24 | mix x0.5 | blood hit spray (para, https://opengameart.org/content/animated-particle-effects-2) |
| `para_blood_hit_2` | 14 | 67x96 | 24 | mix x0.5 | blood hit spray (para, https://opengameart.org/content/animated-particle-effects-2) |
| `sinestesia_hit` | 16 | 128x120 | 24 | mix x0.5 | painted hit flash / blood splash (Sinestesia, https://opengameart.org/content/animations-blood-hit-and-both-d) |
| `sinestesia_blood` | 16 | 128x125 | 24 | mix x0.5 | painted hit flash / blood splash (Sinestesia, https://opengameart.org/content/animations-blood-hit-and-both-d) |
| `sinestesia_hit_blood` | 16 | 127x128 | 24 | mix x0.5 | painted hit flash / blood splash (Sinestesia, https://opengameart.org/content/animations-blood-hit-and-both-d) |
| `mikodrak_black_explosion` | 16 | 50x47 | 18 | mix x0.5 | black smoke burst (Mikodrak, https://opengameart.org/content/2d-spell-effects) |
| `mikodrak_sword_fire` | 16 | 128x57 | 18 | add x0.5 | flaming sword trail (Mikodrak, https://opengameart.org/content/2d-spell-effects) |
| `mikodrak_sign_of_fire` | 16 | 128x114 | 18 | add x0.5 | fire sigil (Mikodrak, https://opengameart.org/content/2d-spell-effects) |
| `mikodrak_fire_scissors` | 13 | 101x128 | 18 | add x0.5 | crossed fire slash (Mikodrak, https://opengameart.org/content/2d-spell-effects) |
| `mikodrak_eater_fire` | 16 | 128x113 | 18 | add x0.5 | devouring fire (Mikodrak, https://opengameart.org/content/2d-spell-effects) |
| `mikodrak_lightning_ball` | 16 | 56x65 | 18 | add x0.5 | ball lightning (Mikodrak, https://opengameart.org/content/2d-spell-effects) |
| `mikodrak_blue_pillar` | 16 | 61x128 | 18 | add x0.5 | blue light pillar (Mikodrak, https://opengameart.org/content/2d-spell-effects) |
| `beast_smoke_aura` | 24 | 96x96 | 20 | mix x0.5 | looping swirl of smoke: dark aura around a boss when tinted black (Beast, https://opengameart.org/content/smoke-aura) |
| `rubberduck_explosion` | 16 | 57x96 | 24 | mix x0.5 | explosion, volumetric render (rubberduck, https://opengameart.org/content/25-special-effects-rendered-with-blender) |
| `rubberduck_flame` | 16 | 51x96 | 24 | add x0.5 | flame, volumetric render (rubberduck, https://opengameart.org/content/25-special-effects-rendered-with-blender) |
| `rubberduck_soul_flame` | 16 | 50x96 | 24 | add x0.5 | flame, volumetric render (rubberduck, https://opengameart.org/content/25-special-effects-rendered-with-blender) |
| `rubberduck_ground_burst` | 16 | 96x47 | 24 | mix x0.5 | flat_effect, volumetric render (rubberduck, https://opengameart.org/content/25-special-effects-rendered-with-blender) |
| `rubberduck_fire_ring` | 16 | 96x78 | 24 | add x0.5 | ring, volumetric render (rubberduck, https://opengameart.org/content/25-special-effects-rendered-with-blender) |
| `rubberduck_shockwave` | 16 | 96x63 | 24 | mix x0.5 | shockwave, volumetric render (rubberduck, https://opengameart.org/content/25-special-effects-rendered-with-blender) |
| `limphands_ps1_fire` | 24 | 36x64 | 24 | mix | looping camp/brazier fire, PS1 look (Limphands, https://limphands.itch.io/ps1-fire) |

### `xyezawr_pack_1` **(local only - not in git, see licence)**

XYEzawr - itch.io licence: free and commercial projects, modify OK, credit optional; NOT to be redistributed or resold (so kept out of the public git repo) - <https://xyezawr.itch.io/free>  
Credit: Free Pixel Effects Pack by XYEzawr (credit optional)  
100x100 frames, subsampled to 20 frames max. LOCAL ONLY (git-ignored). Preview: [preview.png](../../game/art/library/vfx/xyezawr_pack_1/preview.png) - 118 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `effect_1` | 20 | 51x33 | 24 | add | see preview |
| `effect_2` | 20 | 57x39 | 24 | add | see preview |
| `effect_3` | 20 | 48x30 | 24 | add | see preview |

### `xyezawr_pack_2` **(local only - not in git, see licence)**

XYEzawr - itch.io licence: free and commercial projects, modify OK, credit optional; NOT to be redistributed or resold (so kept out of the public git repo) - <https://xyezawr.itch.io/free-pixel-effects-pack-2>  
Credit: Free Pixel Effects Pack by XYEzawr (credit optional)  
100x100 frames, subsampled to 20 frames max. LOCAL ONLY (git-ignored). Preview: [preview.png](../../game/art/library/vfx/xyezawr_pack_2/preview.png) - 24 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `effect_2` | 15 | 20x38 | 24 | add | see preview |
| `effect_4` | 15 | 55x56 | 24 | add | see preview |

### `xyezawr_pack_2_extra` **(local only - not in git, see licence)**

XYEzawr - itch.io licence: free and commercial projects, modify OK, credit optional; NOT to be redistributed or resold (so kept out of the public git repo) - <https://xyezawr.itch.io/free-pixel-effects-pack-2>  
Credit: Free Pixel Effects Pack by XYEzawr (credit optional)  
100x100 frames, subsampled to 20 frames max. LOCAL ONLY (git-ignored). Preview: [preview.png](../../game/art/library/vfx/xyezawr_pack_2_extra/preview.png) - 211 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `effect_1` | 20 | 72x67 | 24 | add | see preview |
| `effect_3_1` | 20 | 68x66 | 24 | add | see preview |
| `effect_3_2` | 20 | 67x68 | 24 | add | see preview |
| `effect_5` | 20 | 64x64 | 24 | add | see preview |
| `effect_6` | 20 | 70x63 | 24 | add | see preview |

### `xyezawr_pack_3` **(local only - not in git, see licence)**

XYEzawr - itch.io licence: free and commercial projects, modify OK, credit optional; NOT to be redistributed or resold (so kept out of the public git repo) - <https://xyezawr.itch.io/free-pixel-effects-pack-3>  
Credit: Free Pixel Effects Pack by XYEzawr (credit optional)  
100x100 frames, subsampled to 20 frames max. LOCAL ONLY (git-ignored). Preview: [preview.png](../../game/art/library/vfx/xyezawr_pack_3/preview.png) - 147 KB

| Effect | Frames | Size | fps | Blend | Use |
|---|---|---|---|---|---|
| `effect_1` | 20 | 36x39 | 24 | add | see preview |
| `effect_2` | 20 | 35x66 | 24 | add | see preview |
| `effect_3` | 20 | 52x38 | 24 | add | see preview |


## Environments, tilesets and parallax layers (`game/art/library/environments/`)

| Asset | Author / licence | What is inside | Could be used for | Preview | Size |
|---|---|---|---|---|---|
| `gothic_window_tiles` | Max Johnson (Shoehorn) - CC0 1.0 (public domain) | 2 files.  | modular stained-glass tracery (lead lines) - lay over a coloured glow for huge cathedral windows | [preview.png](../../game/art/library/environments/gothic_window_tiles/preview.png) | 193 KB |
| `gv_cemetery` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 28 files.  | graveyard under a blood moon: parallax sky/mountains/graves, grassy tiles, dead trees, statue, tombstones | [preview.png](../../game/art/library/environments/gv_cemetery/preview.png) | 332 KB |
| `gv_church` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 14 files.  | cathedral interior: purple stone tiles, balustrade, altar, gothic window, skull column - the Cathedral world | [preview.png](../../game/art/library/environments/gv_church/preview.png) | 201 KB |
| `gv_gothic_castle` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 3 files.  | castle hall with stained windows, chandeliers, gargoyles and gold stairs: a castle / throne world | [preview.png](../../game/art/library/environments/gv_gothic_castle/preview.png) | 122 KB |
| `gv_gothic_horror` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 6 files.  | brick ruins against a cloudy town skyline | [preview.png](../../game/art/library/environments/gv_gothic_horror/preview.png) | 177 KB |
| `gv_night_town_bg` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 14 files.  | 7-layer night parallax: sky, clouds, mountains (+ lit windows), forest, far buildings, town | [preview.png](../../game/art/library/environments/gv_night_town_bg/preview.png) | 96 KB |
| `gv_old_dark_castle` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 3 files.  | mossy dungeon interior with a stained-glass window, arches and stairs: crypt / Frost Ossuary variant | [preview.png](../../game/art/library/environments/gv_old_dark_castle/preview.png) | 143 KB |
| `gv_swamp` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 12 files.  | overgrown swamp with skull ground: a poison / sunken world | [preview.png](../../game/art/library/environments/gv_swamp/preview.png) | 180 KB |
| `gv_town` | Luis Zuno (ansimuz) - CC0 1.0 (public domain) | 16 files.  | ruined night town: sky, far town, tiles, houses, carts, crates, well, lamp post - a hub / between-runs village | [preview.png](../../game/art/library/environments/gv_town/preview.png) | 265 KB |
| `jetrel_castle` | Jetrel - CC0 1.0 | 4 files. The sheets had a flat background colour; it is keyed out to transparency. | green-stone castle tiles with a big gothic column, spikes; interior parallax | [preview.png](../../game/art/library/environments/jetrel_castle/preview.png) | 89 KB |

## Props (`game/art/library/props/`)

| Asset | Author / licence | What is inside | Could be used for | Preview | Size |
|---|---|---|---|---|---|
| `ettingrinder_dark_fantasy` | ETTiNGRiNDER - CC0 1.0 | 81 files.  | candelabras, a hanging gibbet cage, chains with hooks, impaled heads, skulls, gargoyle statues, sword-in-stone, armour/shield/weapon/potion/key/tome icons. Background dressing and pickup / shop icons. | [preview.png](../../game/art/library/props/ettingrinder_dark_fantasy/preview.png) | 119 KB |
| `kaykit_dungeon_props` | Kay Lousberg - CC0 1.0 | 41 files.  | banners, chests, barrels, kegs, pillars, columns, rubble, broken tables, spike floor, gated/broken walls and doorway, stairs, coins, candles and torches (add a vfx flame): dungeon / crypt dressing at the kk_* scale | [preview.png](../../game/art/library/props/kaykit_dungeon_props/preview.png) | 146 KB |
| `yd_statues` | yd (demon statue from a public-domain blend by Joseph) - CC0 1.0 | 4 files.  | crowned knight statue kneeling with his sword, a seated king on a sarcophagus, a knight lying on a tomb, a winged demon on a plinth: cathedral and crypt set-dressing, boss-arena statues | [preview.png](../../game/art/library/props/yd_statues/preview.png) | 25 KB |

## Weapons (`game/art/library/weapons/`)

| Asset | Author / licence | What is inside | Could be used for | Preview | Size |
|---|---|---|---|---|---|
| `kaykit_weapons` | Kay Lousberg - CC0 1.0 | 16 files.  | 16 weapon / gear icons (1H and 2H sword, axes, dagger, bow, crossbow, staff, wand, four shields, spellbook, quiver, smoke bomb); 48 px fit | [preview.png](../../game/art/library/weapons/kaykit_weapons/preview.png) | 40 KB |
| `quaternius_weapons` | Quaternius - CC0 1.0 | 24 files.  | 24 weapon icons (swords, claymore, golden sword, spear, axes, hammers, scythe, bows, shields, arrow): loot, shop and weapon-select icons; 48 px fit | [preview.png](../../game/art/library/weapons/quaternius_weapons/preview.png) | 46 KB |

## UI (`game/art/library/ui/`)

| Asset | Author / licence | What is inside | Could be used for | Preview | Size |
|---|---|---|---|---|---|
| `game_icons` |  - CC-BY 3.0 (game-icons.net) | 85 icons. White glyphs: tint with modulate. card48/ = gold-on-dark boon tiles. | boon, ability, status and menu icons (white glyphs to tint, or the gold card48 tiles) | [preview.png](../../game/art/library/ui/game_icons/preview.png) | 551 KB |
| `kenney_game_icons` | Kenney - CC0 1.0 | 106 images. Menu / system icons (pause, settings, audio, arrows, gamepad...), white 1x. | system icons: pause, settings, sound, arrows, gamepad, home | [preview.png](../../game/art/library/ui/kenney_game_icons/preview.png) | 1589 KB |
| `ravenmore_icons` | Ravenmore - CC-BY 3.0 | 42 images. Hand-painted 64 px item icons for a dark background (128/512 px versions exist in the download). | painted item icons (weapons, armour, potions, gems, coin) | [preview.png](../../game/art/library/ui/ravenmore_icons/preview.png) | 370 KB |
| `rpg_icons_496` | Henrique Lazarini (7Soul1), repacked by gnola14 - Public domain (CC0 on OpenGameArt; the artist's own page says public domain) | 497 images. 34 px pixel icons: weapons (W_), armour (A_), potions (P_), skills (S_), items (I_), etc. Good for boons, shop items, pickups. | pixel item / skill icons for pickups, shop and boons | [preview.png](../../game/art/library/ui/rpg_icons_496/preview.png) | 1546 KB |
| `tiny_rpg_dark_dwellers_gui` | Gabriel "tiopalada" Lima - CC0 1.0 | 94 images. Pixel-art dark GUI: *9Slices* are NinePatchRect frames (96 px, 32 px corners), *-Sheet are button / cursor state strips. | dark pixel GUI: 9-slice panels, buttons with states, health/stamina bars, cursors, equipment and portrait frames | [preview.png](../../game/art/library/ui/tiny_rpg_dark_dwellers_gui/preview.png) | 270 KB |

## Textures (seamless pixel tiles) (`game/art/library/textures/`)

| Asset | Author / licence | What is inside | Could be used for | Preview | Size |
|---|---|---|---|---|---|
| `bricks008` | ambientCG (Lennart Demes) - CC0 1.0 | . tile_64 / tile_128 tile seamlessly (4x4 / 8x8 game tiles). source/ has 512 px colour + normal maps for Blender. | clean church brick | [preview.png](../../game/art/library/textures/bricks008/preview.png) | 25 KB |
| `bricks089` | ambientCG (Lennart Demes) - CC0 1.0 | . tile_64 / tile_128 tile seamlessly (4x4 / 8x8 game tiles). source/ has 512 px colour + normal maps for Blender. | dark medieval brick wall (cathedral / castle backdrop) | [preview.png](../../game/art/library/textures/bricks089/preview.png) | 31 KB |
| `ground065` | ambientCG (Lennart Demes) - CC0 1.0 | . tile_64 / tile_128 tile seamlessly (4x4 / 8x8 game tiles). source/ has 512 px colour + normal maps for Blender. | rocky medieval ground (cemetery, swamp floor) | [preview.png](../../game/art/library/textures/ground065/preview.png) | 33 KB |
| `pavingstones150` | ambientCG (Lennart Demes) - CC0 1.0 | . tile_64 / tile_128 tile seamlessly (4x4 / 8x8 game tiles). source/ has 512 px colour + normal maps for Blender. | paving stones (floor fill, courtyard) | [preview.png](../../game/art/library/textures/pavingstones150/preview.png) | 38 KB |
| `rocks025` | ambientCG (Lennart Demes) - CC0 1.0 | . tile_64 / tile_128 tile seamlessly (4x4 / 8x8 game tiles). source/ has 512 px colour + normal maps for Blender. | rough stone wall (crypt, ruins) | [preview.png](../../game/art/library/textures/rocks025/preview.png) | 38 KB |

## Audio (`game/art/library/audio/`)

All Ogg Vorbis (sfx mono q4 trimmed and peak-normalised to -1 dBFS; ambience mono q2; music stereo q2).

| Folder | Author / licence | Files (seconds) | Use | Credit |
|---|---|---|---|---|
| `sfx/starninjas_swords` | StarNinjas - CC0 1.0 | sword_1 (0.88), sword_2 (1.08), sword_3 (0.62), sword_4 (0.54), sword_5 (0.87), sword_6 (0.5), sword_7 (0.75), sword_8 (0.96), sword_9 (1.35), sword_10 (1.14), sword_clash_1 (0.88), sword_clash_2 (0.59) ... +8 more | 10 sword attacks (swing+hit) and 10 clashes: hits, parries, shield blocks | StarNinjas (credit optional) <https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes> |
| `sfx/vehicle_weapons_apparel` | Vehicle (Jan Schupke) - CC0 1.0 | sword_knife_clash_01 (0.75), sword_knife_clash_02 (0.8), sword_knife_clash_03 (0.63), sword_knife_clash_04 (1.59), sword_knife_clash_05 (1.19), sword_knife_clash_06 (2.03), sword_knife_clash_07 (1.48), sword_knife_clash_08 (1.59), sword_knife_clash_09 (2.28), knife_unsheathe_01 (2.45), knife_unsheathe_02 (0.37), knife_unsheathe_03 (0.56) ... +22 more | metal-on-metal clashes, weapon draw / sheathe (weapon swap), leather boot steps and jumps, arrow draw (bow), buckles (equip) | Vehicle / Jan Schupke (credit optional) <https://opengameart.org/content/fantasy-weapons-and-apparel-sfx-library> |
| `sfx/artisticdude_swishes` | artisticdude - CC0 1.0 | swish_1 (0.1), swish_2 (0.08), swish_3 (0.11), swish_4 (0.1), swish_5 (0.1), swish_6 (0.1), swish_7 (0.12), swish_8 (0.12), swish_9 (0.13), swish_10 (0.08), swish_11 (0.07), swish_12 (0.06) ... +1 more | 13 whooshes (4 light, 9 heavy): swings that miss, dodge roll, spear thrust | artisticdude (credit optional) <https://opengameart.org/content/swishes-sound-pack> |
| `sfx/remaxim_melee` | remaxim - CC0 1.0 | animal_melee_sound (0.6), melee_sound (0.61), sword_sound (0.54) | sword / blunt / claw melee whooshes | remaxim (credit optional) <https://opengameart.org/content/3-melee-sounds> |
| `sfx/rubberduck_rpg` | rubberduck - CC0 1.0 | blade_01 (0.21), blade_02 (0.26), blade_03 (0.25), book_01 (0.58), book_02 (0.68), book_03 (1.02), book_04 (0.94), chain_01 (0.38), chain_02 (0.34), chain_03 (0.7), creature_die_01 (0.71), creature_hurt_01 (0.45) ... +40 more | blades, metal, chains (gates, hanging cages), fire spells, creature hurt/die/roar, coins and gems (cells pickup), locks, books, stones, wood | rubberduck (credit optional) <https://opengameart.org/content/80-cc0-rpg-sfx> |
| `sfx/rubberduck_creatures` | rubberduck - CC0 1.0 | breath (0.37), grunt_01 (0.64), grunt_02 (0.51), grunt_03 (0.48), grunt_04 (0.46), grunt_05 (0.4), howl (0.51), hurt_01 (0.36), hurt_02 (0.36), hurt_03 (0.36), hurt_04 (0.26), hurt_05 (0.3) ... +20 more | monster growls, roars, troll grunts, hurt and scream sounds, a howl (hell hound), breath (ghost) | rubberduck (credit optional) <https://opengameart.org/content/80-cc0-creature-sfx> |
| `sfx/haeldb_footsteps` | HaelDB - CC0 1.0 (dual-licensed CC0 / OGA-BY 3.0; used under CC0) | step_cloth1 (0.05), step_cloth2 (0.13), step_cloth3 (0.25), step_cloth4 (0.08), step_lth1 (0.16), step_lth2 (0.15), step_lth4 (0.25), step_lth33 (0.25), step_metal (0.15), step_metal__2 (0.19), step_metal__3 (0.18), step_metal__4 (0.14) | leather, cloth and metal-armour footsteps | HaelDB (credit optional) <https://opengameart.org/content/footsteps-leather-cloth-armor> |
| `sfx/jaggedstone_magic` | JaggedStone - CC0 1.0 | magical_1_0 (1.59), magical_2 (1.38), magical_3 (1.8), magical_4 (1.61), magical_5 (1.41), magical_6_0 (1.11), magical_7_0 (1.33) | 7 magic casts (wand, boons, shrine) | JaggedStone (credit optional) <https://opengameart.org/content/magic-spell-sfx> |
| `sfx/antumdeluge_fire` | AntumDeluge - CC0 1.0 | fire_1_0 (3.54) | short fire crackle (torch lit, fire hit) | AntumDeluge (credit optional) <https://opengameart.org/content/fire-crackling> |
| `ambience/pagdev_fireplace` | PagDev - CC0 1.0 | fire (29.26) | fireplace loop: bonfire / brazier / Molten Forge bed | PagDev (credit optional) <https://opengameart.org/content/fireplace-sound-loop> |
| `ambience/yd_dungeon` | yd - CC0 1.0 | dungeon002_0 (206.0) | dark dungeon exploration bed | yd (credit optional) <https://opengameart.org/content/dungeon-ambience> |
| `ambience/wortmann_dark_cavern` | Paul Wortmann - CC0 1.0 | dark_cavern_ambient_001 (120.0), dark_cavern_ambient_002 (120.0) | looping cavern drones: Frost Ossuary / crypt | Paul Wortmann (credit optional) <https://opengameart.org/content/dark-cavern-ambient> |
| `ambience/jaggedstone_dungeon_loop` | JaggedStone - CC0 1.0 | dungeon_ambient_1_0 (94.31) | loopable dungeon ambience | JaggedStone (credit optional) <https://opengameart.org/content/loopable-dungeon-ambience> |
| `ambience/ogrebane_dark` | Ogrebane - CC0 1.0 | ambience_1 (4.63), ambience_2 (1.81), ambience_3 (1.69), ambience_4 (1.4), ambience_5 (3.44) | 5 dark ambiences: cathedral hall, boss arena tension | Ogrebane (credit optional) <https://opengameart.org/content/dark-ambiences> |
| `ambience/kindland_forgotten_tomb` | kindland - CC0 1.0 | forgoten_tombs_1 (214.2) | forgotten-tomb ambience: crypt rooms | kindland (credit optional) <https://opengameart.org/content/forgoten-tomb-ambience> |
| `music/isao_dark_solemn_choral_organ` | ISAo - OGA-BY 3.0 | dark_solemn_choral_with_organ (70.66) | THE dark choir + organ theme: title screen, cathedral, Hollow Bishop | "Dark Solemn Choral with Organ" (Beyond Redemption, demo) by ISAo - https://airyluvs.com/ - OGA-BY 3.0 <https://opengameart.org/content/dark-solemn-choral-with-organ> |
| `music/cesisco_fantasy_choir` | cesisco - CC0 1.0 | fantasy_choir_1 (53.1), fantasy_choir_2 (126.13), fantasy_choir_3 (91.24) | 3 orchestral choir pieces: boss intros, victory, between-runs hub | cesisco (credit optional) <https://opengameart.org/content/fantasy-choir-3-orchestral-pieces> |
| `music/umplix_cathedral` | Umplix - CC0 1.0 | cathedral (72.0) | "Cathedral": slow emotional theme for the Cathedral world / game over | Umplix (credit optional) <https://opengameart.org/content/cathedral-0> |
| `music/yubatake_fugue_b_minor` | Yubatake - CC-BY 4.0 | fugue_in_b_minor (277.26) | pipe-organ fugue: cathedral exploration, organ boss | "Fugue in B Minor" by Yubatake (OpenGameArt.org), CC-BY 4.0 <https://opengameart.org/content/fugue-in-b-minor> |
| `music/yubatake_elegy_dm` | Yubatake - CC-BY 4.0 | elegy_dm (382.03) | sacred strings adagio with choir: run end / credits | "Elegy Dm" by Yubatake (OpenGameArt.org), CC-BY 4.0 <https://opengameart.org/content/elegy-dm> |
| `music/nene_boss_battle_2_metal` | nene - CC0 1.0 | boss_battle_2_opening (39.72), boss_battle_2_loop (26.48) | symphonic metal boss fight (opening + loop; the pack swaps the names, see the page) | nene (credit optional) <https://opengameart.org/content/boss-battle-2-symphonic-metal> |
| `music/matthewpablo_dark_descent` | Matthew Pablo - CC-BY 3.0 | dark_descent (83.33) | orchestral dread with choir: descending into a world | "Dark Descent" by Matthew Pablo (http://www.matthewpablo.com), CC-BY 3.0 <https://opengameart.org/content/dark-descent> |
| `music/matthewpablo_heroic_demise` | Matthew Pablo - CC-BY 3.0 | heroic_demise (301.98) | epic battle / final boss | "Heroic Demise" by Matthew Pablo (http://www.matthewpablo.com), CC-BY 3.0 <https://opengameart.org/content/heroic-demise-updated-version> |
| `music/foxsynergy_chapel_of_hate` | FoxSynergy - CC-BY 3.0 | chapel_of_hate (261.17) | dark chapel organ-rock: cathedral combat | "Chapel of Hate" by FoxSynergy, CC-BY 3.0 <https://opengameart.org/content/chapel-of-hate> |

## Licence notes

- **Public repository.** `montassarch/Cinder-and-Crown` is public on GitHub, so committing a file is redistributing it.
  Everything committed here allows that (CC0, CC-BY, OGA-BY, or a free licence that does not forbid it).
- **XYEzawr Free Pixel Effects Pack #1, #2 (both uploads) and #3** - licence on each page: "can be used in both free and
  commercial projects ... modify ... Credit is not necessary ... You may not redistribute it or resell it." Shipping them inside
  the game is fine; putting the files in a public repo is not. They are built by `build_vfx.py` into
  `game/art/library/vfx/xyezawr_*` on the machine that has the downloads, and `vfx/.gitignore` keeps them out of git.
  If the repo is made private, or the files are only kept in an untracked asset folder, they can be used freely.
- **MatheusGG28 Pixel FX Pack** - "Free for personal and commercial use. No credits required." It names no licence and does not
  forbid redistribution; committed, but if you want zero doubt, treat it like the XYEzawr packs.
- **CodeManu Free Pixel Effects Pack** - the itch.io licence field says CC-BY 4.0 while the text says public domain; we follow
  the stricter one and credit it ("Free Pixel Effects Pack by CodeManu (CC-BY 4.0)").
- **496 RPG icons** - CC0 on OpenGameArt; the artist (7Soul1) states public domain; icons derived from commercial games were
  removed by the repacker before upload.
- **Gothicvania music** (Pascal Belisle, inside the ansimuz packs) was **not** taken: its terms ("free to use as long as you
  give credit") are not a standard licence. The Gothicvania art is public domain.
- **KayKit** asks not to resell unmodified copies; using and redistributing inside a game is CC0.
- **yd's demon statue** is based on a public-domain blend by Joseph (BlendSwap); both are public domain / CC0.

## Looked at but not taken (and why)

| What | Why not |
|---|---|
| Kenney.nl, Poly Pizza, Freesound, Pixabay | the network proxy answers 403 for these sites from this container. Kenney's packs were taken from OpenGameArt mirrors instead (Particle Pack, Game Icons; Castle Kit downloaded but not converted). |
| Freesound, Sketchfab, Mixamo, CraftPix | need an account / sign-in to download (Mixamo also forbids redistributing the raw FBX files). Not signed up, as instructed. |
| SpellSoft "2D Soulslike Knight", Kiddolink VFX, Levi V.B. "Blade Swings And Hits", Gothic tilesets by metalzebra / e-wouters | paid. |
| pimen effects, Penusbmic Skeleton Warrior, CreativeKind Necromancer, aamatniekss Fantasy Knight, brullov fire, combosmooth VFX | free for games but "do not redistribute": would need the same local-only treatment as XYEzawr. Good candidates if the repo goes private. |
| LPC sprites, "Animated Knight" (Botanic), Savino's Cemetery, Bone Golem, Lightning Effect (Varkalandar), painterly spell icons | CC-BY-SA / GPL: share-alike is outside the allowed licences. |
| Calciumtrice skeleton, Ars Notoria bosses, Clint Bellanger sparks / lightning, Pixel Lightning, JROB774 explosion, Lamoot RPG GUI, Ruined Cathedral (top-down) | CC-BY and fine, but top-down, small or weaker than what the library already has. Easy to add later. |
| Foozle "Lucifer Skeleton King" (CC0) | downloaded; it is a top-down 4-direction chibi boss, not a side-view sprite. |
| MV Platformer Skeleton (CC0) | ~30 px, too small next to the 45 px hero. |
| BearGames "15 Medieval Church Backgrounds" (152 MB), pixel-1992 gothic castle background | no licence text found on the page / the author says it was made with generative AI tools. |
| Summer Engine "CC0" sheets | AI-generated, licence unclear. |
| Jetrel explosion animations | download link is dead (404). |
| Gothicvania Cold Corridors (ansimuz) | the page shows no licence text (unlike the OpenGameArt packs). |

## Free AI and procedural tools (researched for a 4-core CPU container, no GPU, ~15 GB RAM)

**Image generation that runs here**
- **SD-Turbo** (`stabilityai/sd-turbo`, Stability AI Community License: free for people and companies under USD 1M revenue
  a year, outputs usable in games; download is not gated). One step, 512x512. **Tried** - see "AI sample" below.
- **Stable Diffusion 1.5 + LCM-LoRA** (CreativeML OpenRAIL-M; use-based restrictions only) - 4 steps; FastSD CPU (MIT,
  OpenVINO) claims ~1-12 s per image on a desktop i7; a 4-core cloud CPU is slower.
- **SDXS-512 / small distilled SD models** - sub-second on a fast CPU per FastSD's README; check each model card's licence.
- **Not practical here:** FLUX.1 (12B parameters; schnell is Apache 2.0 but its weights alone are ~24 GB in bf16, more than this container's RAM), SDXL + pixel-art-xl LoRA
  (nerijs, OpenRAIL-M; workable on CPU but ~1-3 min per image), HY-Motion / Kimodo text-to-motion (need 17-26 GB GPU VRAM).
- Honest verdict: AI pictures are useful as **concept / mood references and painted far-background layers**; they do
  not give clean, consistent, animatable sprites. The Blender pipeline (rigged CC0 models -> 8x render -> pixel shrink) stays
  the way to make game sprites.

**Motion / animation**
- Already in use: Quaternius **Universal Animation Library** (QAL). New here: **KayKit Character Animations** (CC0, about 125
  clips on the Rig_Medium skeleton, more for Rig_Large: melee 1H/2H/dual-wield, block, dodge, bow, magic, skeleton rise/taunt).
- **CMU Motion Capture Database** (BVH conversions on cgspeed.com): the data is described as free for research and
  commercial use (CMU asks for a citation); it needs cleanup and retargeting onto our rigs in Blender.
- Video-to-motion: **FreeMoCap** (AGPL code, outputs are yours), **BlendArMocap** (GPL Blender add-on, MediaPipe) - CPU-capable,
  record a webcam/phone clip of a move and get keyframes. MoMask / MDM (MIT code) are text-to-motion research models
  trained on HumanML3D (AMASS-derived data with non-commercial terms) - fine for a free personal game, GPU strongly
  preferred.
- **Mixamo**: royalty-free use in games but needs an Adobe account and forbids redistributing raw files - skipped.

**Procedural textures and pixel tools**
- **Blender procedural nodes** (CPU Cycles) - used here for every render.
- **ambientCG / Poly Haven** (CC0 PBR textures and HDRIs) - five ambientCG materials are in `textures/` both as 512 px
  Blender maps and as seamless 64/128 px pixel tiles (normal-map lighting + 16 colours + ashen grade, `build_textures.py`).
- **Material Maker** (MIT, Godot-based node texture tool) and **ArmorLab** need an OpenGL GPU - run them on a desktop.
- **Pixelorama** (MIT) / **LibreSprite** (GPL) for touching up frames by hand.

## AI sample (tried here)

`game/tools/art/library/ai_sdturbo_sample.py` ran **SD-Turbo** (1 step, 512x512, CPU float32; torch 2.15 CPU wheel and
diffusers 0.42 in a scratch venv; 2.5 GB of weights): **about 17 s per image** on the 4 cores, 13 s to load. Five prompts
(ruined cathedral, crypt corridor, forge hall, storm spire, hollow knight concept) and their conversion to 384x216
game-palette backdrops (`ai_to_backdrop.py`: crop, BOX shrink, 24 colours, ashen grade) are in
[ai_samples/](ai_samples/) - see [ai_sample_sheet.png](ai_samples/ai_sample_sheet.png).
Verdict: strong mood boards and usable **far** background layers after the palette pass (cathedral, crypt and storm spire
work best); the perspective is usually frontal rather than side-on, details are mushy, and nothing in it can be animated.
Good for concept passes and painted far layers; the Blender / pixel pipeline stays the way to make anything that moves.
The weights are not in the repo (Stability AI Community License: free for anyone under USD 1M revenue a year).
