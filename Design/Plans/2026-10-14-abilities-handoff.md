# Abilities: where things stand (handoff)

Branch: `spike/abilities` (work in progress, not merged). Test link still shows the knight without abilities.

## Approved design (Part 1: rules)
- **Mana:** max 100, +2/s regen, +6 per sword hit that lands.
- **Storm Blade (blue lightning):** 40 mana. 0.6 s raise-sword cast (bolt hits blade at 0.4 s), then 8 s of charged sword: +3 damage per hit, 30% chance to stun for 1.2 s. Fades over the last 2 s. Recast resets the timer.
- **Crimson Rend (red lightning wave):** 30 mana. 0.45 s vertical slash; wave leaves at 0.16 s, travels 14 tiles/s up to 10 tiles, hits every enemy once for 14 + knockback, stopped by walls. Castable in the air.
- Casts are committed (only a hit interrupts). Not enough mana: button does nothing and the mana bar flashes.
- Look for Rend: black core, red-orange edge, magenta-violet glow (user's reference image). Storm: clean blue.

## Done (code + tests, in this branch; 200 of 200 tests pass)
Mana, input actions skill1/skill2 (U/I keys, LB/RB pad), STORM/REND player states, weapon bonus damage + stun chance, enemy stun, RendWave (walls stop it via a physics-space shape query), player wiring.
Added in the second session:
- Touch buttons STORM / REND left of ROLL / SWAP (`TouchControls`), covered by tests.
- Blue mana bar under the health bar, flashing on `Player.mana_denied` (`Hud.mana_fraction()`, `mana_flashing()`).
- `StormEffect` (child of Player): blue bolt from the sky on `storm_struck`, crackling arcs on the blade while charged, fading over the last 2 s.
- `PlayerVisual`: `storm` (Attack1 frames 0,1 then hold frame 1) and `rend` (Attack3 frames 1-6) animations, fitted to the cast times. Placeholder reuse of existing frames; commission real art later if wanted.

## Still to do
1. Playtest on the phone (not possible from a cloud session): check button placement, the blade/bolt position on the sprite (`StormEffect.BLADE_TILES`), and Rend timing against the slash frames.
2. Tune the numbers above after playtesting.
3. Parts 2 and 3 of the design were never reviewed by the user; confirm before merging.

## Other branches
- `spike/hero-knight`: knight art, faster run, combo (test link). Merge this into `main` when the user approves ("make the knight the real game").
- `spike/hero-3d`, `spike/hero-animation`: discarded experiments, kept for reference.
- Laptop implementation on `phase-1-prototype` is set aside.
