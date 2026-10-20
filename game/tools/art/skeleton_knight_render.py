# Blender script: the skeleton knight. Takes Quaternius's free hooded Ranger outfit (CC-style QAL licence, see
# art/skeleton_knight/CREDITS.md), tints it dark, adds a skull face with red eyes and a sword, plays the
# Universal Animation Library actions on it and renders every game animation from the side.
#   blender -b -P skeleton_knight_render.py -- <UAL1_Standard.glb> <Male_Ranger.gltf> <out_dir> [anim_dir ...]
# Output: <out_dir>/<AnimDir>/<n>.png  (800x512, transparent; skeleton_knight_pixel.py shrinks them to game frames)
import bpy, math, os, sys, mathutils
CAM_Y = float(os.environ.get('CAM_Y', '0.4545'))   # shifts the character left of centre (feet at x=40 of 100)
SCALE_NOTE = '22 px per metre'
args = sys.argv[sys.argv.index('--') + 1:]
ua, outfit, out = args[:3]
only = set(args[3:])
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=ua)
mannequin = [o for o in bpy.data.objects]
bpy.ops.import_scene.gltf(filepath=outfit)
new = [o for o in bpy.data.objects if o not in mannequin]
for o in [o for o in mannequin if o.type == 'MESH']:
    bpy.data.objects.remove(o, do_unlink=True)
rig = [o for o in new if o.type == 'ARMATURE'][0]
anim_actions = {a.name: a for a in bpy.data.actions}
# darker, moodier colours: tint every base colour toward near-black plum
for m in bpy.data.materials:
    if not m.use_nodes: continue
    b = m.node_tree.nodes.get('Principled BSDF')
    if not b: continue
    tex = [n for n in m.node_tree.nodes if n.type == 'TEX_IMAGE']
    mix = m.node_tree.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
    mix.inputs['Factor'].default_value = 1.0
    mix.inputs['B'].default_value = (0.30, 0.20, 0.46, 1)
    hs = m.node_tree.nodes.new('ShaderNodeHueSaturation')
    hs.inputs['Saturation'].default_value = 0.4; hs.inputs['Value'].default_value = 0.95
    if b.inputs['Base Color'].links:
        src = b.inputs['Base Color'].links[0].from_socket
        m.node_tree.links.new(src, hs.inputs['Color'])
    else:
        hs.inputs['Color'].default_value = b.inputs['Base Color'].default_value
    m.node_tree.links.new(hs.outputs['Color'], mix.inputs['A'])
    m.node_tree.links.new(mix.outputs['Result'], b.inputs['Base Color'])

def make_mat(name, color, rough=0.5, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = color + (1,)
    b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = emit + (1,); b.inputs['Emission Strength'].default_value = strength
    return m

def attach(obj, bone):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True); rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    rig.data.bones.active = rig.data.bones[bone]
    bpy.ops.object.parent_set(type='BONE')

def add(kind, loc, scale, mat, rot=(0, 0, 0), **kw):
    if kind == 'sphere': bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=loc, segments=24, ring_count=16)
    else: bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object; o.scale = scale; o.rotation_euler = rot
    o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = (kind == 'sphere')
    return o

BONE = make_mat('bone', (0.80, 0.77, 0.70), 0.7)
SOCKET = make_mat('socket', (0.01, 0.005, 0.02), 0.9)
EYE = make_mat('eye', (1, 0.1, 0.05), 0.3, 0, (1.0, 0.08, 0.04), 40.0)
STEEL = make_mat('steel', (0.55, 0.56, 0.62), 0.3, 1.0)
GRIP = make_mat('grip', (0.05, 0.03, 0.04), 0.8)
RUBY = make_mat('ruby', (0.8, 0.05, 0.1), 0.2, 0, (1.0, 0.05, 0.1), 2.0)

def build_skull():
    parts = [
        add('sphere', (0, -0.03, 1.705), (0.088, 0.098, 0.100), BONE),                 # cranium
        add('cube',   (0, -0.085, 1.625), (0.060, 0.060, 0.052), BONE),                 # jaw
        add('cube',   (0, -0.117, 1.600), (0.050, 0.010, 0.012), SOCKET),               # teeth gap
        add('sphere', (-0.036, -0.108, 1.705), (0.027, 0.020, 0.030), SOCKET),          # eye sockets
        add('sphere', (0.036, -0.108, 1.705), (0.027, 0.020, 0.030), SOCKET),
        add('sphere', (-0.036, -0.118, 1.705), (0.013, 0.010, 0.013), EYE),             # glowing eyes
        add('sphere', (0.036, -0.118, 1.705), (0.013, 0.010, 0.013), EYE),
        add('cube',   (0, -0.118, 1.665), (0.011, 0.008, 0.016), SOCKET),               # nose hole
    ]
    for p in parts: attach(p, 'Head')

