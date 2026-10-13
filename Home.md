# Cinder & Crown

A Dead Cells-style 2D action roguelite. Start as a simple sandbox prototype, then grow into a bigger game with many bosses, equipment, classes, story, dialogue and quests.

## Map
- [[Design/Overview]]: goals, platforms, architecture
- [[Design/Plans/2026-10-13-phase-1-prototype]]: the Phase 1 implementation plan
- [[Design/Plans/2026-10-13-phase-1-decisions]]: decisions made, mistakes worth not repeating, known gaps
- [[Tasks/Roadmap]]: ordered task list
- Content/Bosses, Content/Equipment, Content/Classes: ideas to add after the prototype
- Story/Dialogue, Story/Quests: Phase 3

## Status
Phase 1 built and reviewed. 179 tests passing; sandbox and generated level
both playable. Export builds blocked on installing Godot export templates
(1.2 GB) from inside the editor.

## Decisions
- **Engine:** Godot 4.7.2, standard build (no C#)
- **Resolution:** 384x216 pixel art to start, integer-scales x5 to 1080p.
  All gameplay values in tiles so a move to Dead Cells-scale art is a
  config change, not a rewrite.
- **Combat:** Dead Cells model. Two weapons swapped freely, no stamina,
  roll with i-frames, hit-stop on impact, enemies telegraph.
- **Tests:** GdUnit4 for logic only. Feel is judged by playing it.
