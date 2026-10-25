# Blender script: the five weapons in the hero's hands (a concept picture, not game frames). Based on skeleton_knight_render.py.
# Blender script: the skeleton knight. Takes Quaternius's free hooded Ranger outfit (CC-style QAL licence, see
# art/skeleton_knight/CREDITS.md), tints it dark, adds a skull face with red eyes and a sword, plays the
# Universal Animation Library actions on it and renders every game animation from the side.
#   blender -b -P skeleton_knight_render.py -- <UAL1_Standard.glb> <Male_Ranger.gltf> <out_dir> [anim_dir ...]
# Output: <out_dir>/<AnimDir>/<n>.png  (800x576, transparent; skeleton_knight_pixel.py shrinks them to game frames)
import bpy, math, os, sys, mathutils
CAM_Y = float(os.environ.get('CAM_Y', '0.40'))   # shifts the character left of centre (feet at x=40 of 100; 25 px per metre)
SCALE_NOTE = '25 px per metre'
args = sys.argv[sys.argv.index('--') + 1:]
ua, outfit, out = args[:3]
only = set(args[3:])  # weapon names; empty = all five
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
    mix.inputs['B'].default_value = (0.24, 0.22, 0.40, 1)
    hs = m.node_tree.nodes.new('ShaderNodeHueSaturation')
    hs.inputs['Saturation'].default_value = 0.5; hs.inputs['Value'].default_value = 0.95
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
    if kind != 'sphere':
        b = o.modifiers.new('bevel', 'BEVEL'); b.width = 0.006; b.segments = 2; b.limit_method = 'NONE'
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
        add('cube', (hx, hy - 0.67, hz), (0.010, 0.90, 0.045), STEEL),                   # blade
        add('cube', (hx, hy - 1.13, hz), (0.006, 0.03, 0.016), STEEL, rot=(0, 0, 0)),
        add('sphere', (hx, hy + 0.17, hz), (0.018, 0.018, 0.018), RUBY),                 # pommel gem
    ]
    for p in parts: attach(p, 'hand_r' if sign < 0 else 'hand_l')
    return parts

# (Turning the rig does nothing: the animation overrides it. The skeleton faces -Y, so the camera and lights
# sit on the -X side instead, which puts the face on the right of the image, the way the game expects.)
sc.render.engine = 'CYCLES'; sc.cycles.samples = 40; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
sc.render.film_transparent = True; sc.render.resolution_x = 800; sc.render.resolution_y = 576
sc.render.image_settings.color_mode = 'RGBA'
cam_d = bpy.data.cameras.new('c'); cam_d.type = 'ORTHO'; cam_d.ortho_scale = 100 / 25.0
cam = bpy.data.objects.new('c', cam_d); sc.collection.objects.link(cam)
cam.location = (-6, -CAM_Y, 1.36); cam.rotation_euler = (math.radians(90), 0, math.radians(-90)); sc.camera = cam
def light(name, loc, energy, color, size=0.6):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.color = color; d.size = size * 3
    o = bpy.data.objects.new(name, d); o.location = loc
    o.rotation_euler = (math.radians(90), 0, math.radians(90)) if loc[0] > 0 else (math.radians(90), 0, math.radians(-90))
    sc.collection.objects.link(o)
light('key', (-3.5, -1.5, 2.2), 1000, (1.0, 0.86, 0.72))
light('rim', (3.5, 1.2, 2.2), 1100, (0.5, 0.6, 1.0))
light('fill', (-3.5, 2, 0.6), 200, (0.9, 0.8, 1.0))
sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.04, 0.04, 0.06, 1)
sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6


# ---- the five weapons -------------------------------------------------------------------------------------
# Everything is built in the rest pose around the right hand (x = -0.76, y = 0.07, z = 1.44) and parented to the
# hand bone, so it follows every animation. Long axis = Y, the weapon points out of the fist toward -Y.
HX, HY, HZ = -0.76, 0.07, 1.44
RUST = make_mat('rust', (0.62, 0.50, 0.44), 0.45, 0.8)
RUST_EDGE = make_mat('rust_edge', (0.95, 0.88, 0.80), 0.3, 1.0)
WOOD = make_mat('wood', (0.45, 0.28, 0.16), 0.8)
GOLD = make_mat('gold', (0.45, 0.30, 0.08), 0.4, 1.0)
IRON = make_mat('iron', (0.50, 0.52, 0.62), 0.35, 1.0)
EMBER = make_mat('ember', (1.0, 0.35, 0.05), 0.3, 0, (1.0, 0.35, 0.04), 9.0)
STRING = make_mat('string', (0.85, 0.85, 0.75), 0.6)
GREEN = make_mat('green', (0.5, 1.0, 0.5), 0.3, 0, (0.55, 1.0, 0.45), 8.0)
CRYSTAL = make_mat('crystal', (0.55, 0.3, 1.0), 0.15, 0, (0.45, 0.15, 1.0), 2.2)
ASH = make_mat('ash', (0.12, 0.11, 0.12), 0.9)
RUNE = make_mat('rune', (1.0, 0.45, 0.1), 0.3, 0, (1.0, 0.45, 0.08), 14.0)


