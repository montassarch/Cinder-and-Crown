# Cinder & Crown

A Dead Cells-style 2D action roguelite. Start as a simple sandbox prototype, then grow into a bigger game with many bosses, equipment, classes, story, dialogue and quests.

## Map
- [[Design/Overview]]: goals, platforms, architecture
- [[Design/Plans/2026-10-13-phase-1-prototype]]: the Phase 1 implementation plan
- [[Tasks/Roadmap]]: ordered task list
- Content/Bosses, Content/Equipment, Content/Classes: ideas to add after the prototype
- Story/Dialogue, Story/Quests: Phase 3

## Status
Phase 1 implemented on branch `phase-1-prototype` (not yet merged): sandbox, player,
weapons, enemies, generated levels, Windows and web exports (local). See
[[README]] for how to run it. Still open: a hands-on feel pass, hosting the
web build, and testing on an iPhone. Repo: `montassarch/Cinder-and-Crown` (private).

## Decisions
- **Engine:** Godot 4.7.2, standard build (no C#)
- **Resolution:** 384x216 pixel art to start, integer-scales x5 to 1080p.
  All gameplay values in tiles so a move to Dead Cells-scale art is a
  config change, not a rewrite.
- **Combat:** Dead Cells model. Two weapons swapped freely, no stamina,
  roll with i-frames, hit-stop on impact, enemies telegraph.
- **Tests:** GdUnit4 for logic only. Feel is judged by playing it.
