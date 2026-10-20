# Enemy Attack Patterns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every enemy its own data-driven attack pattern (strings, projectiles, slams, dives, shields, explosions) with clear parry-or-dodge tells, as seven distinct enemies.

**Architecture:** A new `EnemyMove` resource describes one attack. `EnemyData` holds a list of moves plus a pattern; `Enemy` runs them through one move runner that replaces today's hard-wired strike code. Enemies with no moves get an implicit move built from their legacy fields, so old data and tests keep working. Projectiles and floor waves are small separate nodes.

**Tech Stack:** Godot 4.7.2, GDScript, GdUnit4 (vendored). Web export for phone tests.

**Spec:** `Design/Plans/2026-10-16-enemy-attacks-spec.md` (approved).

## Global Constraints

- Godot 4.7.2 standard build, GDScript only, GL Compatibility renderer.
- New enemies and attacks are **data files** (`.tres`); no per-enemy code.
- Distances in tiles (`GameConfig.tiles`), times in seconds, as everywhere else.
- Only `MELEE` and `PROJECTILE` moves can be parried; slam, dash, dive and explosion are dodge-only.
- Tells: red ring for parryable, orange ring for dodge-only, yellow once committed (past half the wind-up); floor rings for `SLAM`/`EXPLODE`; dashed line for `DASH`/`DIVE`.
- Enemies stay coloured boxes in this plan (no art).
- All existing tests (404 at the start) must keep passing after every task. Run one file: `godot --headless --path game -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/<file>.gd`; the whole suite uses `-a tests`. After adding a new `class_name`, run `godot --headless --path game --import` once.
- Mutation rule: after each task's tests pass, break its main rule on purpose and confirm a named test fails, then restore.
- Each slice ends with a phone test build published to the `gh-pages` branch as `enemies-1` .. `enemies-4` (procedure in Task 4, Step 5).
- Tests never touch the real save: any test that kills an enemy in a `GeneratedLevel` sets `MetaSave.path` to a scratch file.

## Review Focus

- The enemy dies (or is stunned) between two moves of a string: no further move may start.
- The hero is parried-hit on the first move of a three-move string: the other two never play (no phantom hits).
- A projectile that leaves its range or hits a wall must be freed; a reflected projectile that kills the last enemy must open the exit gate and pay cells like any kill.
- A Powder Pilgrim killed before its fuse ends must not explode; one that explodes pays no cells and hurts only the hero, not other enemies.
- A shielded enemy knocked back past the hero must flip its front correctly: hits from behind land at full damage, hits from the front are absorbed.

## File Structure

- Create `game/src/enemies/enemy_move.gd` — `EnemyMove` resource.
- Create `game/src/enemies/enemy_projectile.gd` — `EnemyProjectile` (Area2D), reflectable.
- Create `game/src/enemies/floor_wave.gd` — `FloorWave` (Area2D), the slam shockwave.
- Modify `game/src/enemies/enemy_data.gd` — moves, pattern, gaps, shield, `effective_moves()`.
- Modify `game/src/enemies/enemy.gd` — the move runner, tells, shield, exposed window.
- Create `game/data/moves/*.tres` and new `game/data/enemies/*.tres`; modify the three shipped enemies.
- Tests: `tests/test_enemy_move.gd`, `tests/test_enemy_runner.gd`, `tests/test_enemy_tells.gd`, `tests/test_enemy_projectile.gd`, `tests/test_floor_wave.gd`, `tests/test_enemy_roster.gd`, plus additions to existing suites named per task.

---

## Slice 1: the attack system and the Crown Guard

### Task 1: `EnemyMove` and `EnemyData.effective_moves()`

**Files:**
- Create: `game/src/enemies/enemy_move.gd`
- Modify: `game/src/enemies/enemy_data.gd`
- Test: `game/tests/test_enemy_move.gd`

**Interfaces:**
- Produces: `class_name EnemyMove extends Resource` with `enum Kind { MELEE, PROJECTILE, SLAM, DASH, DIVE, EXPLODE }` and exports `id: String`, `kind: Kind`, `telegraph_seconds: float`, `active_seconds: float`, `recovery_seconds: float`, `damage: int`, `reach_tiles: float` (melee reach, explosion radius), `speed_tiles: float` (projectile, wave, dash, dive speed), `range_tiles: float` (projectile flight, wave travel), `parryable: bool`, `exposed_seconds: float` (extra damage taken after the move). `func is_valid() -> bool`.
- Produces: on `EnemyData`: `enum Pattern { SEQUENCE, RANDOM }`, `@export var moves: Array[EnemyMove]`, `pattern: Pattern`, `chain_gap_seconds: float = 0.1`, `cooldown_seconds: float = 0.0`, `preferred_range_tiles: float = 0.0`, `shielded: bool = false`, and `func effective_moves() -> Array[EnemyMove]`. `Behaviour` gains `KEEP_DISTANCE` (appended last).