def cone(loc, radius, depth, mat, rot):
    bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=0, depth=depth, location=loc, vertices=16)
    o = bpy.context.object; o.rotation_euler = rot; o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = True
    return o


def strip(a, b, thick, mat):
    # a thin box from point a to point b in the Y-Z plane (x fixed), used for curved limbs
    ax, ay, az = a; bx, by, bz = b
    mid = ((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2)
    length = math.hypot(by - ay, bz - az)
    ang = math.atan2(by - ay, bz - az)
    o = add('cube', mid, (thick, thick, length), mat, rot=(-ang, 0, 0))
    return o


def sword():
    return [
        add('cube', (HX, HY, HZ), (0.030, 0.17, 0.030), GRIP),
        add('cube', (HX, HY - 0.19, HZ), (0.020, 0.030, 0.19), RUST_EDGE),
        add('cube', (HX, HY - 0.67, HZ), (0.016, 0.90, 0.075), RUST),
        add('cube', (HX, HY - 0.67, HZ + 0.040), (0.018, 0.88, 0.010), RUST_EDGE),   # the bright edge
        cone((HX, HY - 1.17, HZ), 0.027, 0.12, RUST_EDGE, (math.radians(90), 0, 0)),
        add('sphere', (HX, HY + 0.17, HZ), (0.020, 0.020, 0.020), RUBY),
    ]


def spear():
    return [
        add('cube', (HX, HY - 0.45, HZ), (0.038, 2.0, 0.038), WOOD),                  # shaft (hand a third of the way up)
        add('cube', (HX, HY - 1.40, HZ), (0.034, 0.10, 0.034), GOLD),                 # socket
        cone((HX, HY - 1.63, HZ), 0.075, 0.42, RUST_EDGE, (math.radians(90), 0, 0)),  # leaf head
        add('sphere', (HX, HY - 1.50, HZ), (0.030, 0.030, 0.030), EMBER),             # ember in the socket
        add('cube', (HX, HY - 1.38, HZ - 0.045), (0.008, 0.06, 0.08), EMBER, rot=(0, 0, 0)),
        add('cube', (HX, HY + 0.55, HZ), (0.032, 0.05, 0.032), GOLD),                 # butt cap
    ]


def bow():
    parts = []
    n = 10
    pts = []
    for i in range(n + 1):
        t = -1 + 2 * i / n
        pts.append((HX, HY - 0.26 * (1 - t * t) - 0.02, HZ + 0.62 * t))
    for a, b in zip(pts, pts[1:]):
        parts.append(strip(a, b, 0.032, WOOD))
    parts.append(strip(pts[0], pts[-1], 0.006, STRING))
    parts.append(add('cube', (HX, HY - 0.28, HZ), (0.040, 0.05, 0.16), GOLD))        # grip wrap
    parts.append(add('sphere', (HX, pts[0][1], pts[0][2]), (0.02, 0.02, 0.02), GOLD))
    parts.append(add('sphere', (HX, pts[-1][1], pts[-1][2]), (0.02, 0.02, 0.02), GOLD))
    # a nocked arrow
    parts.append(add('cube', (HX, HY - 0.22, HZ), (0.008, 0.80, 0.008), WOOD))
    parts.append(cone((HX, HY - 0.66, HZ), 0.020, 0.10, GREEN, (math.radians(90), 0, 0)))
    return parts


def wand():
    parts = [
        add('cube', (HX, HY - 0.18, HZ), (0.028, 0.62, 0.028), ASH),
        add('cube', (HX, HY + 0.07, HZ), (0.036, 0.16, 0.036), GRIP),
        add('cube', (HX, HY - 0.47, HZ), (0.040, 0.06, 0.040), GOLD),
    ]
    for dz in (-0.045, 0.045):                                                       # claws holding the crystal
        parts.append(add('cube', (HX, HY - 0.58, HZ + dz), (0.012, 0.14, 0.012), GOLD, rot=(math.radians(dz * 200), 0, 0)))
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1, subdivisions=1, location=(HX, HY - 0.62, HZ))
    gem = bpy.context.object; gem.scale = (0.045, 0.085, 0.045); gem.data.materials.append(CRYSTAL)
    parts.append(gem)
    return parts


