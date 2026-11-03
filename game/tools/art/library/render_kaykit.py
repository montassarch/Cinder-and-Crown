# Blender script: renders KayKit (Kay Lousberg, CC0) rigged characters as side-view sprite frames, the same way as
# game/tools/art/enemy_render.py (orthographic side camera, 8x the game size, then pixel_frames.py shrinks them).
#   blender -b --factory-startup --disable-autoexec -P render_kaykit.py -- <char_id> <out_dir> <downloads dir> [anim ...]
# Output: <out_dir>/<char_id>/<Anim>/<n>.png (transparent) + eyes.json (eye pixel per frame, canvas, eye colour).
# Animations come from the KayKit Character Animations pack (Rig_Medium, CC0); weapons from the same packs.
import bpy, math, os, sys, json, mathutils
from bpy_extras.object_utils import world_to_camera_view

argv = sys.argv[sys.argv.index('--') + 1:]
CHAR, OUT, DL = argv[0], argv[1], argv[2]
ONLY = set(argv[3:])
SK = os.path.join(DL, 'kaykit_skeletons/x/KayKit_Skeletons_1.1_FREE/KayKit_Skeletons_1.1_FREE')
AD = os.path.join(DL, 'kaykit_adventurers/x/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE')
AN = os.path.join(DL, 'kaykit_anims/x/KayKit_Character_Animations_1.1/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium')
SHRINK = 8

# animation name -> (action, t0, t1, frames, loops). Names follow game/art/enemies (Idle Move Windup Strike Recover Stun Death Dash)
MELEE = {'Idle': ('Melee_2H_Idle', 0, 1, 6, True), 'Move': ('Walking_A', 0, 1, 8, True), 'Dash': ('Running_A', 0, 1, 6, True),
         'Windup': ('Melee_1H_Attack_Chop', 0.0, 0.42, 4, False), 'Strike': ('Melee_1H_Attack_Chop', 0.45, 0.68, 3, False),
         'Recover': ('Melee_1H_Attack_Chop', 0.72, 1.0, 3, False), 'Stun': ('Hit_A', 0, 1, 3, False), 'Death': ('Death_A', 0, 1, 6, False),
         'Block': ('Melee_Blocking', 0, 1, 3, True)}
SKEL = dict(MELEE, Idle=('Skeletons_Idle', 0, 1, 6, True), Move=('Skeletons_Walking', 0, 1, 8, True), Death=('Skeletons_Death', 0, 1, 6, False),
            Rise=('Skeletons_Awaken_Floor', 0, 1, 6, False), Taunt=('Skeletons_Taunt', 0, 1, 4, False))
