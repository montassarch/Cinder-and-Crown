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

## The full game (2026-10-30, plan: `Design/Plans/2026-10-30-full-game.md`)
- [x] Stage 1: four worlds, each with painted backdrops, tiles, weather, lights and two new enemies; four new rooms.
- [ ] Stage 2: a boss at the end of each world.
- [ ] Stage 3: double jump, air dash, weapon art on the hero, weapon drops.
- [ ] Stage 4: the hand-painted magic effects in combat.
- [ ] Stage 5: title, victory and death screens, balance, full-run playtest.
- [ ] Note: with 9 enemies on screen one physics frame took 23 ms in the bot run (once); watch performance on the phone.

## Weapons (2026-10-25)
- [x] Five weapons with 4-5 moves each (see `Design/Plans/2026-10-25-weapons.md`): sword, spear, gauntlet, bow, wand.
- [ ] Play each in the sandbox (Menu, Slot A / Slot B) and tell me what feels wrong: reach, speed, damage, the lunges.
- [ ] Per-weapon hero animations and weapon models (the hero always holds a sword; the new weapons reuse its swings).
- [ ] Magic: real wand effects and animation (you wanted to discuss this later).
- [ ] How the hero finds weapons in a run (drops, shop, starting choice) and whether weapons get upgrades.
- [ ] Real arrow art for the bow.

## Found by playtesting (2026-10-24; bot runs plus a real-browser session on the touch-ui build)
- [x] **HIGH (fixed, `/touch-2/`): the hero is hidden under the controls at the ends of a level.** The camera stops at the level edges, so at the exit the hero stands at the right edge under the thumb cluster, and at the start at the left edge under the stick. Fix: let the camera run past the ends (about 8 tiles right, 4 left) so the hero can stand mid-screen.
- [x] **MEDIUM (fixed): a Cinder Bat can hover on a ledge above the hero** and stall the fight: it cannot dive through the platform and the hero cannot reach it. It happened in every early bot run where a bat appeared. Fix: dive only with a clear line to the hero, else slide off the ledge edge.
- [x] **MEDIUM (fixed): the floating stick ring is fairly opaque** and can cover the hero when it lands there. Lighten the ring or show only the rim.
- [ ] **New: ledge safe spot.** Ground enemies cannot path up to a hero standing on a ledge; they gather underneath, unable to hit or be hit. Consider making ground enemies jump or wait at the edge, or letting the hero strike down.
- [ ] Waves stack: rushing through rooms left up to 15 enemies alive at once. Consider capping live enemies or gating the next wave.
- [ ] Balance: the bot averaged ~45 s per level, rarely needed the flask, and survived 10 minutes at depths 0-7 (it dies 1-2 times in 400 s starting at depth 8). Early depths look easy for a competent player.
- [ ] Web build is 43 MB (39.5 MB is the engine); first load time on a phone is not measured.
- Clean results: no script errors in 14 bot runs (about 2 hours of game time), no leaked nodes (node count stays flat, zero orphans), every enemy type appeared and died, the shop, boons and level changes all worked.
- Playtest bot: `game/tools/playtest_bot.gd` (usage in its header).

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