def gauntlet():
    parts = []
    for sign, bone in ((-1, 'hand_r'), (1, 'hand_l')):
        x = HX * -sign * -1 if False else (HX if sign < 0 else -HX)
        out = -1 if sign < 0 else 1                       # which way the fingers point (away from the body)
        parts.append((bone, add('cube', (x + out * 0.02, HY, HZ), (0.22, 0.17, 0.17), IRON)))            # fist block
        parts.append((bone, add('cube', (x - out * 0.14, HY, HZ), (0.20, 0.15, 0.15), IRON)))            # vambrace
        parts.append((bone, add('cube', (x + out * 0.13, HY, HZ), (0.04, 0.18, 0.18), GOLD)))            # knuckle plate
        for dy in (-0.06, 0.0, 0.06):
            parts.append((bone, cone((x + out * 0.17, HY + dy, HZ + 0.02), 0.022, 0.07, RUST_EDGE, (0, math.radians(90 * out), 0))))
        parts.append((bone, add('cube', (x - out * 0.02, HY, HZ + 0.09), (0.18, 0.02, 0.01), RUNE)))       # glowing runes
        parts.append((bone, add('cube', (x - out * 0.14, HY, HZ + 0.078), (0.14, 0.02, 0.01), RUNE)))
    return parts


# Extra turn of the whole weapon about the hand, in degrees (x, y, z), so it points the way the pose wants it to.
GRIP_TURN = {
    'bow': (0, 90, -90),      # bow upright, arrow forward
    'wand': (180, 0, -90),    # held up and forward in the casting hand (the left one)
}
if os.environ.get('TURN'): GRIP_TURN[os.environ['TURN_WEAPON']] = tuple(float(v) for v in os.environ['TURN'].split(','))
if os.environ.get('LOWRES'): sc.render.resolution_percentage = 40; sc.cycles.samples = 10

WEAPONS = {
    'sword':    (sword,    'hand_r', [('idle', 'Sword_Idle', 0.0), ('attack', 'Sword_Attack', 0.2)]),
    'spear':    (spear,    'hand_r', [('idle', 'Sword_Idle', 0.0), ('attack', 'Sword_Attack', 0.3)]),
    'bow':      (bow,      'hand_r', [('idle', 'Pistol_Idle_Loop', 0.0), ('attack', 'Pistol_Aim_Neutral', 0.9)]),
    'wand':     (wand,     'hand_l', [('idle', 'Spell_Simple_Idle_Loop', 0.0), ('attack', 'Spell_Simple_Shoot', 0.6)]),
    'gauntlet': (gauntlet, None,     [('idle', 'Idle_Loop', 0.0), ('attack', 'Punch_Jab', 0.5)]),
}
build_skull()
for name, (builder, bone, poses) in WEAPONS.items():
    if only and name not in only: continue
    # parent in the rest pose: parenting to a bone keeps wherever the weapon is relative to the bone's current pose
    rig.animation_data_create(); rig.animation_data.action = None
    rig.data.pose_position = 'REST'; sc.frame_set(1); bpy.context.view_layer.update()
    HX = 0.76 if bone == 'hand_l' else -0.76          # the casting hand is the left one
    made = builder()
    pivot = bpy.data.objects.new('pivot', None); sc.collection.objects.link(pivot)
    pivot.location = (HX, HY, HZ)
    for p in made:
        if isinstance(p, tuple): attach(p[1], p[0])
        else: attach(p, bone)
    turn = GRIP_TURN.get(name)
    if turn:
        # re-parent the parts to a pivot at the hand, itself on the hand bone, then turn the pivot
        for p in made:
            o = p[1] if isinstance(p, tuple) else p
            o.parent = None; o.matrix_world = o.matrix_world  # keep the rest-pose spot
        bpy.ops.object.select_all(action='DESELECT'); pivot.select_set(True); rig.select_set(True)
        bpy.context.view_layer.objects.active = rig; rig.data.bones.active = rig.data.bones[bone or 'hand_r']
        bpy.ops.object.parent_set(type='BONE')
        for p in made:
            o = p[1] if isinstance(p, tuple) else p
            bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); pivot.select_set(True)
            bpy.context.view_layer.objects.active = pivot
            bpy.ops.object.parent_set(type='OBJECT', keep_transform=True)
        pivot.rotation_mode = 'XYZ'
        pivot.rotation_euler = tuple(math.radians(v) for v in turn)
    rig.data.pose_position = 'POSE'
    for pose, action, t in poses:
        act = anim_actions[action]
        rig.animation_data_create(); rig.animation_data.action = act
        if hasattr(rig.animation_data, 'action_slot') and act.slots: rig.animation_data.action_slot = act.slots[0]
        f0, f1 = act.frame_range
        if pose == 'attack' and os.environ.get('ATTACK_T'): t = float(os.environ['ATTACK_T'])
        sc.frame_set(round(f0 + (f1 - f0) * t))
        os.makedirs(out, exist_ok=True)
        sc.render.filepath = os.path.join(out, f'{name}_{pose}{os.environ.get("SUFFIX", "")}.png')
        bpy.ops.render.render(write_still=True)
    for p in made:
        o = p[1] if isinstance(p, tuple) else p
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.objects.remove(pivot, do_unlink=True)
    print('done', name)
