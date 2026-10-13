# Cinder & Crown — Phase 1 Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable sandbox prototype of a Dead Cells-style 2D action roguelite: a player who runs, jumps, rolls and attacks; two data-driven weapons; three data-driven enemies; a test room with a spawn/swap menu; and randomly assembled rooms with an exit.

**Architecture:** Godot 4.7.2, GDScript, `CharacterBody2D` player driven by a pure-function state machine so transitions are testable headlessly. Everything the designer will add later — weapons, enemies, classes, rooms — is a `Resource` (`.tres`) file loaded at runtime, never a hard-coded branch. All spatial values live in tiles and resolve through one `GameConfig` autoload, which is what keeps the 384×216 → high-res upgrade a config change.

**Tech Stack:** Godot 4.7.2 (standard build, no .NET), GDScript, GdUnit4 for logic tests.

**Spec:** [[Design/Overview]] · **Roadmap:** [[Tasks/Roadmap]]

---

## Global Constraints

- **Engine:** Godot 4.7.2 standard build. Project `config/features` must declare `4.7`. No C#/.NET.
- **Base resolution:** 384×216, set once in `project.godot` (`display/window/size/viewport_width|height`). Stretch mode `canvas_items`, aspect `keep`.
- **Resolution upgrade path (hard rule):** no raw pixel literal may appear in gameplay code. Every distance, size, offset and speed is expressed in **tiles** or **tiles/second** and converted through `GameConfig.tiles()`. Raising `GameConfig.TILE_SIZE` and the viewport size must be the only edits needed to move toward Dead Cells-scale art.
- **Tile size:** `GameConfig.TILE_SIZE = 16`.
- **Physics tick:** 60 Hz (`physics/common/physics_ticks_per_second = 60`). Gameplay reads `delta`, never assumes a tick rate.
- **Data-driven rule:** adding a weapon, enemy or room means adding a `.tres`/`.tscn` file under `game/data/`. A task that requires editing a `match` statement to add content has failed its own requirement.
- **Input:** keyboard, gamepad and touch are equal first-class paths from Task 3 onward. No gameplay script may call `Input.*` directly; all input goes through `InputRouter`.
- **Combat model (Dead Cells):** two weapons swapped freely, no stamina, roll grants invincibility frames, hit-stop on impact, enemies telegraph before striking.
- **Tests:** GdUnit4, logic only. Game feel is verified by the human playing it. No test asserts "this feels good."
- **Test command:** `godot --headless --path game -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests` (exact invocation confirmed in Task 1).
- **Godot binary:** `C:\Users\LAPTOP\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` (winget could not create the `godot` PATH alias without admin).
- **Placeholder art:** flat `ColorRect`/`Polygon2D` shapes sized in tiles. No sprite assets in Phase 1.
- **Hosting is out of scope for the agent.** Task 9 builds exports locally and stops. Publishing to GitHub Pages or Netlify leaves the machine and requires the human's explicit go-ahead.

## Review Focus

Input classes the spec implies but no task's tests fully exercise. Each has a test assigned to the task that owns the code.

1. **Weapon swapped mid-attack, inside the active hit window** — the old weapon's hitbox must be withdrawn and must not deal damage after the swap; the new weapon must not inherit the old one's elapsed hit window. (Task 5)
2. **Opposing and multi-device input at once** — left+right held together, or keyboard and touch disagreeing on the same frame. The axis must resolve deterministically to a documented winner, never jitter between frames. (Task 3)
3. **Degenerate room pool** — a pool of one room, or zero rooms, passed to the generator. Must return a valid level or an empty array, never loop forever trying to satisfy "no two identical rooms in a row". (Task 8)
4. **Enemy killed during its telegraph wind-up** — the queued strike must be cancelled. A dead enemy may not deal damage. (Task 6)
5. **Damage that should not heal** — zero, negative, and defense-exceeds-damage cases must clamp to 0 and never raise the target's health. Overkill must report the damage actually absorbed, not the amount sent. (Task 2)

---

## File Structure

