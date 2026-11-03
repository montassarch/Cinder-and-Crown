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
