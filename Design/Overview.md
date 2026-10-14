# Design Overview

## Intent
Build a small, simple, playable prototype that works as a **sandbox for testing**. After it is confirmed working, expand it: many bosses with different styles, equipment, classes, then story, dialogue and quests. The user wants to be able to add whatever they want later.

## Platforms
- **iPhone (primary).** Godot web export hosted on GitHub Pages, opened in Safari, then "Add to Home Screen" so it runs fullscreen. The view widens to fill the phone screen; touch controls are the main input and every new feature must be playable by touch. Native iOS needs a Mac plus a paid Apple developer account, so it is out of scope.
- **PC (secondary).** Windows build and the Godot editor, used for development; keyboard and gamepad keep working.
- The game site is public by link (approved 2026-10-14); the repo stays private.

## Engine
Godot 4.7.2, standard build (4.3 or later is what single-threaded web export for iOS Safari needs).

## Architecture principle: data-driven
Anything the user will add later is a data file (Godot Resource), not hard-coded:
- Weapons / equipment: one resource per item
- Enemies and bosses: base class plus a resource per type
- Classes: resource defining stats and starting gear
- Rooms: scene chunks assembled randomly
- Dialogue / quests (later): data files read by a small system

Adding content means adding a file, not changing core code.

## Input
Keyboard, gamepad and touch from day one. Touch has an on-screen stick plus attack, jump and roll buttons.

## Phase 1 scope (prototype)
Player (run, jump, roll, melee, health), 2 weapons, 2 or 3 simple enemies, a sandbox test room with a spawn and swap menu, basic random room assembly, placeholder art.

## Out of scope for now
Bosses, classes, full equipment, story, dialogue, quests, native iOS.