```
game/
  project.godot
  addons/gdUnit4/              # test framework (vendored)
  src/
    core/
      game_config.gd           # autoload: TILE_SIZE, base resolution, tiles()
      damage.gd                # pure damage arithmetic
      health.gd                # Health component node
      hit_stop.gd              # autoload: brief global time freeze on impact
    input/
      input_router.gd          # autoload: keyboard + gamepad + touch -> intents
      touch_controls.tscn      # on-screen stick + attack/jump/roll buttons
    player/
      player_state_machine.gd  # pure transition function
      player.gd
      player.tscn
    weapons/
      weapon_data.gd           # Resource
      weapon.gd                # runtime node, owns the hitbox
    enemies/
      enemy_data.gd            # Resource
      enemy.gd                 # base, behaviour driven by data
      enemy.tscn
    level/
      room_data.gd             # Resource
      level_generator.gd       # deterministic, seeded
    ui/
      hud.tscn
      sandbox_menu.tscn
  data/
    weapons/   rusty_blade.tres, ember_spear.tres
    enemies/   shambler.tres, cinder_bat.tres, crown_brute.tres
    rooms/     room_spawn.tscn, room_a.tscn, room_b.tscn, room_exit.tscn
  levels/
    sandbox.tscn               # the test room
  tests/
    test_game_config.gd  test_damage.gd  test_health.gd
    test_input_router.gd  test_player_state_machine.gd
    test_weapon_data.gd  test_enemy_data.gd  test_level_generator.gd
```

---

### Task 1: Project bootstrap, GameConfig, and a working test runner

**Files:**
- Create: `game/project.godot`, `game/src/core/game_config.gd`, `game/tests/test_game_config.gd`
- Create: `game/addons/gdUnit4/` (vendored from upstream release)
- Modify: nothing. `.gitignore` already ignores `.godot/` at any depth.

**Interfaces:**
- Consumes: nothing.
- Produces: `GameConfig` autoload with `const TILE_SIZE: int = 16`, `const BASE_WIDTH: int = 384`, `const BASE_HEIGHT: int = 216`, `static func tiles(n: float) -> float`, `static func tiles_v(x: float, y: float) -> Vector2`. Every later task converts through these.

- [ ] **Step 1: Vendor GdUnit4 and confirm it supports Godot 4.7**

Download the latest GdUnit4 release into `game/addons/gdUnit4/`. If its `plugin.cfg` or docs do not claim Godot 4.7 support, stop and record a `Ruling:` — fall back to GUT (`bitwes/Gut`) and adapt the test command in Global Constraints. Do not proceed on an addon that fails to load.

- [ ] **Step 2: Create `game/project.godot`**

Set: `config/name="Cinder & Crown"`, `config/features=PackedStringArray("4.7", "GL Compatibility")`, viewport 384×216, `display/window/stretch/mode="canvas_items"`, `display/window/stretch/aspect="keep"`, `rendering/textures/canvas_textures/default_texture_filter=0` (nearest), `physics/common/physics_ticks_per_second=60`, autoload `GameConfig="*res://src/core/game_config.gd"`, and enable the `gdUnit4` plugin.

- [ ] **Step 3: Write the failing test**

```gdscript
# game/tests/test_game_config.gd
extends GdUnitTestSuite

func test_tile_size_is_sixteen() -> void:
	assert_int(GameConfig.TILE_SIZE).is_equal(16)

func test_base_resolution_integer_scales_to_1080p() -> void:
	assert_int(1920 / GameConfig.BASE_WIDTH).is_equal(5)
	assert_int(1080 / GameConfig.BASE_HEIGHT).is_equal(5)
	assert_int(1920 % GameConfig.BASE_WIDTH).is_equal(0)
	assert_int(1080 % GameConfig.BASE_HEIGHT).is_equal(0)

func test_tiles_converts_to_pixels() -> void:
	assert_float(GameConfig.tiles(1.0)).is_equal(16.0)
	assert_float(GameConfig.tiles(2.5)).is_equal(40.0)

func test_tiles_v_converts_both_axes() -> void:
	assert_vector(GameConfig.tiles_v(1.0, 2.0)).is_equal(Vector2(16.0, 32.0))
```

- [ ] **Step 4: Run it and watch it fail**

Run the Global Constraints test command.
Expected: FAIL — `GameConfig` is not a known identifier.

- [ ] **Step 5: Implement `game/src/core/game_config.gd`**

`extends Node`. The four constants and two static functions from the Interfaces block. Nothing else — this file is a constants table, not a manager.

- [ ] **Step 6: Run the tests and watch them pass**

Expected: PASS, 4 of 4.

- [ ] **Step 7: Verify the project imports clean**

Run: `<godot> --headless --path game --quit`
Expected: exit 0, and no line containing `ERROR` or `SCRIPT ERROR` in the output.