- [ ] **Step 1: Write failing tests** in `test_enemy_move.gd`: `test_a_melee_move_needs_a_reach_and_times`, `test_projectile_and_wave_moves_need_speed_and_range`, `test_dash_and_dive_need_speed_and_duration`, `test_explosions_need_a_radius`, `test_effective_moves_returns_the_listed_moves`, `test_an_enemy_without_moves_gets_a_melee_move_from_its_old_fields` (assert kind `MELEE`, `telegraph_seconds`, `recovery_seconds`, `damage == attack_damage`, `reach_tiles == attack_range_tiles`, `parryable == true`), `test_a_charger_without_moves_gets_a_dash_move` (kind `DASH`, `parryable == false`, `speed_tiles == move_speed_tiles * Enemy.CHARGE_SPEED_MULTIPLIER`, `active_seconds == Enemy.CHARGE_DURATION`).
- [ ] **Step 2: Run** the file; expect parse errors (types missing).
- [ ] **Step 3: Implement** `EnemyMove` (defaults: telegraph 0.5, active 0.15, recovery 0.6, damage 5, reach 1.5, parryable true) and the `EnemyData` additions; `effective_moves()` returns `moves` when non-empty, otherwise a one-element array built from the legacy fields as the test describes. Run `--import`.
- [ ] **Step 4: Run** the file and the full suite; all pass. Mutation: make `effective_moves()` ignore `moves`; `test_effective_moves_returns_the_listed_moves` must fail.
- [ ] **Step 5: Commit** `feat: EnemyMove resource and implicit moves for old enemies`.

### Task 2: One move runner replaces the hard-wired strike code (behaviour-preserving)

**Files:**
- Modify: `game/src/enemies/enemy.gd` (`begin_telegraph`, `_on_telegraph_timeout`, `_think_strike`, `_deal_damage`, new `_current_move`)
- Test: `game/tests/test_enemy_runner.gd` (new), existing `test_enemy_data.gd`, `test_enemy_poise.gd`, `test_player_parry.gd` act as the regression guard

**Interfaces:**
- Consumes: `EnemyData.effective_moves()`.
- Produces: `Enemy.current_move() -> EnemyMove` (null outside an attack), `Enemy.move_index() -> int`. A MELEE move strikes at the end of its telegraph (as today); a DASH move rushes for `active_seconds` at `speed_tiles` and hits on contact within `CHARGE_CONTACT_TILES` (as today). Hits route through `Enemy._hit_hero(foe: Node, move: EnemyMove) -> void`: parryable moves call `foe.take_strike(damage, global_position.x, self)` when the foe has it, otherwise `take_hit`; non-parryable moves always call `take_hit`.

- [ ] **Step 1: Write failing tests** in `test_enemy_runner.gd`: `test_the_current_move_is_set_while_winding_up_and_cleared_after_recovery`, `test_a_non_parryable_move_hits_through_take_hit_not_take_strike` (use `tests/support/strike_recorder.gd`, extend it with a `take_hit` that records into `hits`), `test_a_parryable_move_hits_through_take_strike`.
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Refactor** the enemy so `begin_telegraph()` picks `effective_moves()[0]`, the telegraph timer uses that move's `telegraph_seconds`, MELEE/DASH resolve as described, and the recovery timer uses `recovery_seconds`. Delete the old special cases made redundant by the move kinds. No behaviour change for existing enemies.
- [ ] **Step 4: Run** the new file, then the full suite: every pre-existing enemy, poise, parry, encounter and generated-level test must still pass. Mutation: route non-parryable moves through `take_strike`; the new routing test fails.
- [ ] **Step 5: Commit** `refactor: enemies attack through EnemyMove`.

### Task 3: Strings, patterns, cooldown and interruption

**Files:**
- Modify: `game/src/enemies/enemy.gd` (runner: `_advance_string`, `_pick_first_move`)
- Test: `game/tests/test_enemy_runner.gd`