SPECS = {
    'kk_skeleton_warrior': dict(model=(SK, 'characters/gltf/Skeleton_Warrior.glb'), right=(SK, 'assets/gltf/Skeleton_Blade.gltf'),
                                left=(SK, 'assets/gltf/Skeleton_Shield_Large_A.gltf'), anims=SKEL, eye=(120, 220, 255)),
    'kk_skeleton_rogue': dict(model=(SK, 'characters/gltf/Skeleton_Rogue.glb'), right=(SK, 'assets/gltf/Skeleton_Blade.gltf'), left=(SK, 'assets/gltf/Skeleton_Blade.gltf'),
                              anims=dict(SKEL, Windup=('Melee_Dualwield_Attack_Chop', 0.0, 0.4, 4, False), Strike=('Melee_Dualwield_Attack_Chop', 0.43, 0.66, 3, False),
                                         Recover=('Melee_Dualwield_Attack_Chop', 0.7, 1.0, 3, False), Dash=('Dodge_Forward', 0, 1, 5, False), Block=None), eye=(120, 220, 255)),
    'kk_skeleton_mage': dict(model=(SK, 'characters/gltf/Skeleton_Mage.glb'), right=(SK, 'assets/gltf/Skeleton_Staff.gltf'),
                             anims=dict(SKEL, Windup=('Ranged_Magic_Raise', 0.0, 1.0, 4, False), Strike=('Ranged_Magic_Shoot', 0.2, 0.6, 3, False),
                                        Recover=('Ranged_Magic_Shoot', 0.65, 1.0, 3, False), Summon=('Ranged_Magic_Summon', 0, 1, 6, False), Block=None), eye=(200, 120, 255)),
    'kk_skeleton_minion': dict(model=(SK, 'characters/gltf/Skeleton_Minion.glb'),
                               anims=dict(SKEL, Windup=('Melee_Unarmed_Attack_Punch_A', 0.0, 0.4, 3, False), Strike=('Melee_Unarmed_Attack_Punch_A', 0.42, 0.65, 3, False),
                                          Recover=('Melee_Unarmed_Attack_Punch_A', 0.7, 1.0, 3, False), Block=None), eye=(120, 220, 255)),
    'kk_ashen_knight': dict(model=(AD, 'Characters/gltf/Knight.glb'), right=(AD, 'Assets/gltf/sword_1handed.gltf'), left=(AD, 'Assets/gltf/shield_badge.gltf'),
                            anims=dict(MELEE, Idle=('Idle_B', 0, 1, 6, True), Windup=('Melee_1H_Attack_Slice_Diagonal', 0.0, 0.4, 4, False),
                                       Strike=('Melee_1H_Attack_Slice_Diagonal', 0.42, 0.65, 3, False), Recover=('Melee_1H_Attack_Slice_Diagonal', 0.68, 1.0, 3, False),
                                       Thrust=('Melee_1H_Attack_Stab', 0.1, 0.8, 5, False), Roll=('Dodge_Forward', 0, 1, 5, False),
                                       Jump=('Jump_Full_Short', 0.1, 0.9, 6, False)),
                            tint=(0.42, 0.42, 0.48), sat=0.25, val=0.75, eye=None),
    'kk_greatsword_knight': dict(model=(AD, 'Characters/gltf/Knight.glb'), right=(AD, 'Assets/gltf/sword_2handed.gltf'),
                                 anims=dict(MELEE, Windup=('Melee_2H_Attack_Chop', 0.0, 0.45, 4, False), Strike=('Melee_2H_Attack_Chop', 0.47, 0.66, 3, False),
                                            Recover=('Melee_2H_Attack_Chop', 0.7, 1.0, 3, False), Spin=('Melee_2H_Attack_Spin', 0, 1, 8, False), Block=None),
                                 tint=(0.36, 0.30, 0.30), sat=0.3, val=0.7, eye=None),
}
SPEC = SPECS[CHAR]
CW, CH = 112, 72
PXM = 17.5                     # KayKit characters are ~2.6 units tall -> ~45 px, like the hero
FEET_X = 0.40

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

for f in ('Rig_Medium_General.glb', 'Rig_Medium_MovementBasic.glb', 'Rig_Medium_MovementAdvanced.glb', 'Rig_Medium_CombatMelee.glb',
          'Rig_Medium_CombatRanged.glb', 'Rig_Medium_Special.glb'):
    bpy.ops.import_scene.gltf(filepath=os.path.join(AN, f))
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
actions = {a.name: a for a in bpy.data.actions}

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.join(*SPEC['model']))
new = [o for o in bpy.data.objects if o not in before]
rig = [o for o in new if o.type == 'ARMATURE'][0]
for o in new:
    if o.type == 'MESH' and o.name.startswith('Icosphere'): bpy.data.objects.remove(o, do_unlink=True)


def attach(path, bone):
    b4 = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(*path))
    objs = [o for o in bpy.data.objects if o not in b4]
    roots = [o for o in objs if o.parent is None]
    bpy.context.view_layer.update()
    pb = rig.pose.bones[bone]
    M = rig.matrix_world @ pb.matrix
    for r in roots:
        r.matrix_world = M @ r.matrix_world
        bpy.context.view_layer.update()
        mw = r.matrix_world.copy()
        r.parent = rig; r.parent_type = 'BONE'; r.parent_bone = bone
        bpy.context.view_layer.update()
        r.matrix_world = mw


if SPEC.get('right'): attach(SPEC['right'], 'handslot.r')
if SPEC.get('left'): attach(SPEC['left'], 'handslot.l')

if SPEC.get('tint'):
    for m in bpy.data.materials:
        if not m.use_nodes: continue
        b = m.node_tree.nodes.get('Principled BSDF')
        if not b or m.name.lower().startswith('glow'): continue
        hs = m.node_tree.nodes.new('ShaderNodeHueSaturation'); hs.inputs['Saturation'].default_value = SPEC['sat']; hs.inputs['Value'].default_value = SPEC['val']
        mix = m.node_tree.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs['Factor'].default_value = 1.0
        mix.inputs['B'].default_value = tuple(SPEC['tint']) + (1,)
        if b.inputs['Base Color'].links: m.node_tree.links.new(b.inputs['Base Color'].links[0].from_socket, hs.inputs['Color'])
        else: hs.inputs['Color'].default_value = b.inputs['Base Color'].default_value
        m.node_tree.links.new(hs.outputs['Color'], mix.inputs['A']); m.node_tree.links.new(mix.outputs['Result'], b.inputs['Base Color'])
        b.inputs['Metallic'].default_value = max(b.inputs['Metallic'].default_value, 0.35)

