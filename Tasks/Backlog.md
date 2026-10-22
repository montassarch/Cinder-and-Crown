# Backlog: what is missing and what is next

Written 2026-10-22. The roadmap (`Roadmap.md`) has the big phases; this is the full working list.

## Decide now (needs you)
- [ ] Play the `/skeleton-3/` test build and say whether the player, enemies and lightning look right.
- [ ] Merge decision: `feature/runs` -> `feature/enemy-attacks` -> `feature/skeleton-knight` are stacked and unmerged. `main` has only the notes. Merging also needs publishing to the site root.
- [ ] The yellow "committed" tell ring hides whether a short wind-up is parry (red) or dodge (orange). Keep the hue, or mark commitment another way (pulse, thicker ring)?
- [ ] Delete the leftover remote branch `spike/skeleton-hero` (my session cannot delete remote branches).
- [ ] The laptop branch `phase-1-prototype` is still unmerged.
- [ ] The Windows build exports but was never launched.
- [ ] Licence note: the repo holds derived Quaternius frames (QAL: fine in a game, not redistributable as assets) and the Hero Knight source (keep the repo private or remove `tools/art/source/` before making it public).

## Art and feel (known gaps)
- [ ] Hero: dark purple on a dark cathedral, skull is a few pixels. Brighter palette, rim light, or a larger render. The painted-eye trick used on enemies could help.
- [ ] Combat animations: the library has one sword swing. Attack 2 plays it backwards, attack 3 is a slow copy; the Guard's three-hit string and the Penitent's thrust reuse it. Needs custom posed animations (scripted in Blender).
- [ ] Enemy polish: Crown Brute's death drops below the frame, Powder Pilgrim is small, Wisp and Bat are plain shapes, no death or hit effects.
- [ ] Lightning: thin and pixelated. Bolder, a glow, check the sky bolt in motion on a phone.
- [ ] Environment: the cathedral torches are flat. The Blender torch test (4 flame frames) was never added. Other props to make: gate, banner, crown, chests.
- [ ] Look the three render styles (smooth, pixel, toon) were compared once; pixel was chosen. Revisit if wanted.
- [ ] Judge every animation in motion on the phone, not just frames.

## Code (deferred minors from the final review)
- [ ] `EnemyProjectile._travelled` is not reset on reflect, so a far parry can die short of the Wisp.
- [ ] A bolt can hit two stacked enemies in one step (add a spent flag).
- [ ] A bolt meeting a rolling (invincible) hero is freed instead of passing through.
- [ ] `FloorWave` ignores walls and runs on past ledges (`RendWave` checks walls).
- [ ] Slam waves start 0.8 tiles out, so a hero standing inside the Brute is missed.
- [ ] The dive target is not set on the first wind-up frame.
- [ ] `_on_telegraph_timeout` guard `!= STUNNED` could recover a DEAD enemy (use `== TELEGRAPH`).
- [ ] One test name ("knocked past him") overstates what it checks; `attack_range_tiles` doc comment is out of date; `effective_moves()` rebuilds the implicit move every call.
- [ ] `enemy.gd` is ~650 lines: split per-kind move execution out before adding more kinds.
- [ ] Wall-clock timing tests (input buffers) were flaky; the two worst were fixed, check for others.
- [ ] README status is out of date (still says placeholder art).

## Phase 2: Content
- [ ] Boss framework, then many bosses with different styles.
- [ ] Equipment system and classes.

## Phase 3: Story
- [ ] Dialogue system.
- [ ] Quest system.
