# Blender script: renders static CC0 models (props, weapons, statues) into 8x sprites for pixel_frames.py (objects mode).
#   blender -b --factory-startup --disable-autoexec -P render_objects.py -- <set> <out_dir> <downloads dir>
# Sets: kaykit_dungeon_props, quaternius_weapons, kaykit_weapons, yd_statues.
# Each model is rendered alone with an orthographic camera at a fixed pixels-per-unit scale (so props keep their relative
# sizes) or, for weapon icons, fitted to a fixed box. Output: <out_dir>/<set>/<name>.png + objects.json.
import bpy, math, os, sys, json, mathutils

argv = sys.argv[sys.argv.index('--') + 1:]
SET, OUT, DL = argv[0], argv[1], argv[2]
SHRINK = 8
KD = os.path.join(DL, 'kaykit_dungeon/x/KayKit_Dungeon_Pack_1.1_FREE/KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf')
QW = os.path.join(DL, 'weapons_quaternius/x/Medieval_Weapons_Pack_-_Sept_2018/Medieval_Weapons_Pack_-_Sept_2018/FBX')
KA = os.path.join(DL, 'kaykit_adventurers/x/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Assets/gltf')

SETS = {
    # KayKit units: the characters are ~2.6 tall, so 17.5 px per unit keeps props in scale with kk_* characters and the hero
    'kaykit_dungeon_props': dict(category='props', pxm=17.5, view='front', ashen=True, author='Kay Lousberg', licence='CC0 1.0',
                                 credit='KayKit Dungeon Remastered by Kay Lousberg (credit optional)', url='https://kaylousberg.itch.io/kaykit-dungeon-remastered',
                                 files={n: os.path.join(KD, n + '.gltf') for n in (
                                     'torch_lit', 'torch_mounted', 'candle_triple', 'candle_lit', 'candle_melted', 'candle_thin_lit', 'banner_red', 'banner_patternA_red',
                                     'banner_shield_red', 'banner_thin_red', 'banner_triple_red', 'banner_patternC_brown', 'chest', 'chest_gold', 'barrel_large',
                                     'barrel_small_stack', 'keg', 'crates_stacked', 'pillar', 'pillar_decorated', 'column', 'rubble_large', 'rubble_half',
                                     'sword_shield_broken', 'sword_shield', 'coin_stack_large', 'keyring_hanging', 'shelf_small_candles', 'table_long_broken',
                                     'table_medium_broken', 'wall_archedwindow_gated', 'wall_broken', 'wall_cracked', 'wall_doorway', 'floor_tile_big_spikes',
                                     'bed_frame', 'stool', 'trunk_large_A', 'bottle_A_green', 'barrier_column', 'stairs')}),
    'yd_statues': dict(category='props', pxm=26.0, view='front', ashen=False, author='yd (demon statue from a public-domain blend by Joseph)',
                       licence='CC0 1.0', credit='yd (credit optional)', url='https://opengameart.org/content/knight-statue | https://opengameart.org/content/demon-statue',
                       files={'knight_statue_kneeling': os.path.join(DL, 'statue_knight/knight_statue.blend'),
                              'knight_statue_sitting': os.path.join(DL, 'statue_knight/knight_statue_sitting.blend'),
                              'knight_statue_lying': os.path.join(DL, 'statue_knight/knight_statue_lying.blend'),
                              'demon_statue': os.path.join(DL, 'statue_demon/demon_statue.blend')}),
    'quaternius_weapons': dict(category='weapons', fit=48, view='icon', ashen=False, author='Quaternius', licence='CC0 1.0',
                               credit='LowPoly Medieval Weapons by Quaternius (credit optional)', url='https://quaternius.itch.io/lowpoly-medieval-weapons',
                               files={os.path.splitext(f)[0].lower(): os.path.join(QW, f) for f in sorted(os.listdir(QW)) if f.endswith('.fbx')} if os.path.isdir(QW) else {}),
    'kaykit_weapons': dict(category='weapons', fit=48, view='icon', ashen=False, author='Kay Lousberg', licence='CC0 1.0',
                           credit='KayKit Adventurers by Kay Lousberg (credit optional)', url='https://kaylousberg.itch.io/kaykit-adventurers',
                           files={n: os.path.join(KA, n + '.gltf') for n in ('sword_1handed', 'sword_2handed', 'axe_1handed', 'axe_2handed', 'dagger', 'bow_withString',
                                                                              'crossbow_2handed', 'staff', 'wand', 'shield_badge', 'shield_round', 'shield_spikes',
                                                                              'shield_square', 'spellbook_open', 'quiver', 'smokebomb')}),
}
S = SETS[SET]


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    before = set(bpy.data.objects)
    ext = os.path.splitext(path)[1].lower()
    if ext in ('.glb', '.gltf'): bpy.ops.import_scene.gltf(filepath=path)
    elif ext == '.fbx': bpy.ops.import_scene.fbx(filepath=path)
    elif ext == '.blend':
        with bpy.data.libraries.load(path, link=False) as (src, dst): dst.objects = [n for n in src.objects]
        for o in dst.objects:
            if o is not None and o.type == 'MESH': bpy.context.scene.collection.objects.link(o)
    objs = [o for o in bpy.data.objects if o not in before]
    for o in objs:
        if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o, do_unlink=True)
    return [o for o in bpy.data.objects if o.type == 'MESH']