**Interfaces:**
- Consumes: Task 2's runner; `EnemyData.pattern`, `chain_gap_seconds`, `cooldown_seconds`.
- Produces: with `SEQUENCE`, a finished move's recovery is followed (after `chain_gap_seconds`) by the next move's telegraph until the list ends, then `cooldown_seconds` before the enemy may attack again; with `RANDOM`, each attack picks one move at random from an injectable `rng` (`Enemy.rng: RandomNumberGenerator`). A parry, stun, flinch, guard break or death ends the string; `move_index()` returns 0 afterwards.

- [ ] **Step 1: Write failing tests**: `test_a_string_plays_its_moves_in_order` (3 melee moves, assert `attack_released` damages `[6, 6, 14]` in order), `test_the_string_waits_out_its_cooldown_before_starting_again`, `test_a_parry_on_the_first_move_cancels_the_rest` (Review Focus: no phantom hits; victim records exactly one strike), `test_a_stun_between_moves_ends_the_string`, `test_a_death_between_moves_starts_no_further_move` (Review Focus), `test_a_random_pattern_only_picks_listed_moves` (seeded rng, 30 attacks), `test_a_guard_break_ends_the_string`.
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Implement** the string logic in the runner; keep `COMMIT_FRACTION` and poise rules applying per move.
- [ ] **Step 4: Run** the file and the full suite. Mutation: let `on_parried` leave the string running; `test_a_parry_on_the_first_move_cancels_the_rest` fails.
- [ ] **Step 5: Commit** `feat: enemy attack strings and patterns`.

### Task 4: Tells, the Crown Guard, and the slice-1 phone build

**Files:**
- Modify: `game/src/enemies/enemy.gd` (`_draw`, new `tell_color()`)
- Create: `game/data/moves/guard_quick.tres`, `guard_quick_2.tres`, `guard_heavy.tres`, `game/data/enemies/crown_guard.tres`
- Test: `game/tests/test_enemy_tells.gd` (new), `game/tests/test_enemy_roster.gd` (new)

**Interfaces:**
- Produces: `Enemy.tell_color() -> Color` (red `TELL_COLOR` for a parryable move winding up, new `TELL_DODGE_COLOR := Color(1.0, 0.55, 0.1)` for dodge-only, `TELL_COMMITTED_COLOR` once committed, `Color.TRANSPARENT` when not winding up).
- Data: Crown Guard — `moves = [guard_quick, guard_quick_2, guard_heavy]`, `pattern = SEQUENCE`, `chain_gap_seconds 0.1`, `cooldown_seconds 1.2`, `max_health 45`, `move_speed_tiles 2.2`, `poise 2`, `threat 4`, `unlock_depth 1`, `max_per_wave 2`, `cell_reward 2`, `body_size_tiles (1.0, 2.0)`, tint steel blue. Moves: quick (`telegraph 0.35`, `active 0.1`, `recovery 0.15`, `damage 6`, `reach 1.6`, parryable), quick 2 (`telegraph 0.3`, same otherwise), heavy (`telegraph 0.6`, `recovery 0.8`, `damage 14`, `reach 1.8`, **not** parryable).

- [ ] **Step 1: Write failing tests**: `test_a_parryable_wind_up_shows_the_red_tell`, `test_a_dodge_only_wind_up_shows_the_orange_tell`, `test_a_committed_wind_up_shows_yellow`, `test_no_tell_when_not_winding_up`; in the roster file `test_every_move_file_is_valid_and_matches_its_file_name`, `test_the_crown_guard_has_a_three_move_string_ending_in_an_unparryable_heavy`, `test_the_crown_guard_is_unlocked_by_depth_one`.
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Implement** `tell_color()` and make `_draw` use it for the ring; create the move and enemy files with the values above.
- [ ] **Step 4: Run** the full suite; mutation: swap the two tell colours; the red/orange tests fail. Render one screenshot of a Crown Guard string under Xvfb (`--fixed-fps 60`, frame-based waits) and check the rings read as red, red, orange.
- [ ] **Step 5: Publish `enemies-1`:** export the web build (`godot --headless --path game --export-release "Web" ../build/web/index.html`), copy `build/web/*` into a fresh `enemies-1/` folder of the `gh-pages` clone, commit, push, wait until `https://montassarch.github.io/Cinder-and-Crown/enemies-1/index.pck` returns 200, and run the iPhone-viewport Playwright check (no console errors, menu spawns a Crown Guard). Commit the branch and push `feature/enemy-attacks`.

