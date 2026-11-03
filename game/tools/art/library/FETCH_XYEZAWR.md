# Getting the xyezawr effect packs back

Their licence lets the game use them but not redistribute the files, so they are not in this public repo
(art/fx_packs/.gitignore). If art/fx_packs/xyezawr_pack_* is missing, the game still runs (enemy embers are then
drawn as plain glowing balls). To restore them:
1. Download "Free Pixel Effects Pack", "#2" and "#3" from https://xyezawr.itch.io ("name your own price", $0 works).
2. Convert them with the asset agent's build_vfx.py (branch worktree-agent-a85d102eca5f31723,
   game/tools/art/library/build_vfx.py) into art/fx_packs/xyezawr_pack_1, _2, _2_extra and _3.