- [ ] **Step 8: Commit**

```bash
git add game
git commit -m "feat: bootstrap Godot project with GameConfig and GdUnit4"
```

---

### Task 2: Damage arithmetic and the Health component

**Files:**
- Create: `game/src/core/damage.gd`, `game/src/core/health.gd`
- Test: `game/tests/test_damage.gd`, `game/tests/test_health.gd`

**Interfaces:**
- Consumes: `GameConfig` (Task 1).
- Produces:
  - `Damage.compute(base: int, multiplier: float, defense: int) -> int` — static, clamps at 0.
  - `Health` (`class_name Health extends Node`): `@export var max_health: int`, `var current: int`, `func take_damage(amount: int) -> int` returning damage actually absorbed, `func heal(amount: int) -> void`, `func is_alive() -> bool`, `signal health_changed(current: int, max_health: int)`, `signal died`.

- [ ] **Step 1: Write the failing tests**

```gdscript
# game/tests/test_damage.gd
func test_applies_multiplier_then_subtracts_defense() -> void:
	assert_int(Damage.compute(10, 2.0, 5)).is_equal(15)

func test_rounds_down_fractional_damage() -> void:
	assert_int(Damage.compute(10, 1.55, 0)).is_equal(15)

func test_defense_exceeding_damage_clamps_to_zero() -> void:
	assert_int(Damage.compute(5, 1.0, 99)).is_equal(0)

func test_negative_base_never_heals() -> void:
	assert_int(Damage.compute(-10, 1.0, 0)).is_equal(0)

func test_zero_multiplier_deals_nothing() -> void:
	assert_int(Damage.compute(50, 0.0, 0)).is_equal(0)
```

```gdscript
# game/tests/test_health.gd
func test_take_damage_reduces_current() -> void        # 100 hp, take 30 -> current 70, returns 30
func test_overkill_reports_only_absorbed_damage() -> void  # 10 hp, take 999 -> current 0, returns 10
func test_death_emits_died_once() -> void              # two lethal hits -> died emitted exactly once
func test_damage_after_death_absorbs_nothing() -> void # returns 0, current stays 0
func test_heal_cannot_exceed_max() -> void             # 100 max, 90 current, heal 50 -> 100
func test_health_changed_carries_current_and_max() -> void
```

- [ ] **Step 2: Run and watch them fail**

Expected: FAIL — `Damage` and `Health` not defined.

- [ ] **Step 3: Implement `Damage` and `Health`**

`Damage.compute` applies the multiplier, subtracts defense, floors, then clamps to `0`. `Health.take_damage` returns `min(amount, current)` before mutation and emits `died` only on the transition into `current == 0`.

- [ ] **Step 4: Run and watch them pass**

Expected: PASS, 11 of 11.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: add damage arithmetic and Health component"
```

---

### Task 3: InputRouter — keyboard, gamepad and touch as one interface

**Files:**
- Create: `game/src/input/input_router.gd`, `game/src/input/touch_controls.tscn`
- Modify: `game/project.godot` (InputMap actions, `InputRouter` autoload)
- Test: `game/tests/test_input_router.gd`

**Interfaces:**
- Consumes: `GameConfig` (Task 1).
- Produces: `InputRouter` autoload:
  - `func move_axis() -> float` — −1.0..1.0
  - `func jump_held() -> bool`, `func jump_buffered() -> bool`, `func consume_jump() -> void`
  - `func attack_buffered() -> bool`, `func consume_attack() -> void`
  - `func roll_buffered() -> bool`, `func consume_roll() -> void`
  - `func swap_weapon_pressed() -> bool`
  - `func set_virtual_axis(value: float) -> void`, `func set_virtual_button(action: StringName, pressed: bool) -> void` — the touch layer's only entry point
  - `const BUFFER_SECONDS: float = 0.12`

InputMap actions: `move_left`, `move_right`, `jump`, `attack`, `roll`, `swap_weapon` — each bound to a key **and** a gamepad button.

- [ ] **Step 1: Write the failing tests**

```gdscript
# game/tests/test_input_router.gd
func test_virtual_axis_drives_move_axis() -> void
func test_opposing_virtual_and_physical_input_resolves_to_zero() -> void
	# left physical + right virtual on the same frame -> 0.0, and stable across
	# repeated polls. Documents the rule: opposing inputs cancel, never jitter.
