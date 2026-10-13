# Design Overview

## Intent
Build a small, simple, playable prototype that works as a **sandbox for testing**. After it is confirmed working, expand it: many bosses with different styles, equipment, classes, then story, dialogue and quests. The user wants to be able to add whatever they want later.

## Platforms
- **PC:** Windows build, plus running in the Godot editor.
- **iPhone:** Godot web export, hosted, opened in Safari, then "Add to Home Screen". Native iOS needs a Mac plus a paid Apple developer account, so it is out of scope.
- Hosting publishes outside the machine, so ask before doing it (GitHub Pages or Netlify, unlisted link).

## Engine
Godot 4.3 or later (needed for single-threaded web export that works on iOS Safari). Not yet installed.

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
