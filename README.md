# Cinder & Crown

A Dead Cells-style 2D action roguelite, built in Godot 4.7.2.

Two weapons swapped freely, no stamina, a roll that is invincible only in
its middle, hit-stop on impact, and enemies that telegraph before they
strike. Fast and aggressive — it rewards reading an enemy, not managing a
resource bar.

**Status:** Phase 1 prototype. Playable sandbox with a player, two weapons,
three enemies and seeded room generation. Placeholder art throughout. No
bosses, classes, story or audio yet.

## Running it

Open `game/` in Godot 4.7.2 and press <kbd>F5</kbd>. Or from a terminal:

```
godot --path game
```

The sandbox room is the main scene. The menu top-right spawns enemies and
assigns either weapon to either hand; **show boxes** draws hitboxes and
hurtboxes, tinting the player's hurtbox while the roll's invincibility
window is open. **generated level** switches to a seeded multi-room level;
<kbd>Esc</kbd> comes back.

### Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | `A` / `D` or arrows | left stick / d-pad |
| Jump | `Space` | A |
| Attack | `J` or left click | X |
| Roll | `Shift` or `K` | B |
| Swap weapon | `Q` | Y |

Touch controls appear automatically on a touchscreen — a left-hand stick
and right-hand buttons. They never suppress the keyboard, so a device with
both can use either.

## Tests

```
godot --headless --path game --import
godot --headless --path game -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests
```

150 tests, GdUnit4. The `--import` is not optional after adding a new
`class_name`: Godot resolves those from a cache rebuilt at import time.
`--ignoreHeadlessMode` is required because GdUnit4 otherwise refuses to run
without a display.

**What the tests do and don't cover.** They cover logic: damage arithmetic,
the player's transition table, input buffering and multi-device conflicts,
hit-window timing, telegraph cancellation, seeded generation. They do not
cover feel — no test can assert that a jump arc is satisfying or that a hit
lands with weight. That is judged by playing the sandbox.

## Layout

```
game/
  src/
    core/      GameConfig, Damage, Health, HitStop
    input/     InputRouter (keyboard + gamepad + touch), touch controls
    player/    pure state machine, player body
    weapons/   WeaponData resource, Weapon node
    enemies/   EnemyData resource, Enemy node
    level/     RoomData, LevelGenerator, run assembly
    ui/        HUD, sandbox menu, debug overlay
  data/
    weapons/   one .tres per weapon
    enemies/   one .tres per enemy
    rooms/     one .tscn + .tres per room
  levels/      sandbox.tscn, run_level.tscn
  tests/       GdUnit4 suites
Design/        design notes and the Phase 1 plan
```

## Two rules worth knowing before changing anything

**Everything addable is data.** A new weapon, enemy or room is a `.tres`
file under `game/data/` and no code change. The sandbox menu scans those
folders at runtime, so a dropped-in file appears without a rebuild. If
adding content requires editing a `match` statement, something has
regressed.

**No raw pixel literals in gameplay code.** Every distance, size, offset
and speed is expressed in *tiles* and converted through `GameConfig`. The
prototype runs at 384×216, but the intended destination is Dead
Cells-scale art — and that move should change `GameConfig.TILE_SIZE` and
the viewport, not every speed and hitbox in the codebase.

## Platforms

- **Windows** — exported from the `Windows Desktop` preset.
- **iPhone** — via the web export, opened in Safari and added to the Home
  Screen. The web preset has `thread_support=false` deliberately: a
  threaded build needs SharedArrayBuffer, which needs COOP/COEP headers
  that Safari will not give a Home Screen page. Turning threads on breaks
  the iPhone target while still working on desktop, which makes it an easy
  mistake to ship. Native iOS is out of scope — it needs a Mac and a paid
  Apple developer account.

## Roadmap

- **Phase 1** — prototype sandbox. Player, two weapons, three enemies,
  seeded rooms, exports. *Current.*
- **Phase 2** — boss framework and many bosses, equipment system, classes.
- **Phase 3** — dialogue system, quests.

See `Design/Overview.md` for intent and architecture, and
`Design/Plans/` for the implementation plan.