func test_axis_is_clamped_to_unit_range() -> void   # set_virtual_axis(5.0) -> 1.0
func test_jump_buffer_expires_after_buffer_seconds() -> void
func test_consume_jump_clears_the_buffer() -> void
func test_buffer_survives_shorter_than_buffer_seconds() -> void
```

- [ ] **Step 2: Run and watch them fail**

Expected: FAIL — `InputRouter` not defined.

- [ ] **Step 3: Add the InputMap actions and the autoload to `project.godot`**

- [ ] **Step 4: Implement `input_router.gd`**

Each buffered action holds a timestamp; `*_buffered()` is true while `now - stamp < BUFFER_SECONDS`. Physical and virtual axes are summed, then clamped — which is what makes opposing inputs cancel deterministically.

- [ ] **Step 5: Run and watch them pass**

Expected: PASS, 6 of 6.

- [ ] **Step 6: Build `touch_controls.tscn`**

A `CanvasLayer` with a left-side virtual stick and right-side Attack / Jump / Roll buttons, all sized and positioned in tiles via `GameConfig`. Buttons call only `InputRouter.set_virtual_*`. Visible when `DisplayServer.is_touchscreen_available()`, and it must not suppress keyboard input when shown.

- [ ] **Step 7: Commit**

```bash
git commit -m "feat: add InputRouter unifying keyboard, gamepad and touch"
```

---

### Task 4: Player — state machine, movement, roll i-frames, health

**Files:**
- Create: `game/src/player/player_state_machine.gd`, `game/src/player/player.gd`, `game/src/player/player.tscn`
- Test: `game/tests/test_player_state_machine.gd`

**Interfaces:**
- Consumes: `GameConfig`, `InputRouter`, `Health`.
- Produces:
  - `PlayerState` enum: `IDLE, RUN, JUMP, FALL, ROLL, ATTACK, HURT`
  - `PlayerStateMachine.next_state(current: PlayerState, ctx: Dictionary) -> PlayerState` — pure, no engine access. `ctx` keys: `on_floor: bool`, `move_axis: float`, `jump_buffered: bool`, `attack_buffered: bool`, `roll_buffered: bool`, `state_time: float`, `coyote_time: float`, `hurt: bool`.
  - `Player` node: `func is_invincible() -> bool`, `signal died`
  - Tuning constants on `Player`, all in tiles: `RUN_SPEED = 9.0` (tiles/s), `JUMP_HEIGHT = 3.2` (tiles), `ROLL_SPEED = 14.0`, `ROLL_DURATION = 0.32` (s), `IFRAME_WINDOW = Vector2(0.04, 0.26)` (s within the roll), `COYOTE_TIME = 0.1` (s), `GRAVITY = 56.0` (tiles/s²).

- [ ] **Step 1: Write the failing tests**

```gdscript
# game/tests/test_player_state_machine.gd
func test_idle_to_run_on_move_input() -> void
func test_run_to_idle_when_input_releases() -> void
func test_jump_buffered_on_floor_enters_jump() -> void
func test_jump_within_coyote_time_still_jumps_off_floor() -> void
func test_jump_after_coyote_time_expires_is_refused() -> void
func test_roll_cannot_be_interrupted_before_duration_elapses() -> void
func test_roll_returns_to_idle_after_duration() -> void
func test_attack_from_idle_enters_attack() -> void
func test_hurt_overrides_every_state_except_roll() -> void
	# roll's i-frames are the point of the move; a hit landing mid-roll is ignored
