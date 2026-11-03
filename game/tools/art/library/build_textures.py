# Builds seamless pixel-art wall / floor tiles from CC0 ambientCG PBR materials (game/art/library/textures/*).
#   python3 -I game/tools/art/library/build_textures.py <downloads dir>
# For each material: colour x ambient occlusion, lit by the normal map from the upper left (warm key, cool fill),
# shrunk to 64 and 128 px (both tile seamlessly because the source does), 16 colours, ashen grade.
# A 512 px copy of the colour + normal maps is kept in source/ for Blender renders.
import glob, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from PIL import Image, ImageChops

DL = sys.argv[1]
MATS = {'Bricks089': 'dark medieval brick wall (cathedral / castle backdrop)', 'Bricks008': 'clean church brick',
        'Rocks025': 'rough stone wall (crypt, ruins)', 'PavingStones150': 'paving stones (floor fill, courtyard)',
        'Ground065': 'rocky medieval ground (cemetery, swamp floor)'}


def lit(colour, normal, ao):
    """simple two-light shading from a GL normal map."""
    import math
    W, H = colour.size
    c = colour.load(); n = normal.load(); a = ao.load()
    L1 = (-0.55, 0.55, 0.63); L2 = (0.6, -0.3, 0.74)          # key from upper-left (GL normal: +Y up), fill from lower-right
    out = Image.new('RGB', (W, H)); o = out.load()
    for y in range(H):
        for x in range(W):
            nx, ny, nz = [(v / 255.0) * 2 - 1 for v in n[x, y][:3]]
            k = max(0.0, nx * L1[0] + ny * L1[1] + nz * L1[2]); f = max(0.0, nx * L2[0] + ny * L2[1] + nz * L2[2])
            occ = a[x, y] / 255.0 if isinstance(a[x, y], int) else a[x, y][0] / 255.0
            r, g, b = c[x, y][:3]
            o[x, y] = (min(255, int(r * occ * (0.25 + 0.95 * k * 1.0 + 0.25 * f * 0.7))),
                       min(255, int(g * occ * (0.25 + 0.95 * k * 0.92 + 0.25 * f * 0.8))),
                       min(255, int(b * occ * (0.25 + 0.95 * k * 0.80 + 0.25 * f * 1.1))))
    return out


rows = []
for mid, use in MATS.items():
    folder = glob.glob(os.path.join(DL, 'tex_ambientcg/x/*' + mid + '_1K-JPG'))[0]
    col = Image.open(glob.glob(os.path.join(folder, '*_Color.jpg'))[0]).convert('RGB')
    nor = Image.open(glob.glob(os.path.join(folder, '*_NormalGL.jpg'))[0]).convert('RGB')
    ao = Image.open(glob.glob(os.path.join(folder, '*_AmbientOcclusion.jpg'))[0]).convert('L')
    d = lib.out_dir('textures', mid.lower())
    src = os.path.join(d, 'source'); os.makedirs(src, exist_ok=True)
    col.resize((512, 512), Image.LANCZOS).save(os.path.join(src, mid + '_Color_512.jpg'), quality=88)
    nor.resize((512, 512), Image.LANCZOS).save(os.path.join(src, mid + '_NormalGL_512.jpg'), quality=90)
    base = lit(col.resize((512, 512), Image.LANCZOS), nor.resize((512, 512), Image.LANCZOS), ao.resize((512, 512), Image.LANCZOS))
    out = []
    for px in (64, 128):
        t = base.resize((px, px), Image.BOX).convert('RGBA')
        t = lib.quantize_set([t], 16)[0]
        t = lib.ashen(t, sat=0.5, val=0.9)
        lib.save(t, os.path.join(d, f'tile_{px}.png')); out.append(t)
    lib.write_meta(d, name=mid, author='ambientCG (Lennart Demes)', licence='CC0 1.0', url=f'https://ambientcg.com/view?id={mid}',
                   credit=f'Created using {mid} from ambientCG.com, licensed under CC0 1.0 (credit optional)', use=use,
                   notes='tile_64 / tile_128 tile seamlessly (4x4 / 8x8 game tiles). source/ has 512 px colour + normal maps for Blender.')
    tiled = Image.new('RGBA', (256, 128))
    for x in range(0, 256, 64):
        for y in range(0, 128, 64): tiled.alpha_composite(out[0], (x, y))
    rows.append((f'{mid}: tile_64 repeated, tile_128', [tiled, out[1]]))
    print(mid)
lib.contact_sheet(rows, os.path.join(lib.LIB, 'textures', 'preview.png'), zoom=2, max_cols=2)