## Slice 2: projectiles and reflect

### Task 5: `EnemyProjectile` with parry-reflect

**Files:**
- Create: `game/src/enemies/enemy_projectile.gd`
- Test: `game/tests/test_enemy_projectile.gd`

**Interfaces:**
- Produces: `class_name EnemyProjectile extends Area2D`; `func launch(direction: float, speed_px: float, max_distance_px: float, damage: int, shooter: Node) -> void`; `func on_parried(perfect: bool, from_x: float) -> void` (reverses direction, switches to enemy-hitting, damage ×2, ×3 if perfect); it detects the hero hurtbox (layer 8) while hostile and enemy hurtboxes (layer 16) once reflected, and the world (layer 1). A hostile hit calls the hero's `take_strike(damage, x, self)`; a reflected hit calls the enemy's `take_hit(damage, x)`. It frees itself on any hit, on a wall, or past `max_distance_px`.

- [ ] **Step 1: Write failing tests**: `test_it_flies_at_its_speed_in_its_direction`, `test_it_frees_itself_past_its_range`, `test_it_frees_itself_on_a_wall` (Review Focus), `test_it_hurts_the_hero_through_take_strike`, `test_a_parry_sends_it_back_and_it_then_hits_enemies_not_the_hero`, `test_a_reflected_projectile_deals_double_damage_and_triple_if_perfect`, `test_a_reflected_shot_that_kills_the_last_enemy_pays_cells_and_opens_the_gate` (in `GeneratedLevel` with a scratch `MetaSave`; Review Focus).
- [ ] **Step 2: Run**; expect failures. **Step 3: Implement** the node (small rectangle shape, drawn as an orange/white dot). **Step 4: Run** the file and full suite; mutation: skip the damage multiplier on reflect, the damage test fails. **Step 5: Commit** `feat: reflectable enemy projectiles`.

### Task 6: `PROJECTILE` moves, keep-distance movement, the Ember Wisp, slice-2 build

**Files:**
- Modify: `game/src/enemies/enemy.gd` (runner: PROJECTILE; movement: `KEEP_DISTANCE`)
- Create: `game/data/moves/wisp_bolt.tres`, `game/data/enemies/ember_wisp.tres`
- Test: `game/tests/test_enemy_runner.gd`, `game/tests/test_enemy_roster.gd`

**Interfaces:**
- Consumes: `EnemyProjectile.launch(...)`.
- Produces: a PROJECTILE move spawns one projectile at the end of its telegraph, aimed horizontally at the hero, `speed_tiles` and `range_tiles` from the move. `KEEP_DISTANCE` backs away when the hero is closer than `preferred_range_tiles - 1`, approaches when farther than `preferred_range_tiles + 1`, otherwise holds and attacks when within `range_tiles`.
- Data: `wisp_bolt` (`telegraph 0.6`, `recovery 0.5`, `damage 8`, `speed 6`, `range 14`, parryable); Ember Wisp (`behaviour KEEP_DISTANCE`, `preferred_range_tiles 7`, `max_health 16`, `move_speed_tiles 3`, `cooldown_seconds 1.8`, `threat 3`, `unlock_depth 2`, `max_per_wave 2`, `cell_reward 2`).

- [ ] **Step 1: Write failing tests**: `test_a_projectile_move_spawns_a_shot_that_flies_toward_the_hero`, `test_a_keep_distance_enemy_backs_off_when_the_hero_is_too_close`, `test_a_keep_distance_enemy_closes_in_when_the_hero_is_far`, `test_the_wisp_data_is_valid_and_unlocked_at_depth_two`, `test_parrying_a_wisp_bolt_damages_the_wisp_when_it_comes_back` (real player, real wisp).
- [ ] **Step 2–4:** run (fail), implement, run file and full suite; mutation: spawn the shot without `range_tiles`; the range test fails. **Step 5: Publish `enemies-2`** (same procedure as Task 4, Step 5) and commit.

## Slice 3: slam and dive

### Task 7: `FloorWave` and the `SLAM` move

**Files:**
- Create: `game/src/enemies/floor_wave.gd`
- Modify: `game/src/enemies/enemy.gd` (runner: SLAM; floor tell)
- Test: `game/tests/test_floor_wave.gd`, `game/tests/test_enemy_runner.gd`