func test_falling_when_airborne_without_upward_velocity() -> void
```

- [ ] **Step 2: Run and watch them fail**

Expected: FAIL — `PlayerStateMachine` not defined.

- [ ] **Step 3: Implement `player_state_machine.gd` as a pure transition table**

No `Input`, no `get_node`, no `delta` — it receives `ctx` and returns a state. This is what makes it testable headlessly, and it is the only place transition rules may live.

- [ ] **Step 4: Run and watch them pass**

Expected: PASS, 10 of 10.

- [ ] **Step 5: Implement `player.gd` and `player.tscn`**

`CharacterBody2D` with `CollisionShape2D`, `Health`, a `Hurtbox` `Area2D`, and a placeholder `ColorRect` 1×2 tiles. Per physics frame: build `ctx` from `InputRouter` and floor state, call `next_state`, apply the velocity for the resulting state, `move_and_slide()`. `is_invincible()` is true while in `ROLL` and `state_time` falls inside `IFRAME_WINDOW`. Gravity, speeds and jump height convert through `GameConfig.tiles()` — no pixel literals.

- [ ] **Step 6: Verify the project still imports clean**

Run: `<godot> --headless --path game --quit`
Expected: exit 0, no `SCRIPT ERROR`.

- [ ] **Step 7: Commit**

```bash
git commit -m "feat: add player state machine, movement and roll i-frames"
```

---

### Task 5: Data-driven weapons

**Files:**
- Create: `game/src/weapons/weapon_data.gd`, `game/src/weapons/weapon.gd`, `game/src/core/hit_stop.gd`
- Create: `game/data/weapons/rusty_blade.tres`, `game/data/weapons/ember_spear.tres`
- Modify: `game/src/player/player.gd` (hold two weapons, swap between them)
- Test: `game/tests/test_weapon_data.gd`

**Interfaces:**
- Consumes: `GameConfig`, `Damage`, `PlayerState` (Task 4).
- Produces:
  - `WeaponData extends Resource`: `@export var display_name: String`, `damage: int`, `attack_duration: float`, `hit_window: Vector2` (start/end seconds within the attack), `knockback_tiles: float`, `hitbox_size_tiles: Vector2`, `hitbox_offset_tiles: Vector2`, `hit_stop_seconds: float`
  - `WeaponData.is_hit_window_valid() -> bool` — start ≥ 0, start < end, end ≤ `attack_duration`
  - `Weapon` node: `func equip(data: WeaponData) -> void`, `func start_attack() -> void`, `func cancel_attack() -> void`, `func is_hitbox_active() -> bool`, `signal hit_landed(target: Node, damage: int)`
  - `HitStop` autoload: `func freeze(seconds: float) -> void` (scales `Engine.time_scale`, restores it on timeout)

- [ ] **Step 1: Write the failing tests**

```gdscript
# game/tests/test_weapon_data.gd
func test_both_shipped_weapons_load_from_disk() -> void
	# load("res://data/weapons/rusty_blade.tres") and ember_spear.tres are WeaponData
func test_shipped_weapons_have_valid_hit_windows() -> void
func test_hit_window_starting_after_it_ends_is_invalid() -> void
func test_hit_window_past_attack_duration_is_invalid() -> void
func test_hitbox_inactive_before_window_opens() -> void
func test_hitbox_active_inside_window() -> void
func test_hitbox_inactive_after_window_closes() -> void
func test_cancel_attack_deactivates_hitbox_immediately() -> void
func test_swapping_weapon_mid_hit_window_withdraws_the_hitbox() -> void
	# Review Focus 1: equip() during an active window must cancel the attack,
	# leave is_hitbox_active() false, and reset elapsed time so the new
	# weapon does not inherit the old window's progress.
```

- [ ] **Step 2: Run and watch them fail**

Expected: FAIL — `WeaponData` not defined; the two `.tres` files do not exist.

- [ ] **Step 3: Implement `weapon_data.gd`, then author the two weapons**

`rusty_blade` — fast, short reach, low damage, 3-hit feel. `ember_spear` — slower, longer reach, higher damage. Values in tiles and seconds. These two files are the proof the system is data-driven: a third weapon must need no code change.

- [ ] **Step 4: Implement `weapon.gd` and `HitStop`**

`Weapon` owns an `Area2D` hitbox whose shape it resizes from `hitbox_size_tiles` on `equip()`. `equip()` calls `cancel_attack()` first — that is the fix for Review Focus 1. On a landed hit, call `HitStop.freeze(data.hit_stop_seconds)`.

- [ ] **Step 5: Wire two weapon slots into `player.gd`**

An array of two `WeaponData`, swapped on `InputRouter.swap_weapon_pressed()`. Swapping is always allowed — no stamina, no lockout — per the Dead Cells combat model.

- [ ] **Step 6: Run and watch them pass**

Expected: PASS, 9 of 9.

- [ ] **Step 7: Commit**

```bash
git commit -m "feat: add data-driven weapons with hit windows and hit-stop"
```

---

### Task 6: Enemy base class and three data-driven types

**Files:**
- Create: `game/src/enemies/enemy_data.gd`, `game/src/enemies/enemy.gd`, `game/src/enemies/enemy.tscn`
- Create: `game/data/enemies/shambler.tres`, `cinder_bat.tres`, `crown_brute.tres`
- Test: `game/tests/test_enemy_data.gd`

**Interfaces:**
- Consumes: `GameConfig`, `Damage`, `Health`.
- Produces:
  - `EnemyData extends Resource`: `display_name: String`, `max_health: int`, `move_speed_tiles: float`, `attack_damage: int`, `attack_range_tiles: float`, `telegraph_seconds: float`, `recovery_seconds: float`, `behaviour: Behaviour` where `enum Behaviour { CHASER, FLYER, CHARGER }`, `body_size_tiles: Vector2`, `tint: Color`
  - `Enemy` node: `func configure(data: EnemyData) -> void`, `func begin_telegraph() -> void`, `func is_telegraphing() -> bool`, `signal attack_released(damage: int)`, `signal died`

- [ ] **Step 1: Write the failing tests**

```gdscript
# game/tests/test_enemy_data.gd
func test_all_three_shipped_enemies_load_from_disk() -> void
func test_shipped_enemies_have_positive_health_and_nonzero_telegraph() -> void
	# A telegraph of 0 is unreadable and unfair; assert every enemy telegraphs.
