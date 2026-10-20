# Skeleton knight and pre-rendered lightning

Branch: `feature/skeleton-knight` (on top of `feature/enemy-attacks`). Status: **player art and lightning built, enemies not started**.
Test builds: `/skeleton-1/` (first), `/skeleton-2/` (facing fix + new lightning).

## What changed
- **New player character:** the hooded skeleton knight. Free Quaternius outfit (Male Ranger) and Universal Animation Library, tinted dark in Blender, with a skull face (red eyes) and a longsword added, rendered from the side and shrunk to pixel art (100x72 frames, 25 px per metre, 28-colour palette).
  Tools: `game/tools/art/skeleton_knight_render.py` (Blender) and `skeleton_knight_pixel.py`. Credits: `game/art/skeleton_knight/CREDITS.md`.
- **Facing bug fixed:** the art faced left, so he looked backwards. Turning the rig in Blender does nothing (the animation overrides it), so the render camera and lights are mirrored instead. `tests/test_skeleton_art.gd` measures the skull side on the displayed frame.
- **Old sword trail, blade wrap and sky bolt removed.** They redrew jagged lines every physics tick and lagged on phones.
- **New lightning, pre-rendered in Blender** (`tools/art/lightning_render.py` + `lightning_pixel.py`, frames in `art/lightning/`, played by `LightningArt`):
  blue bolt from the sky and blue blade crackle for Storm; red blade crackle and a red wave sprite for Rend.

## Known limits
- One sword swing in the library: attack 2 plays it backwards, attack 3 is a slower copy.
- The hero is dark purple on a dark cathedral and the skull is a few pixels: a brighter palette or rim light would help.
- Enemies are still coloured boxes. They need sprites and code to draw them.
