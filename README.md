# Cinder & Crown

A Dead Cells-style 2D action roguelite, built in Godot 4.7.2. Phase 1 is a playable **sandbox prototype**: a player who runs, jumps, rolls and attacks; two weapons; three enemies; a test room with a spawn/swap menu; and randomly assembled rooms with an exit. Everything is placeholder art on purpose. Bosses, classes, equipment, story, dialogue and quests come later ([roadmap](#roadmap)).

**Status:** Phase 1 done and played on an iPhone 14 Pro Max. The iPhone is the main platform. Since then: a black swordsman hero with a plague mask after a hit, Storm Blade and Crimson Rend abilities with mana, a ruined-cathedral backdrop, 12 data-driven boons, parry with riposte, and enemy telegraphs, poise and guard break (see `Design/Plans/`).

**Play it:** https://montassarch.github.io/Cinder-and-Crown/ in Safari. For fullscreen, tap Share > Add to Home Screen and launch it from the icon, in landscape.

## Run it

1. Install [Godot 4.7.2](https://godotengine.org/download) (standard build, **not** .NET).
2. Open `game/project.godot` in Godot and press **F5**. The main scene is the sandbox.

### Controls

| | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Move | A / D or arrows | Left stick or D-pad | Left stick |
| Jump (hold for height) | Space | A | JMP |
| Attack | J | X | ATK |
| Roll (i-frames) | K | B | ROLL |
| Swap weapon | Q | Y | SWAP |
| Storm Blade (40 mana) | U | LB | STORM |
| Crimson Rend (30 mana) | I | RB | REND |
| Parry (tap as an enemy's ring closes) | L | Left-stick click | PARRY |
| Sandbox menu | Tab | Start | Menu button |

The **menu** (it pauses the game) spawns enemies, clears them, assigns either weapon to either slot, resets the player, toggles hitbox/hurtbox debug boxes, and switches between the **Sandbox** and a **Generated level**. Reaching the gold exit gate in a generated level pauses on a **pick one of three boons** screen (tap a card, or press 1-3); once you choose, the next level is built from the next seed. Dying or "Reset player" starts a new run and drops your boons.

## Tests

[GdUnit4](https://github.com/MikeSchulze/gdUnit4) (vendored in `game/addons/`), logic and wiring only. Whether the game *feels* right is judged by playing it, not by a test.

```bash
godot --headless --path game --import        # once on a fresh checkout
godot --headless --path game -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests
```

`--ignoreHeadlessMode` is required; GdUnit4 refuses to run headless without it.

## Project layout

```
game/
  project.godot
  addons/gdUnit4/        vendored test framework
  src/
    core/                GameConfig (tile size, resolution), Damage, Health, HitStop, DataScanner
    input/               InputRouter (keyboard + gamepad + touch -> intents), touch controls
    player/              state machine (pure), player scene
    weapons/             WeaponData resource, Weapon runtime node
    enemies/             EnemyData resource, Enemy scene
    level/               RoomData resource, LevelGenerator (seeded, deterministic)
    ui/                  HUD, sandbox menu, debug overlay
  data/                  <- content lives here
    weapons/  enemies/  rooms/
  levels/                sandbox.tscn, generated_level.tscn
  tests/
  tools/                 export preset template
Design/ Tasks/ Home.md   planning notes (an Obsidian vault)
```

### Rules the code follows

- **Data-driven.** Weapons, enemies and rooms are files under `game/data/`, found by scanning the folder at runtime.
- **Tiles, not pixels.** Gameplay values are in tiles (or tiles/second) and convert through `GameConfig.tiles()`. `TILE_SIZE = 16` on a 384x216 base that integer-scales x5 to 1080p, so moving to higher-resolution art is a config change. (Room *scenes* are authored in pixels at the base tile size; a test checks every room.)
- **One input path.** Gameplay never calls `Input.*`; it asks `InputRouter`.

### Adding content

- **A weapon:** copy `data/weapons/rusty_blade.tres`, change the numbers. It shows up in the sandbox menu.
- **An enemy:** copy `data/enemies/shambler.tres`. Pick a `behaviour` (CHASER, FLYER, CHARGER). It shows up in the menu.
- **A room:** add `room_x.tscn` plus a `room_x.tres` (a `RoomData` pointing at it, with `kind` and `size_tiles`) under `data/rooms/`. `tests/test_rooms.gd` checks it has a full-width floor, stays inside its size, uses clearable platform heights, and (for spawn/exit rooms) has its `PlayerSpawn` / `ExitZone`.

## Export builds (local)

1. In Godot: *Editor > Manage Export Templates* and install the **4.7.2** templates (or unpack the official `Godot_v4.7.2-stable_export_templates.tpz` into `~/.local/share/godot/export_templates/4.7.2.stable/`).
2. Create your git-ignored presets: `cp game/tools/export_presets.template.cfg game/export_presets.cfg`
3. Export:

```bash
godot --headless --path game --export-release "Windows Desktop" ../build/windows/CinderAndCrown.exe
godot --headless --path game --export-release "Web" ../build/web/index.html
```

The web preset has **threading off**, which iOS Safari needs (no special server headers). Serve it over HTTP to try it; it will not run from `file://`:

```bash
cd build/web && python3 -m http.server 8000     # then open http://localhost:8000
```

The live site is the `gh-pages` branch (GitHub Pages, Deploy from branch `gh-pages` / root). To update it, export the web build and replace the files at the root of that branch. The site is public to anyone with the link.

## What is not verified

- **Game feel.** Jump arc, roll distance and i-frame generosity, attack reach, hit-stop weight, enemy telegraph readability, hurt stun-lock. These are constants, easy to retune.
- **The Windows build running.** It exports cleanly (`.exe` + `.pck`), but was built on Linux and never launched.
- **Other phones.** Played on an iPhone 14 Pro Max only; other iPhones and Android are untested.
- **Real gamepad and touch hardware.** Logic is tested with synthetic events.

## Roadmap

- **Phase 1 (this):** prototype sandbox.
- **Phase 2:** boss framework and many bosses; equipment system and classes.
- **Phase 3:** dialogue system; quest system.

Planning notes live in `Home.md`, `Design/` and `Tasks/`.