func test_configure_sets_health_from_data() -> void
func test_telegraph_releases_attack_after_telegraph_seconds() -> void
func test_death_during_telegraph_cancels_the_attack() -> void
	# Review Focus 4: kill mid-wind-up -> attack_released never fires.
func test_dead_enemy_cannot_begin_a_new_telegraph() -> void
func test_three_behaviours_are_all_represented_by_shipped_data() -> void
```

- [ ] **Step 2: Run and watch them fail**

Expected: FAIL — `EnemyData` not defined.

- [ ] **Step 3: Implement `enemy_data.gd`, then author the three enemies**

`shambler` — slow CHASER, ground, medium health. `cinder_bat` — fast FLYER, low health, erratic. `crown_brute` — slow CHARGER, high health, long telegraph, heavy hit. Every value from data; `behaviour` selects a movement strategy, and adding a fourth enemy must need only a new `.tres`.

- [ ] **Step 4: Implement `enemy.gd` and `enemy.tscn`**

`CharacterBody2D`, `Health`, hurtbox, placeholder `ColorRect` sized from `body_size_tiles` and coloured by `tint`. Telegraph runs on a `Timer`; `Health.died` must stop that timer — the fix for Review Focus 4.

- [ ] **Step 5: Run and watch them pass**

Expected: PASS, 7 of 7.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat: add enemy base class with three data-driven types"
```

---

### Task 7: Sandbox test room, spawn/swap menu and HUD

**Files:**
- Create: `game/levels/sandbox.tscn`, `game/src/ui/sandbox_menu.tscn`, `game/src/ui/hud.tscn`, and their scripts
- Modify: `game/project.godot` (`run/main_scene` = sandbox)

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: the first build the human can actually play. No new API for later tasks.

- [ ] **Step 1: Build `sandbox.tscn`**

Flat floor, a couple of platforms at jumpable heights (derived from `Player.JUMP_HEIGHT`, not guessed), walls, player spawn.

- [ ] **Step 2: Build `sandbox_menu.tscn`**

A panel that scans `res://data/enemies/` and `res://data/weapons/` **at runtime** and lists what it finds — a dropped-in `.tres` must appear with no code change. Controls: spawn each enemy, clear all enemies, assign either weapon to either slot, reset the player, toggle a hitbox/hurtbox debug overlay.

- [ ] **Step 3: Build `hud.tscn`**

Player health bar, current weapon names for both slots, live enemy count.

- [ ] **Step 4: Verify it runs**

Run: `<godot> --headless --path game --quit-after 180`
Expected: exit 0, no `SCRIPT ERROR` in output.

- [ ] **Step 5: Run the whole suite**

Expected: PASS, every test from Tasks 1–6 still green.

- [ ] **Step 6: Commit, then hand it to the human to play**

```bash
git commit -m "feat: add sandbox test room with spawn/swap menu and HUD"
```

**This is the first checkpoint where feel matters.** Report to the human that the prototype is playable and ask them to try it, naming what cannot be tested automatically: jump arc, roll distance and i-frame generosity, attack reach, hit-stop weight, enemy telegraph readability.

---

### Task 8: Deterministic room-based level generation

**Files:**
- Create: `game/src/level/room_data.gd`, `game/src/level/level_generator.gd`
- Create: `game/data/rooms/room_spawn.tscn`, `room_a.tscn`, `room_b.tscn`, `room_exit.tscn`
- Test: `game/tests/test_level_generator.gd`

