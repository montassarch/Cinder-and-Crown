## Licence notes

- **Public repository.** `montassarch/Cinder-and-Crown` is public on GitHub, so committing a file is redistributing it.
  Everything committed here allows that (CC0, CC-BY, OGA-BY, or a free licence that does not forbid it).
- **XYEzawr Free Pixel Effects Pack #1, #2 (both uploads) and #3** - licence on each page: "can be used in both free and
  commercial projects ... modify ... Credit is not necessary ... You may not redistribute it or resell it." Shipping them inside
  the game is fine; putting the files in a public repo is not. They are built by `build_vfx.py` into
  `game/art/library/vfx/xyezawr_*` on the machine that has the downloads, and `vfx/.gitignore` keeps them out of git.
  If the repo is made private, or the files are only kept in an untracked asset folder, they can be used freely.
- **MatheusGG28 Pixel FX Pack** - "Free for personal and commercial use. No credits required." It names no licence and does not
  forbid redistribution; committed, but if you want zero doubt, treat it like the XYEzawr packs.
- **CodeManu Free Pixel Effects Pack** - the itch.io licence field says CC-BY 4.0 while the text says public domain; we follow
  the stricter one and credit it ("Free Pixel Effects Pack by CodeManu (CC-BY 4.0)").
- **496 RPG icons** - CC0 on OpenGameArt; the artist (7Soul1) states public domain; icons derived from commercial games were
  removed by the repacker before upload.