**Interfaces:**
- Produces: `class_name FloorWave extends Area2D`; `func launch(direction: float, speed_px: float, range_px: float, damage: int) -> void`. A thin strip (height 6 px) travelling along the floor; it hurts the hero through `take_hit` only if the hero's hurtbox overlaps the strip (a hero in the air misses), once per wave; frees itself past `range_px`. A SLAM move launches two waves (left and right) at the end of its telegraph and draws an orange floor ring during it.

- [ ] **Step 1: Write failing tests**: `test_a_wave_hurts_a_hero_standing_on_the_floor`, `test_a_wave_misses_a_hero_who_is_jumping`, `test_a_wave_hurts_only_once`, `test_a_wave_is_freed_after_its_range`, `test_a_slam_move_launches_one_wave_each_way`, `test_a_slam_cannot_be_parried` (parry state active, still takes damage).
- [ ] **Step 2–4:** run (fail), implement, run file and full suite; mutation: let the wave hit a hero in the air; the jump test fails. **Step 5: Commit** `feat: slam shockwave`.

### Task 8: `DIVE` with an exposed landing; Brute and Bat migrate; slice-3 build

**Files:**
- Modify: `game/src/enemies/enemy.gd` (runner: DIVE; `exposed_seconds`; dashed-line tell)
- Create: `game/data/moves/brute_charge.tres`, `brute_slam.tres`, `bat_dive.tres`
- Modify: `game/data/enemies/crown_brute.tres`, `cinder_bat.tres`
- Test: `game/tests/test_enemy_runner.gd`, `game/tests/test_enemy_roster.gd`

**Interfaces:**
- Produces: a DIVE move latches the hero's position at the end of its telegraph and flies there at `speed_tiles` for up to `active_seconds`, hurting through `take_hit` on contact; afterwards the enemy is **exposed** for the move's `exposed_seconds` (takes `BREAK_DAMAGE_MULTIPLIER` damage, orange tint) before recovery ends. The tell draws a dashed line to the latched target.
- Data: `brute_charge` (DASH, `telegraph 0.9`, `active 0.35`, `speed = move_speed_tiles * 4`, `damage 20`, not parryable, `recovery 0.3`), `brute_slam` (SLAM, `telegraph 0.7`, `damage 16`, `speed 9`, `range 10`, not parryable, `recovery 1.0`); Brute `moves = [brute_charge, brute_slam]`, `SEQUENCE`, `cooldown_seconds 1.5`, `unlock_depth 4`. `bat_dive` (DIVE, `telegraph 0.5`, `active 0.6`, `speed 14`, `damage 7`, not parryable, `exposed_seconds 1.0`); Bat `moves = [bat_dive]`, `unlock_depth 1`.

- [ ] **Step 1: Write failing tests**: `test_a_dive_flies_to_where_the_hero_was_not_where_he_is_now` (hero moves after the telegraph ends; enemy lands at the latched point), `test_a_dive_hurts_on_contact_through_take_hit`, `test_the_diver_takes_extra_damage_after_landing_and_then_recovers`, `test_the_brute_charges_then_slams` (two moves in order), `test_the_migrated_enemies_keep_their_threat_and_cell_reward`, `test_the_brute_unlocks_at_depth_four_and_the_bat_at_one`.
- [ ] **Step 2–4:** run (fail), implement, run file and full suite (poise, parry and encounter suites must still pass with the migrated data); mutation: skip the exposed window; the extra-damage test fails. **Step 5: Publish `enemies-3`** and commit.

## Slice 4: shield and explosion

### Task 9: Shield and the Penitent

**Files:**
- Modify: `game/src/enemies/enemy.gd` (`take_hit` front check)
- Create: `game/data/moves/penitent_thrust.tres`, `game/data/enemies/penitent.tres`
- Test: `game/tests/test_enemy_poise.gd` (additions), `game/tests/test_enemy_roster.gd`

**Interfaces:**
- Produces: when `data.shielded` and the hit's `source_x` is on the side the enemy faces, `take_hit` deals no health damage, costs one poise (so a guard break still works), flashes, and returns; hits from behind are normal. Facing is the enemy's `_facing` (toward the hero while it is not being knocked).
- Data: `penitent_thrust` (MELEE, `telegraph 0.8`, `active 0.15`, `recovery 0.7`, `damage 12`, `reach 1.8`, parryable); Penitent (`shielded true`, `max_health 40`, `move_speed_tiles 1.6`, `poise 3`, `threat 5`, `unlock_depth 3`, `max_per_wave 1`, `cell_reward 3`).