def build_sword(sign=-1):
    # held in hand_r (x < 0 in the rest pose); the blade points forward (-Y) out of the fist
    hx, hy, hz = 0.76 * sign, 0.07, 1.44
    parts = [
        add('cube', (hx, hy, hz), (0.030, 0.17, 0.030), GRIP),                           # grip
        add('cube', (hx, hy - 0.19, hz), (0.020, 0.030, 0.19), STEEL),                   # crossguard
        add('cube', (hx, hy - 0.54, hz), (0.010, 0.60, 0.045), STEEL),                   # blade
        add('cube', (hx, hy - 0.90, hz), (0.006, 0.03, 0.016), STEEL, rot=(0, 0, 0)),
        add('sphere', (hx, hy + 0.17, hz), (0.018, 0.018, 0.018), RUBY),                 # pommel gem
    ]
    for p in parts: attach(p, 'hand_r' if sign < 0 else 'hand_l')
    return parts

build_skull()
SWORD = build_sword()   # [grip, crossguard, blade, blade tip, pommel]
rig.rotation_euler[2] = math.radians(float(os.environ.get('FACE_ROT', '0')))
sc.render.engine = 'CYCLES'; sc.cycles.samples = 40; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
sc.render.film_transparent = True; sc.render.resolution_x = 800; sc.render.resolution_y = 512
sc.render.image_settings.color_mode = 'RGBA'
cam_d = bpy.data.cameras.new('c'); cam_d.type = 'ORTHO'; cam_d.ortho_scale = 100 / 22.0
cam = bpy.data.objects.new('c', cam_d); sc.collection.objects.link(cam)
cam.location = (6, CAM_Y, 1.364); cam.rotation_euler = (math.radians(90), 0, math.radians(90)); sc.camera = cam
def light(name, loc, energy, color, size=0.6):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.color = color; d.size = size * 3
    o = bpy.data.objects.new(name, d); o.location = loc
    o.rotation_euler = (math.radians(90), 0, math.radians(90)) if loc[0] > 0 else (math.radians(90), 0, math.radians(-90))
    sc.collection.objects.link(o)
light('key', (3.5, 1.5, 2.2), 1000, (1.0, 0.72, 0.5))
light('rim', (-3.5, -1.2, 2.2), 1100, (0.5, 0.6, 1.0))
light('fill', (3.5, -2, 0.6), 200, (0.9, 0.8, 1.0))
sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.04, 0.04, 0.06, 1)
sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6

# game animation -> (library action, frames wanted, loops?, reversed?)
JOBS = {
    'Idle':    ('Sword_Idle', 8, True, False),
    'Run':     ('Jog_Fwd_Loop', 10, True, False),
    'Jump':    ('Jump_Start', 3, False, False),
    'Fall':    ('Jump_Loop', 4, True, False),
    'Roll':    ('Roll', 9, False, False),
    'Hurt':    ('Hit_Chest', 3, False, False),
    'Death':   ('Death01', 10, False, False),
    'Attack1': ('Sword_Attack', 6, False, False),
    'Attack2': ('Sword_Attack', 6, False, True),     # the same swing played backwards reads as a backhand
    'Attack3': ('Sword_Attack', 8, False, False),
}
os.makedirs(out, exist_ok=True)
rig.animation_data_create()
import json
from bpy_extras.object_utils import world_to_camera_view
BLADES = {}


def blade_pixels():
    # guard and tip of the sword in frame pixels (100 x 64, y down), for effects that follow the blade
    dg = bpy.context.evaluated_depsgraph_get(); dg.update()
    guard = SWORD[1].evaluated_get(dg).matrix_world.translation
    blade = SWORD[2].evaluated_get(dg)
    ends = [blade.matrix_world @ mathutils.Vector((0, y, 0)) for y in (-0.5, 0.5)]
    tip = max(ends, key=lambda e: (e - guard).length)
    def px(v):
        c = world_to_camera_view(sc, cam, v)
        return [round(c.x * 100, 1), round((1 - c.y) * 64, 1)]
    return px(guard) + px(tip)

for game_anim, (action, count, loops, backwards) in JOBS.items():
    if only and game_anim not in only: continue
    act = anim_actions[action]
    rig.animation_data.action = act
    if hasattr(rig.animation_data, 'action_slot') and act.slots:
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = act.frame_range
    d = os.path.join(out, game_anim); os.makedirs(d, exist_ok=True)
    for i in range(count):
        t = i / count if loops else (i / (count - 1) if count > 1 else 0)
        if backwards: t = 1 - t
        sc.frame_set(round(f0 + (f1 - f0) * t))
        BLADES.setdefault(game_anim, []).append(blade_pixels())
        if os.environ.get('BLADE_ONLY'): continue
        sc.render.filepath = os.path.join(d, f'{i}.png')
        bpy.ops.render.render(write_still=True)
    print('done', game_anim, action, count)

json.dump(BLADES, open(os.path.join(out, 'blade.json'), 'w'))
