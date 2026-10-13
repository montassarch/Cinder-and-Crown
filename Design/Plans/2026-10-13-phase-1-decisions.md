# Phase 1 — Decisions and Known Gaps

Companion to [[Design/Plans/2026-10-13-phase-1-prototype]]. Every call made
during implementation that the plan did not already settle, plus what was
deliberately left undone. Written down because the working ledger it came
from is scratch and gets deleted.

## Decisions that shape the product

**Resolution.** 384×216 at `TILE_SIZE = 16`, integer-scaling ×5 to 1080p.
Every gameplay distance resolves through `GameConfig`, and — after the final
review — so does all world geometry, via `WorldBuilder`. The upgrade path is
tested, not assumed: `TILE_SIZE = 32` with a 768×432 viewport boots clean
and passes everything except the test that deliberately pins 16.

**Combat.** Dead Cells model. Two weapons swapped freely with no stamina and
no lockout; the roll is invincible only between 0.04s and 0.26s of its 0.32s,
so its exposed edges genuinely punish spamming; hit-stop is per-weapon;
every enemy telegraphs, and a zero telegraph is a test failure.

**Invincibility is gated in `Player`, not in the state machine.** The hurtbox
ignores damage while `is_invincible()`, so `ctx.hurt` reaching the transition
table always means the player was genuinely vulnerable. That keeps the table
one rule with no exceptions. Taking a hit outranks committed states — an
earlier ordering let a roll swallow hits and made the i-frame window
decoration.

**Committed states are snapshotted.** A swing's duration is captured when it
starts, so swapping weapons mid-swing cannot retroactively lengthen or
shorten a commitment you are already inside.

**`JUMP` means actually rising.** Airborne with zero vertical velocity is a
fall, because that is the first frame after stepping off a ledge. The
opposite polarity fired a free full-height jump off every ledge and made
coyote time unreachable.

**One content scanner.** `Content` scans `data/` and tolerates export
renaming (`.res`, `.remap`). Everything that enumerates content uses it, so a
new `.tres` reaches the sandbox menu and the level generator together. A
hardcoded list in one of them had them disagreeing.

**Time seams over frame counting.** `Weapon.advance()`, `Enemy.advance()` and
`Enemy.decide()` take `delta` explicitly so timing is provable headlessly.
This is what made the hit window's edges and the telegraph cancellation
testable rather than arguable.

**Gravity lives on `GameConfig`.** A world property, not a player one —
enemies fall by it, and so will projectiles and dropped items.

## Testing posture

GdUnit4, logic only, 179 tests. They cover damage arithmetic, the transition
table, input buffering and multi-device conflict, hit-window timing,
telegraph cancellation, seeded generation and world derivation. They do not
cover feel, and no test should pretend to.

Two workflow facts worth remembering: a task adding a new `class_name` must
run `--import` first (Godot resolves those from a cache built at import
time), and `--quit` hangs without a main scene — use `--import` or
`--quit-after`.

GdUnit4 aborts a suite at its first failure, which masks later failures in
the same file. Worth knowing when a fix seems to pass on its first run.

## Three mistakes worth not repeating

The final review caught three places where reasoning recorded as sound was
not. All are fixed; the pattern is what matters.

1. **A test can pin nothing and look like it pins something.** The
   export-renaming test asserted a real folder is non-empty and a fake one
   empty — it passed with the renaming support deleted.
2. **Asserting on data is not asserting on behaviour.** A test checked that
   three distinct behaviour integers appeared in three files. `CHARGER` had
   no implementation at all and the test passed.
3. **A stated cost can be the wrong cost.** Polling overlaps instead of
   `area_entered` was the right call, but the recorded cost was "one query
   per frame". The real cost was that polling has no self-exclusion, where
   `area_entered` accidentally did — which is how the player's own swing
   came to damage them.

The defects clustered at the seams, not inside components: data one side
produced and the other never consumed. **A grep for every `@export` field
appearing exactly once in the codebase is a cheap standing check** — it found
`recovery_seconds` and `knockback_tiles` sitting inert.

## Known gaps

**Builds verified.** Windows 105 MB, web 39 MB, both with zero test, addon
or report files packed. The web build was served locally over HTTP and every
asset returned 200, including the Apple touch icon iOS uses for Add to Home
Screen.

**iPhone testing is the one thing left.** It needs the web build hosted at a
URL, which leaves the machine, so it waits on an explicit decision about
where to put it.

**Deferred minors**, none urgent:

- `WeaponData.is_hit_window_valid()` is never called in production, so a
  weapon with an invalid window silently never deals damage.
- `InputRouter.jump_held()` is unused and its comment describes variable
  jump height, which does not exist.
- `sandbox_menu.gd` has the only raw pixel literal left in `src/` (a UI
  label width).
- `HitStop` restores `time_scale` to a literal `1.0` rather than the
  captured value, and `hit_stop_seconds` is unclamped — a mis-authored
  `.tres` could freeze the game for 30s.
- Input buffers run on real time while gameplay runs on scaled time, so a
  hit-stop can eat part of the buffer.
- Body collision is asymmetric: enemies are blocked by the player, the
  player walks through enemies.
- `Weapon._shape_hitbox()` ends with `face(1.0)`, so the debug overlay can
  draw the hitbox on the wrong side before the first swing.
- `InputRouter._process` calls `Input` directly rather than through its own
  seam, leaving the physical buffering path untestable.
- Two tests reach past an underscore (`_state_time`, `_duration_of`); the
  alternative is a setter existing only for tests.
- No explicit host interface for `HUD.bind()`; `Sandbox` and `RunLevel` each
  satisfy it informally.

## A fourth mistake, found while building

Godot's `ConfigFile` uses `;` as its comment character, **not `#`**. The
explanatory `#` comments I put inside the Web preset's options made Godot
abandon the rest of that section, so `variant/thread_support=false` was never
read.

It still produced a single-threaded build — because `false` is Godot's
default. So the thing I committed, documented in the README, and described
here as the setting protecting the iPhone target was **inert**. The file
looked like it carried a decision and did not.

It surfaced only because a second setting in the same section was also being
ignored and showed up wrong in the generated output. Now proven rather than
assumed: with `thread_support=true` the export produces the threaded WASM,
and with `false` it produces the no-threads one, byte-identical to
`web_nothreads_release.zip`.

The general shape is the same as the other three: **a thing that looks
load-bearing and isn't.** A test that pins nothing, a field nothing reads, a
config line nothing parses. Worth checking that a setting takes effect, not
just that it is written down.

## Phase 2 notes

- Mobile VRAM compression is off on the Web preset. It requires
  `rendering/textures/vram_compression/import_etc2_astc` in project
  settings, and with no texture assets yet it was only causing the export to
  fail. Turn both on when real art arrives.
- `Player.STARTING_WEAPONS` should become part of a class resource, which the
  roadmap already schedules.