- **Gothicvania music** (Pascal Belisle, inside the ansimuz packs) was **not** taken: its terms ("free to use as long as you
  give credit") are not a standard licence. The Gothicvania art is public domain.
- **KayKit** asks not to resell unmodified copies; using and redistributing inside a game is CC0.
- **yd's demon statue** is based on a public-domain blend by Joseph (BlendSwap); both are public domain / CC0.

## Looked at but not taken (and why)

| What | Why not |
|---|---|
| Kenney.nl, Poly Pizza, Freesound, Pixabay | the network proxy answers 403 for these sites from this container. Kenney's packs were taken from OpenGameArt mirrors instead (Particle Pack, Game Icons; Castle Kit downloaded but not converted). |
| Freesound, Sketchfab, Mixamo, CraftPix | need an account / sign-in to download (Mixamo also forbids redistributing the raw FBX files). Not signed up, as instructed. |
| SpellSoft "2D Soulslike Knight", Kiddolink VFX, Levi V.B. "Blade Swings And Hits", Gothic tilesets by metalzebra / e-wouters | paid. |
| pimen effects, Penusbmic Skeleton Warrior, CreativeKind Necromancer, aamatniekss Fantasy Knight, brullov fire, combosmooth VFX | free for games but "do not redistribute": would need the same local-only treatment as XYEzawr. Good candidates if the repo goes private. |
| LPC sprites, "Animated Knight" (Botanic), Savino's Cemetery, Bone Golem, Lightning Effect (Varkalandar), painterly spell icons | CC-BY-SA / GPL: share-alike is outside the allowed licences. |
| Calciumtrice skeleton, Ars Notoria bosses, Clint Bellanger sparks / lightning, Pixel Lightning, JROB774 explosion, Lamoot RPG GUI, Ruined Cathedral (top-down) | CC-BY and fine, but top-down, small or weaker than what the library already has. Easy to add later. |
| Foozle "Lucifer Skeleton King" (CC0) | downloaded; it is a top-down 4-direction chibi boss, not a side-view sprite. |
| MV Platformer Skeleton (CC0) | ~30 px, too small next to the 45 px hero. |
| BearGames "15 Medieval Church Backgrounds" (152 MB), pixel-1992 gothic castle background | no licence text found on the page / the author says it was made with generative AI tools. |
| Summer Engine "CC0" sheets | AI-generated, licence unclear. |
| Jetrel explosion animations | download link is dead (404). |
| Gothicvania Cold Corridors (ansimuz) | the page shows no licence text (unlike the OpenGameArt packs). |

## Free AI and procedural tools (researched for a 4-core CPU container, no GPU, ~15 GB RAM)

**Image generation that runs here**
- **SD-Turbo** (`stabilityai/sd-turbo`, Stability AI Community License: free for people and companies under USD 1M revenue
  a year, outputs usable in games; download is not gated). One step, 512x512. **Tried** - see "AI sample" below.
- **Stable Diffusion 1.5 + LCM-LoRA** (CreativeML OpenRAIL-M; use-based restrictions only) - 4 steps; FastSD CPU (MIT,
  OpenVINO) claims ~1-12 s per image on a desktop i7; a 4-core cloud CPU is slower.
- **SDXS-512 / small distilled SD models** - sub-second on a fast CPU per FastSD's README; check each model card's licence.
- **Not practical here:** FLUX.1 (12B parameters; schnell is Apache 2.0 but its weights alone are ~24 GB in bf16, more than this container's RAM), SDXL + pixel-art-xl LoRA
  (nerijs, OpenRAIL-M; workable on CPU but ~1-3 min per image), HY-Motion / Kimodo text-to-motion (need 17-26 GB GPU VRAM).
- Honest verdict: AI pictures are useful as **concept / mood references and painted far-background layers**; they do
  not give clean, consistent, animatable sprites. The Blender pipeline (rigged CC0 models -> 8x render -> pixel shrink) stays
  the way to make game sprites.

**Motion / animation**
- Already in use: Quaternius **Universal Animation Library** (QAL). New here: **KayKit Character Animations** (CC0, about 125
  clips on the Rig_Medium skeleton, more for Rig_Large: melee 1H/2H/dual-wield, block, dodge, bow, magic, skeleton rise/taunt).
- **CMU Motion Capture Database** (BVH conversions on cgspeed.com): the data is described as free for research and
  commercial use (CMU asks for a citation); it needs cleanup and retargeting onto our rigs in Blender.
- Video-to-motion: **FreeMoCap** (AGPL code, outputs are yours), **BlendArMocap** (GPL Blender add-on, MediaPipe) - CPU-capable,
  record a webcam/phone clip of a move and get keyframes. MoMask / MDM (MIT code) are text-to-motion research models
  trained on HumanML3D (AMASS-derived data with non-commercial terms) - fine for a free personal game, GPU strongly
  preferred.
- **Mixamo**: royalty-free use in games but needs an Adobe account and forbids redistributing raw files - skipped.

**Procedural textures and pixel tools**
- **Blender procedural nodes** (CPU Cycles) - used here for every render.
- **ambientCG / Poly Haven** (CC0 PBR textures and HDRIs) - five ambientCG materials are in `textures/` both as 512 px
  Blender maps and as seamless 64/128 px pixel tiles (normal-map lighting + 16 colours + ashen grade, `build_textures.py`).
- **Material Maker** (MIT, Godot-based node texture tool) and **ArmorLab** need an OpenGL GPU - run them on a desktop.
- **Pixelorama** (MIT) / **LibreSprite** (GPL) for touching up frames by hand.

## AI sample (tried here)

`game/tools/art/library/ai_sdturbo_sample.py` ran **SD-Turbo** (1 step, 512x512, CPU float32; torch 2.15 CPU wheel and
diffusers 0.42 in a scratch venv; 2.5 GB of weights): **about 17 s per image** on the 4 cores, 13 s to load. Five prompts
(ruined cathedral, crypt corridor, forge hall, storm spire, hollow knight concept) and their conversion to 384x216
game-palette backdrops (`ai_to_backdrop.py`: crop, BOX shrink, 24 colours, ashen grade) are in
[ai_samples/](ai_samples/) - see [ai_sample_sheet.png](ai_samples/ai_sample_sheet.png).
Verdict: strong mood boards and usable **far** background layers after the palette pass (cathedral, crypt and storm spire
work best); the perspective is usually frontal rather than side-on, details are mushy, and nothing in it can be animated.
Good for concept passes and painted far layers; the Blender / pixel pipeline stays the way to make anything that moves.
The weights are not in the repo (Stability AI Community License: free for anyone under USD 1M revenue a year).
