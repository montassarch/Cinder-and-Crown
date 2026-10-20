# Skeleton knight art

Built from free assets by **Quaternius** (https://quaternius.com), Standard versions, used under the
Quaternius Asset License (QAL v1.0): free for personal, educational and commercial games, no credit
required, but the assets themselves may not be resold or redistributed as assets.

- **Modular Character Outfits - Fantasy** (Male Ranger outfit, the hooded body)
- **Universal Animation Library** (Sword_Idle, Jog, Jump, Roll, Hit, Death, Sword_Attack)

What was added here: a skull face with glowing red eyes inside the hood, a sword in the right hand,
a dark colour tint, all done in Blender by `tools/art/skeleton_knight_render.py`. The renders are shrunk to
pixel-art frames by `tools/art/skeleton_knight_pixel.py`. Only the finished frames are kept in the repo;
the original packs are not (download them again from quaternius.com / itch.io to regenerate).

Notes: the library has one sword swing, so Attack2 plays it backwards (a backhand) and Attack3 is a
slower copy. Dedicated combo animations would need custom posing.
