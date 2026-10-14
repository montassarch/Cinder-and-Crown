# Cinder & Crown

A Dead Cells-style 2D action roguelite. Start as a simple sandbox prototype, then grow into a bigger game with many bosses, equipment, classes, story, dialogue and quests.

## Map
- [[Design/Overview]]: goals, platforms, architecture
- [[Design/Plans/2026-10-13-phase-1-prototype]]: the Phase 1 implementation plan
- [[Tasks/Roadmap]]: ordered task list
- [[Design/Plans/2026-10-14-phase-1-rulings]]: every decision, finding and gap from building Phase 1
- Content/Bosses, Content/Equipment, Content/Classes: ideas to add after the prototype
- Story/Dialogue, Story/Quests: Phase 3

## Status
Phase 1 is done and on `main`: sandbox, player, weapons, enemies, generated
levels. Played and signed off on an iPhone 14 Pro Max (2026-10-14).
Play it: https://montassarch.github.io/Cinder-and-Crown/ (Safari, then Share >
Add to Home Screen for fullscreen). See [[README]] for running it locally.
Next: Phase 2, starting with the boss framework.
Repo: `montassarch/Cinder-and-Crown` (private; the game site is public by link).

## Decisions
- **Platform focus: iPhone first.** The web build, launched from the home
  screen, is what we design and test for; touch controls are the primary input.
  Desktop keyboard/gamepad keep working but are secondary. (2026-10-14)
- **Codebase:** the cloud-session build (Build A) is the one we continue on
  `main`. The separate laptop implementation on branch `phase-1-prototype` is
  set aside, kept on GitHub but not used. (2026-10-14)
- **Engine:** Godot 4.7.2, standard build (no C#)
- **Resolution:** 384x216 pixel art to start, integer-scales x5 to 1080p.
  All gameplay values in tiles so a move to Dead Cells-scale art is a
  config change, not a rewrite.
- **Combat:** Dead Cells model. Two weapons swapped freely, no stamina,
  roll with i-frames, hit-stop on impact, enemies telegraph.
- **Tests:** GdUnit4 for logic only. Feel is judged by playing it.
