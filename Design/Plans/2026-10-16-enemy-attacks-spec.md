# Enemy attack patterns: design spec

Branch: `feature/enemy-attacks` (from `feature/runs`). Status: **awaiting your review**. No code written yet.
Chosen focus (you): attack patterns first, with the current coloured-box enemies. Real enemy art comes after.

## What we are building and why
Every enemy today attacks the same way: wind up, one strike, recover. Only speed, size and health differ, so there is nothing new to learn as a run goes deeper. We want each enemy to have its **own readable attack pattern** that you learn, then answer by parrying, rolling or jumping. Fights should feel like Dead Cells, with the Dark Souls habit of reading a tell and making a choice.

Success looks like:
- Seven enemies, each with a clearly different pattern.
- On a phone-sized screen you can tell from the tell alone whether to **parry** or **dodge**.
- Adding an enemy or an attack later means adding data files, not editing core code (the same rule as weapons, boons and rooms).
- Everything is covered by tests, with the break-it-on-purpose check I have used so far.

What you said versus what I assumed:
- You said: attack patterns first, enemy design afterwards; the vibe is Dark Souls at Dead Cells resolution; the game is played by touch.
- I assumed: about seven enemies; only melee and projectile attacks can be parried; the rest must be dodged; art stays as coloured boxes in this pass.

## The data model
**`EnemyMove`** (new resource, one file per attack, `data/moves/`):

| Field | Meaning |
|---|---|
| `kind` | `MELEE`, `PROJECTILE`, `SLAM`, `DASH`, `DIVE`, `EXPLODE` |
| `telegraph_seconds` | wind-up; the existing closing ring plays over this time |
| `active_seconds` | how long the strike is live |
| `recovery_seconds` | how long the enemy is open afterwards |
| `damage` | damage to the hero |
| `reach_tiles` | melee reach, or blast radius for `EXPLODE` |
| `parryable` | true: red tell, goes through `take_strike`. false: orange tell, plain `take_hit` |
| kind-specific | projectile speed and lifetime; slam wave speed and range; dash/dive speed and duration |

**`EnemyData`** gains:
- `moves: Array[EnemyMove]` and `pattern` (`SEQUENCE` plays them in order as one string, `RANDOM` picks one each time).
- `chain_gap_seconds`: pause between moves in a string.
- `cooldown_seconds`: rest after the whole string before the next one starts.
- `movement` (what `behaviour` does today, plus `KEEP_DISTANCE` for ranged enemies).
- `shielded`: blocks hits from the front.

**Compatibility rule:** an enemy with an empty `moves` list keeps today's behaviour (its `attack_damage`, `telegraph_seconds`, `recovery_seconds` and `attack_range_tiles` act as one implicit melee move). Existing enemies and all 404 existing tests keep working while enemies are migrated one slice at a time.

## The runner (inside `Enemy`)
The existing states stay: `MOVE`, `TELEGRAPH`, `STRIKE`, `RECOVER`, `STUNNED`, `DEAD`. A new `_current_move` and `_move_index` say which attack is playing. After a move's recovery:
- if the string has more moves, go to the next one's `TELEGRAPH` after `chain_gap_seconds`;
- otherwise rest for `cooldown_seconds`, then `MOVE`.

A parry, a stun, a guard break or a flinch ends the whole string. Poise and the commit rule (half the wind-up) apply to each move unchanged.

## Parry versus dodge
- `parryable` moves call `Player.take_strike`, exactly as now. A parry staggers the enemy and banks the riposte.
- Non-parryable moves call `Player.take_hit`, so a parry press does nothing against them. A roll's i-frames or a jump avoids them.
- A parried **projectile** is reflected: it flies back, is owned by the hero, and damages enemies.

## Tells (what you see)
| Move | Tell |
|---|---|
| Parryable melee or projectile | Red ring and "!" closing over the enemy's head (today's tell) |
| Non-parryable | Orange ring and "!" |
| `SLAM` and `EXPLODE` | Orange ring on the floor showing the area or the wave's start |
| `DASH` and `DIVE` | A dashed line on the ground or in the air showing the committed path |

Committed moves (past half the wind-up) turn the ring yellow, as today.

## Roster
Numbers are starting points to tune by playing.

| Enemy | Movement | Moves | Parry? | Answer | Unlocks at depth |
|---|---|---|---|---|---|
| Shambler (exists) | chaser | 1 slow overhead swing | yes | parry or step back | 0 |
| Crown Guard (new) | chaser | string of 3: quick, quick, delayed heavy | first two yes, third no | parry, parry, roll | 1 |
| Cinder Bat (exists) | flyer | hover, then dive along a shown line, then lands and is exposed 1s | no | roll through, punish the landing | 1 |
| Ember Wisp (new) | keeps its distance | slow ember bolt | yes (reflects) | parry it back | 2 |
| Powder Pilgrim (new) | chaser | rush, fuse of 0.8s, explosion ring, dies | no | kill it first or roll out | 3 |
| Penitent (new) | slow chaser, shielded | slow thrust | yes | hit from behind or break the guard | 3 |
| Crown Brute (exists) | charger | charge, then overhead slam sending a shockwave both ways | charge no, slam wave no | roll the charge, jump the wave | 4 |

Each also gets `threat`, `max_per_wave`, `cell_reward` and `poise` in its data file, so `WaveGenerator` and the shop economy pick them up with no code change.

## Build order (each slice ends with a test link for your phone)
1. **The attack system and the Crown Guard.** `EnemyMove`, the runner, the string, the tells (red and orange rings), the compatibility fallback, and the Crown Guard's 3-hit combo.
2. **Projectiles and reflect.** `EnemyProjectile`, `KEEP_DISTANCE` movement, the Ember Wisp, parry-reflect.
3. **Slam and dive.** The floor shockwave (jumpable), the committed dive line with a landing window, the Crown Brute's and Cinder Bat's new patterns.
4. **Shield and explosion.** Frontal shield, the self-destructing Powder Pilgrim, the Penitent.

## Testing
- Move timing, string order, cooldown and interruption are tested with real enemies and physics frames.
- Parry rules: parryable moves are deflected, non-parryable ones are not, and a reflected projectile damages enemies.
- Each kind's hit rules: the slam wave misses a jumping hero, the explosion hits inside its radius only, a shield blocks only from the front.
- Data tests: every move and enemy file is valid, ids match file names, parryable melee has a reach, and so on.
- Mutation checks as before: each new rule is broken on purpose and the right test must fail.
- A real-browser run on an iPhone-sized viewport for each slice.

## Out of scope
- Enemy art and animation (the next pass).
- Bosses.
- Elite modifiers.
- Sound.

## Open to tuning after you play
Window lengths, the roster's numbers, how many enemies a wave holds, whether the Crown Guard's third hit should be parryable on a perfect parry only.