**Interfaces:**
- Consumes: `GameConfig`.
- Produces:
  - `RoomData extends Resource`: `scene: PackedScene`, `kind: Kind` where `enum Kind { SPAWN, NORMAL, EXIT }`, `size_tiles: Vector2i`
  - `LevelGenerator.generate(pool: Array[RoomData], room_count: int, rng_seed: int) -> Array[RoomData]` — static, deterministic, no engine state

- [ ] **Step 1: Write the failing tests**

```gdscript
# game/tests/test_level_generator.gd
func test_same_seed_produces_identical_layout() -> void
func test_different_seeds_produce_different_layouts() -> void
func test_first_room_is_always_spawn() -> void
func test_last_room_is_always_exit() -> void
func test_returns_requested_room_count() -> void
func test_no_two_identical_rooms_in_a_row_when_pool_allows_it() -> void
func test_single_room_pool_returns_without_looping() -> void
	# Review Focus 3: a pool of one cannot satisfy "no repeats"; it must
	# relax that rule rather than spin forever.
func test_empty_pool_returns_empty_array() -> void
func test_pool_without_an_exit_room_returns_empty_array() -> void
```

- [ ] **Step 2: Run and watch them fail**

Expected: FAIL — `LevelGenerator` not defined.

- [ ] **Step 3: Implement `level_generator.gd`**

Seed a `RandomNumberGenerator` from `rng_seed`. Pick SPAWN first, EXIT last, fill the middle from NORMAL rooms. The no-repeat rule is a **preference with a bounded retry count**, not a loop condition — that is what makes the single-room pool terminate. Return `[]` for an unsatisfiable pool rather than a partial level.

- [ ] **Step 4: Run and watch them pass**

Expected: PASS, 9 of 9.

- [ ] **Step 5: Add a generated-level entry point**

A scene that generates a level from a seed, instances the rooms end to end, and places the player at the spawn. The sandbox room stays as-is and reachable.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat: add deterministic seeded room-based level generation"
```

---

### Task 9: Windows and web export builds (local only)

**Files:**
- Create: `game/export_presets.cfg` (git-ignored; recreated by whoever builds)
- Modify: `README.md` (what the game is, how to run it, project layout)

**Interfaces:**
- Consumes: a working project from Tasks 1–8.
- Produces: verified local builds. Nothing later depends on this.

- [ ] **Step 1: Install export templates for 4.7.2**

Run: `<godot> --headless --quit` after placing templates, or fetch them from the official 4.7.2 release. Verify: the Windows and Web presets both report templates found.

- [ ] **Step 2: Export the Windows build**

Run: `<godot> --headless --path game --export-release "Windows Desktop" ../build/windows/CinderAndCrown.exe`
Expected: exit 0, the `.exe` and `.pck` exist, no `ERROR` lines.

- [ ] **Step 3: Export the web build**

Web export must be single-threaded for iOS Safari — the reason the spec pins Godot 4.3+. Set the Web preset's threading support **off**.
Run: `<godot> --headless --path game --export-release "Web" ../build/web/index.html`
Expected: exit 0; `index.html`, `.wasm`, `.pck` all present.

- [ ] **Step 4: Serve the web build locally and confirm it boots**

Run a local static server over `build/web/` and fetch `index.html`.
Expected: HTTP 200 and the expected asset set. Local only — this does not leave the machine.

- [ ] **Step 5: Rewrite `README.md`**

What the game is, current status, how to open it in Godot, how to run the tests, the project layout, and the Phase 2/3 roadmap. Replace the two placeholder lines.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat: add Windows and web export builds; document the project"
```

- [ ] **Step 7: STOP — do not host anything**

Publishing the web build to GitHub Pages or Netlify sends it off the machine and makes it reachable by URL. Report that the build is ready and ask the human whether to host it, and where. Testing on an iPhone needs that answer first, so roadmap task 8 stays open until they give it.

---

## Phase 1 Done When

- All nine tasks committed, full suite green.
- The human has played the sandbox and signed off on the feel, or filed changes.
- A Windows build runs; a web build boots from a local server.
- Adding a weapon, enemy or room is demonstrably a new file and no code change.
- Hosting and on-device iPhone testing remain open, pending the human's go-ahead.

## Deliberately Not In Phase 1

Bosses, equipment beyond the two weapons, classes, story, dialogue, quests, native iOS, real art, audio, save/load, meta-progression.