- [ ] **Step 1: Write failing tests**: `test_a_hit_from_the_front_is_absorbed`, `test_a_hit_from_behind_deals_full_damage`, `test_a_front_hit_still_wears_poise_down_until_the_guard_breaks`, `test_a_broken_shield_takes_full_damage_from_the_front` (Review Focus), `test_a_flipped_facing_after_knockback_flips_the_shield_side` (Review Focus), `test_the_penitent_data_is_valid`.
- [ ] **Step 2–4:** run (fail), implement, run file and full suite; mutation: ignore the side check; the behind-hit test fails. **Step 5: Commit** `feat: shielded enemies and the Penitent`.

### Task 10: `EXPLODE` and the Powder Pilgrim; slice-4 build

**Files:**
- Modify: `game/src/enemies/enemy.gd` (runner: EXPLODE; floor ring; `exploded` signal)
- Create: `game/data/moves/pilgrim_blast.tres`, `game/data/enemies/powder_pilgrim.tres`
- Test: `game/tests/test_enemy_runner.gd`, `game/tests/test_enemy_roster.gd`, `game/tests/test_encounters.gd`

**Interfaces:**
- Produces: `signal exploded`. An EXPLODE move's telegraph is the fuse; at its end the hero takes `damage` through `take_hit` if within `reach_tiles` of the enemy, other enemies are unaffected, and the enemy dies **without** emitting `died` (so no cells are paid) while counting as dead for the exit gate. Killing the enemy before the fuse ends cancels the explosion.
- Data: `pilgrim_blast` (EXPLODE, `telegraph 0.8`, `damage 18`, `reach 2.5`, not parryable); Pilgrim (`max_health 12`, `move_speed_tiles 3.5`, `threat 3`, `unlock_depth 3`, `max_per_wave 1`, `cell_reward 2`).

- [ ] **Step 1: Write failing tests**: `test_the_blast_hurts_the_hero_inside_its_radius_only`, `test_the_blast_does_not_hurt_other_enemies` (Review Focus), `test_killing_the_pilgrim_before_the_fuse_ends_cancels_the_blast` (Review Focus), `test_an_exploding_pilgrim_pays_no_cells_but_opens_the_gate` (scratch `MetaSave`), `test_a_pilgrim_killed_by_the_hero_pays_its_cells`, `test_the_pilgrim_data_is_valid`.
- [ ] **Step 2–4:** run (fail), implement, run file and full suite; mutation: let the blast hurt enemies; the friendly-fire test fails. **Step 5: Publish `enemies-4`** (all seven enemies), commit and push.

### Task 11: Waves, docs, whole-branch check

**Files:**
- Modify: `Design/Plans/2026-10-16-enemy-attacks-spec.md` (mark status), `Design/Plans/2026-10-16-runs.md` (roster lines), `Tasks/Roadmap.md`, `README.md` (enemy list)
- Test: `game/tests/test_wave_generator.gd`, `game/tests/test_enemy_roster.gd`

- [ ] **Step 1: Write failing tests**: `test_every_shipped_enemy_unlocks_in_the_spec_order` (Shambler 0, Crown Guard 1, Bat 1, Wisp 2, Pilgrim 3, Penitent 3, Brute 4), `test_no_wave_at_any_depth_exceeds_its_budget_with_the_full_roster` (depths 0–8, 40 seeds), `test_every_shipped_enemy_has_at_least_one_move_or_a_valid_legacy_attack`.
- [ ] **Step 2: Run**; fix data if any fail. **Step 3:** update the docs and README. **Step 4:** run the full suite and an iPhone-viewport Playwright run through a generated level at depth 4 (no console errors). **Step 5:** commit, push, then request a whole-branch review.

---

## Self-review (done)

- **Spec coverage:** data model → Task 1; runner → Tasks 2–3; parry/dodge routing → Task 2; tells → Task 4 (rings), Task 7 (floor ring), Task 8 (dashed line), Task 10 (blast ring); roster → Tasks 4, 6, 8, 9, 10 with the spec's numbers; compatibility → Tasks 1–2; waves/economy → Task 11; testing and mutation rule → Global Constraints; builds per slice → Tasks 4, 6, 8, 10.
- **Types:** `EnemyMove` fields, `effective_moves()`, `current_move()`, `tell_color()`, `_hit_hero()`, `launch(...)` signatures are used identically across tasks.
- **Proportion:** tasks give signatures, values and test names only; bodies are left to the implementer.
