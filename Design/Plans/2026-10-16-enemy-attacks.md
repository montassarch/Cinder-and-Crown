# Enemy attack patterns (built)

Branch: `feature/enemy-attacks`. Test builds: `/enemies-1/` (attack system, Crown Guard), `/enemies-2/` (+ projectiles, Ember Wisp), `/enemies-3/` (+ slam, dive), `/enemies-4/` (+ shield, explosion: all seven).
Spec: `2026-10-16-enemy-attacks-spec.md`. Plan: `2026-10-16-enemy-attacks-plan.md`.

## The system in one paragraph
Every attack is an `EnemyMove` file in `game/data/moves/`. An enemy (`EnemyData`) lists its moves and a pattern (`SEQUENCE` plays them as one string, `RANDOM` picks one). `Enemy` plays them through one runner. Enemies with no moves get an implicit one built from their old fields, so the Shambler still works unchanged.

## The seven
| Enemy | Pattern | Answer |
|---|---|---|
| Shambler | one slow swing | parry or step back |
| Crown Guard | quick, quick (parryable), delayed heavy (not) | parry, parry, roll |
| Cinder Bat | dives along a line frozen at the halfway point, lands exposed for 1s | roll through, punish the landing |
| Ember Wisp | keeps its distance and fires an ember (backed into a wall it shoots anyway) | parry it and it flies back for x2 (x3 perfect) |
| Powder Pilgrim | rushes, 0.8s fuse, blast radius 2.5 tiles, then it is gone (no cells for a self-destruct) | kill it first or roll out |
| Penitent | shielded: blocks the side it faces (still wears poise), slow thrust | hit from behind or break the guard |
| Crown Brute | charge, then a slam sending a floor wave both ways | roll the charge, jump the wave |

## Tells
Red ring: parry it. Orange ring: dodge it. Yellow: committed. Orange floor ring: slam or blast zone. Dashed line: the path of a dash or dive.

## Adding an enemy or an attack
Add `game/data/moves/<id>.tres` (kind, times, damage, reach/speed/range, `parryable`) and `game/data/enemies/<name>.tres` listing the moves, plus `threat`, `unlock_depth`, `max_per_wave`, `cell_reward`. No code change; the waves, the spawn menu and the shop economy pick it up.

## Rulings made while building (see git history for detail)
- How close an enemy gets before it starts an attack stays `EnemyData.attack_range_tiles`; a move's `reach_tiles` is only the strike's reach.
- The Brute's charge is now dodge-only (spec); it used to be parryable.
- The dive's aim freezes when the wind-up commits (halfway), so the dashed line visibly stops tracking.
- A ranged enemy against a wall shoots instead of retreating forever.
- Shielded enemies turn to face the hero while walking or recovering.

## To tune by playing
Every number in the move and enemy files: wind-up lengths, damage, blast radius, shot speed, shield side logic, unlock depths, wave budget.

## Not done
Enemy art and animation; elite modifiers; bosses; sound.
