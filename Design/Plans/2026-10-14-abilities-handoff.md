# Abilities: where things stand (handoff)

Branch: `spike/abilities` (work in progress, not merged). Test link still shows the knight without abilities.

## Approved design (Part 1: rules)
- **Mana:** max 100, +2/s regen, +6 per sword hit that lands.
- **Storm Blade (blue lightning):** 40 mana. 0.6 s raise-sword cast (bolt hits blade at 0.4 s), then 8 s of charged sword: +3 damage per hit, 30% chance to stun for 1.2 s. Fades over the last 2 s. Recast resets the timer.
- **Crimson Rend (red lightning wave):** 30 mana. 0.45 s vertical slash; wave leaves at 0.16 s, travels 14 tiles/s up to 10 tiles, hits every enemy once for 14 + knockback, stopped by walls. Castable in the air.
- Casts are committed (only a hit interrupts). Not enough mana: button does nothing and the mana bar flashes.
- Look for Rend: black core, red-orange edge, magenta-violet glow (user's reference image). Storm: clean blue.

## Done (code + tests, in this branch)
Mana, input actions skill1/skill2 (U/I keys, LB/RB pad), STORM/REND player states, weapon bonus damage + stun chance, enemy stun, RendWave, player wiring. 195 of 196 tests pass.

## Known failing test
`test_rend_wave.gd::test_a_wall_stops_the_wave`: Area2D `body_entered` is not fired for static walls the wave moves into. Fix (written, not yet applied): in `RendWave._physics_process`, query `get_world_2d().direct_space_state.intersect_shape` with the wave's shape against mask 1 and free the wave on a non-one-way static hit; drop `_on_body_entered`.

## Still to do (Parts 2 and 3 of the design were never reviewed)
1. Fix the wall test above, run the full suite.
2. Touch buttons STORM / REND next to ATK and ROLL (TouchControls: add to BUTTON_CENTERS_TILES and BUTTON_LABELS; keep the no-overlap test green).
3. Blue mana bar under the health bar in the HUD, flashing on `Player.mana_denied`.
4. Visuals: blue bolt from the sky + crackling arcs on the blade while charged (fade in the last 2 s, `Player.storm_struck` signal); Rend wave art already drawn in code.
5. Animations: knight has no "sword raised" or "vertical slash" frames; reuse Attack1 frame 1 (sword up) for the Storm cast and Attack3 frames 1-3 for Rend, or commission art.
6. Player states STORM/REND need entries in `PlayerVisual.animation_for` (currently fall through to idle).
7. Playtest on the phone, then tune the numbers above.

## Other branches
- `spike/hero-knight`: knight art, faster run, combo (test link). Merge this into `main` when the user approves ("make the knight the real game").
- `spike/hero-3d`, `spike/hero-animation`: discarded experiments, kept for reference.
- Laptop implementation on `phase-1-prototype` is set aside.