def bbox(objs):
    bpy.context.view_layer.update()
    lo = mathutils.Vector((1e9,) * 3); hi = mathutils.Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            lo = mathutils.Vector(map(min, lo, w)); hi = mathutils.Vector(map(max, hi, w))
    return lo, hi


def setup(objs):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = int(os.environ.get('SAMPLES', '24')); sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
    sc.render.film_transparent = True; sc.render.image_settings.color_mode = 'RGBA'
    root = bpy.data.objects.new('root', None); sc.collection.objects.link(root)
    for o in objs:
        if o.parent is None: o.parent = root
    if S['view'] == 'icon':
        # longest axis -> diagonal (bottom-left to top-right), seen from the front
        lo, hi = bbox(objs); size = hi - lo
        ax = max(range(3), key=lambda i: size[i])
        if ax == 0: root.rotation_euler = (0, math.radians(-90), 0)
        elif ax == 1: root.rotation_euler = (math.radians(90), 0, 0)
        bpy.context.view_layer.update()
        rot = mathutils.Matrix.Rotation(math.radians(-45), 4, 'Y')
        root.matrix_world = rot @ root.matrix_world
    bpy.context.view_layer.update()
    lo, hi = bbox(objs)
    centre = (lo + hi) / 2
    # camera looks along +Y from the front, a little from above (props) or straight (icons)
    elev = math.radians(12 if S['view'] == 'front' else 0); yaw = math.radians(18 if S['view'] == 'front' else 0)
    d = mathutils.Vector((math.sin(yaw) * math.cos(elev), -math.cos(yaw) * math.cos(elev), math.sin(elev)))
    cam_d = bpy.data.cameras.new('c'); cam_d.type = 'ORTHO'
    cam = bpy.data.objects.new('c', cam_d); sc.collection.objects.link(cam)
    cam.location = centre + d * 20
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.view_layer.update()
    # projected extent
    inv = cam.matrix_world.inverted()
    pts = []
    for o in objs:
        for c in o.bound_box: pts.append(inv @ (o.matrix_world @ mathutils.Vector(c)))
    w = max(p.x for p in pts) - min(p.x for p in pts); h = max(p.y for p in pts) - min(p.y for p in pts)
    cx = (max(p.x for p in pts) + min(p.x for p in pts)) / 2; cy = (max(p.y for p in pts) + min(p.y for p in pts)) / 2
    cam.location = cam.matrix_world @ mathutils.Vector((cx, cy, 0))
    if S.get('fit'):
        pxm = (S['fit'] - 4) / max(w, h)
    else:
        pxm = S['pxm']
    W = max(8, int(math.ceil((w * pxm + 6) / 8.0)) * 8); H = max(8, int(math.ceil((h * pxm + 6) / 8.0)) * 8)
    cam_d.ortho_scale = max(W, H) / pxm
    sc.render.resolution_x, sc.render.resolution_y = W * SHRINK, H * SHRINK
    sc.camera = cam

    def light(name, vec, energy, colour):
        ld = bpy.data.lights.new(name, 'SUN'); ld.energy = energy; ld.color = colour; ld.angle = math.radians(20)
        lo_ = bpy.data.objects.new(name, ld); sc.collection.objects.link(lo_)
        lo_.rotation_euler = (-mathutils.Vector(vec)).to_track_quat('-Z', 'Y').to_euler()
    light('key', (-1.0, -1.2, 1.3), 3.2, (1.0, 0.82, 0.62)); light('rim', (1.2, 1.0, 0.8), 2.6, (0.5, 0.6, 1.0)); light('fill', (0.3, -1, -0.2), 0.6, (0.8, 0.8, 1.0))
    sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
    sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.05, 0.05, 0.07, 1)
    sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6
    return pxm, (W, H)


info = {k: v for k, v in S.items() if k not in ('files',)}
info['objects'] = {}
os.makedirs(os.path.join(OUT, SET), exist_ok=True)
for name, path in S['files'].items():
    if not os.path.exists(path): print('missing', path); continue
    clear()
    objs = load(path)
    if not objs: print('no meshes', name); continue
    pxm, size = setup(objs)
    bpy.context.scene.render.filepath = os.path.join(OUT, SET, name + '.png')
    bpy.ops.render.render(write_still=True)
    info['objects'][name] = dict(source=os.path.basename(path), px_per_unit=round(pxm, 2), canvas=list(size))
    print('rendered', name, size)
json.dump(info, open(os.path.join(OUT, SET, 'objects.json'), 'w'), indent=1)
print('objects done', SET)
