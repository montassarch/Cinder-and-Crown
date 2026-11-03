# Effect packs (art/library/vfx)

Found by the asset-hunter agent, converted to game frames by it (one folder of numbered PNGs per effect plus meta.json).

| Pack | Author | Licence | Credit | In the repo |
|---|---|---|---|---|
| Free Pixel Effects Pack (codemanu_pixel_fx) | CodeManu, https://codemanu.itch.io/pixelart-effect-pack | CC-BY 4.0 (the page also says public domain; we credit to be safe) | "Free Pixel Effects Pack by CodeManu (CC-BY 4.0)" | yes |
| Pixel FX Pack - 11 Visual Effects (matheusgg28_pixel_fx) | MatheusGG28, https://matheusgg99.itch.io/impact-and-explosion-effects-pack | free for personal and commercial use, no credit required | "Pixel FX Pack by MatheusGG28" (optional) | yes |
| Free Pixel Effects Pack #1, #2, #3 (xyezawr_pack_*) | XYEzawr, https://xyezawr.itch.io | free for free and commercial projects, credit optional, may not be redistributed or resold | "Free Pixel Effects Pack by XYEzawr" (optional) | **no**: kept local (this repo is public); fetch them again as in tools/art/library/FETCH_XYEZAWR.md |

Where the game plays them: see the CUE_* constants in src/fx/combat_fx.gd, `projectile_fx` / `impact_fx` in
data/weapons/*.tres, and EnemyProjectile.FIREBALL_CUE. Missing packs are skipped quietly (LibraryFx returns null).