# eye marker (between the eye sockets) for the glowing-eye pixel, like the other enemies
eye_obj = bpy.data.objects.new('eye', None); sc.collection.objects.link(eye_obj)
hb = rig.data.bones['head']
eye_obj.location = (rig.matrix_world @ hb.head_local) + mathutils.Vector((0, -0.42, 0.42))
eye_obj.parent = rig; eye_obj.parent_type = 'BONE'; eye_obj.parent_bone = 'head'
bpy.context.view_layer.update()
eye_obj.matrix_world = mathutils.Matrix.Translation((rig.matrix_world @ hb.head_local) + mathutils.Vector((0, -0.42, 0.42)))

sc.render.engine = 'CYCLES'; sc.cycles.samples = int(os.environ.get('SAMPLES', '24')); sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
sc.render.film_transparent = True
sc.render.resolution_x, sc.render.resolution_y = CW * SHRINK, CH * SHRINK
sc.render.image_settings.color_mode = 'RGBA'
width_m = CW / PXM
cd = bpy.data.cameras.new('c'); cd.type = 'ORTHO'; cd.ortho_scale = width_m
cam = bpy.data.objects.new('c', cd); sc.collection.objects.link(cam)
shift = (0.5 - FEET_X) * width_m
cz = -2.0 / PXM + CH / PXM / 2.0
YAW = math.radians(float(os.environ.get('YAW', SPEC.get('yaw', 28))))   # swing the camera round the feet so the chibi body is not seen dead side-on
pos = mathutils.Matrix.Rotation(YAW, 3, 'Z') @ mathutils.Vector((-8.0, -shift, cz))
cam.location = (pos.x, pos.y, cz); cam.rotation_euler = (math.radians(90), 0, math.radians(-90) + YAW); sc.camera = cam


def light(name, loc, energy, color):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.color = color; d.size = 2.5
    o = bpy.data.objects.new(name, d); o.location = mathutils.Matrix.Rotation(YAW, 3, 'Z') @ mathutils.Vector(loc)
    o.rotation_euler = (math.radians(90), 0, (math.radians(90) if loc[0] > 0 else math.radians(-90)) + YAW)
    sc.collection.objects.link(o)


light('key', (-5, -2.5, 3.5), 2200, (1.0, 0.84, 0.68)); light('rim', (5, 2, 3.2), 2600, (0.5, 0.6, 1.0)); light('fill', (-5, 3, 1.0), 400, (0.85, 0.8, 1.0))
sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.04, 0.04, 0.06, 1)
sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.5

EYES = {}
rig.animation_data_create()
for anim, spec in SPEC['anims'].items():
    if spec is None or (ONLY and anim not in ONLY): continue
    action, t0, t1, count, loops = spec
    act = actions[action]
    rig.animation_data.action = act
    if hasattr(rig.animation_data, 'action_slot') and act.slots: rig.animation_data.action_slot = act.slots[0]
    f0, f1 = act.frame_range
    for i in range(count):
        t = t0 + (t1 - t0) * (i / count if loops else (i / (count - 1) if count > 1 else 0))
        sc.frame_set(round(f0 + (f1 - f0) * t))
        dg = bpy.context.evaluated_depsgraph_get(); dg.update()
        if os.environ.get('DEBUG'):
            for o in bpy.data.objects:
                if o.parent_type == 'BONE': print('DBG', anim, i, o.name, tuple(round(v, 2) for v in o.evaluated_get(dg).matrix_world.translation))
        c = world_to_camera_view(sc, cam, eye_obj.evaluated_get(dg).matrix_world.translation)
        EYES.setdefault(anim, []).append([round(c.x * CW, 1), round((1 - c.y) * CH, 1)])
        d = os.path.join(OUT, CHAR, anim); os.makedirs(d, exist_ok=True)
        sc.render.filepath = os.path.join(d, f'{i}.png')
        bpy.ops.render.render(write_still=True)
json.dump({'eyes': EYES, 'canvas': [CW, CH], 'eye_colour': SPEC.get('eye')}, open(os.path.join(OUT, CHAR, 'eyes.json'), 'w'))
print('kaykit done', CHAR)
