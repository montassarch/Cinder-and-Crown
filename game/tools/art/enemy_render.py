# Blender script: renders one enemy's sprite animations from the side (the same pipeline as the skeleton knight).
#   blender -b -P enemy_render.py -- <enemy_id> <out_dir> <packs_dir> [anim ...]
# Humanoids and creatures borrow Quaternius's free Universal Animation Library actions (QAL licence, see
# art/enemies/CREDITS.md); the Cinder Bat and Ember Wisp are built here from simple shapes.
# Output: <out_dir>/<enemy_id>/<Anim>/<n>.png (transparent, 8x the game size) and eyes.json (eye position per frame).
import bpy, math, os, sys, json, random, mathutils
from bpy_extras.object_utils import world_to_camera_view

argv = sys.argv[sys.argv.index('--') + 1:]
ENEMY, OUT, PACKS = argv[0], argv[1], argv[2]
ONLY = set(argv[3:])
UAL = os.path.join(PACKS, 'Universal_Animation_Library/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb')
OUTFITS = os.path.join(PACKS, 'Modular_Character_Outfits_-_Fantasy/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits')
BEST = os.path.join(PACKS, 'bestiary/Bestiary - Dungeon Monsters Kit[Standard]/Exports/GLB (Godot-Unreal)')
BASES = os.path.join(PACKS, 'Universal_Base_Characters/Universal Base Characters[Standard]/Base Characters/Godot - UE')
SHRINK = 8

# animation -> (library action, t0, t1, frame count, loops).  windup/strike/recover split one attack swing.
HUMAN_ANIMS = {
    'Idle': ('Idle_Loop', 0, 1, 6, True), 'Move': ('Walk_Loop', 0, 1, 8, True),
    'Windup': ('Sword_Attack', 0.0, 0.38, 4, False), 'Strike': ('Sword_Attack', 0.42, 0.72, 3, False),
    'Recover': ('Sword_Attack', 0.78, 1.0, 3, False), 'Stun': ('Hit_Chest', 0.0, 1.0, 3, False),
    'Death': ('Death01', 0.0, 1.0, 6, False), 'Dash': ('Sprint_Loop', 0, 1, 6, True),
}

# bosses also cast: summons and floor hazards play these instead of the weapon swing
BOSS_ANIMS = dict(HUMAN_ANIMS, CastWindup=('Spell_Simple_Enter', 0.0, 1.0, 4, False), CastStrike=('Spell_Simple_Shoot', 0.2, 0.7, 3, False),
                  CastRecover=('Spell_Simple_Exit', 0.0, 1.0, 3, False))

SPECS = {
    # canvas px, px per metre, eye colour, base model
    'shambler': dict(base='outfit:Male_Peasant', canvas=(96, 64), pxm=23, eye=(255, 90, 40), mul=(0.34, 0.5, 0.34), sat=0.5, val=0.8, props=['zombie_head'], anims=dict(HUMAN_ANIMS, Move=('Walk_Loop', 0, 1, 8, True))),
    'crown_guard': dict(base='outfit:Male_Peasant', canvas=(96, 64), pxm=25, eye=(255, 200, 70), mul=(0.4, 0.48, 0.7), sat=0.5, val=0.85, props=['helm', 'breastplate', 'pauldrons', 'sword'], anims=HUMAN_ANIMS),
    'penitent': dict(base='outfit:Male_Ranger', canvas=(112, 64), pxm=25, eye=(255, 245, 220), mul=(0.85, 0.82, 0.8), sat=0.25, val=1.05, props=['shield', 'spear'], anims=dict(HUMAN_ANIMS, Windup=('Punch_Jab', 0.0, 0.35, 4, False), Strike=('Punch_Jab', 0.4, 0.65, 3, False), Recover=('Punch_Jab', 0.72, 1.0, 3, False))),
    'powder_pilgrim': dict(base='creature:Puglin', canvas=(80, 48), pxm=34, eye=(255, 230, 90), mul=(0.85, 0.7, 0.6), sat=0.9, val=0.9, props=['keg'], anims=dict(HUMAN_ANIMS, Move=('Jog_Fwd_Loop', 0, 1, 8, True), Windup=('Spell_Simple_Enter', 0.0, 1.0, 4, False), Strike=('Spell_Simple_Shoot', 0.3, 0.6, 3, False), Recover=('Spell_Simple_Exit', 0.0, 1.0, 3, False))),
    'crown_brute': dict(base='creature:Imp', canvas=(120, 80), pxm=34, eye=(255, 230, 120), mul=(0.6, 0.42, 0.45), sat=0.8, val=0.75, props=['crown'], anims=HUMAN_ANIMS),
    'ember_wisp': dict(base='proc:wisp', canvas=(48, 48), pxm=50, eye=(40, 20, 10), anims={}, light=0.0),
    'cinder_bat': dict(base='proc:bat', canvas=(64, 48), pxm=70, eye=(255, 230, 120), anims={}, yaw=55, light=0.35),
    # later worlds
    'frost_ghoul': dict(base='outfit:Male_Peasant', canvas=(96, 64), pxm=23, eye=(140, 230, 255), mul=(0.42, 0.58, 0.85), sat=0.4, val=0.85, props=['frost_head', 'ice_spikes'], anims=dict(HUMAN_ANIMS, Windup=('Punch_Cross', 0.0, 0.4, 4, False), Strike=('Punch_Cross', 0.42, 0.66, 3, False), Recover=('Punch_Cross', 0.7, 1.0, 3, False))),
    'rime_wisp': dict(base='proc:wisp', canvas=(48, 48), pxm=50, eye=(20, 30, 60), anims={}, light=0.0, core=(225, 245, 255), glow=(90, 190, 255)),
    'forge_brute': dict(base='creature:Imp', canvas=(120, 80), pxm=30, eye=(255, 170, 40), mul=(0.75, 0.32, 0.25), sat=0.9, val=0.7, props=['horns', 'hammer'], anims=HUMAN_ANIMS),
    'magma_bat': dict(base='proc:bat', canvas=(64, 48), pxm=60, eye=(255, 240, 150), anims={}, yaw=55, light=0.35, body=(60, 20, 14), wing=(220, 90, 20), wing_glow=3.0),
    'storm_knight': dict(base='outfit:Male_Ranger', canvas=(96, 64), pxm=24, eye=(150, 210, 255), mul=(0.38, 0.42, 0.72), sat=0.5, val=0.8, props=['storm_helm', 'breastplate', 'pauldrons', 'storm_sword'], anims=HUMAN_ANIMS),
    # bosses (rendered big: more pixels per metre on a bigger canvas)
    'hollow_bishop': dict(base='outfit:Male_Ranger', canvas=(176, 112), pxm=44, eye=(255, 215, 100), mul=(0.62, 0.32, 0.85), sat=0.9, val=0.85, props=['mitre', 'crozier'], anims=BOSS_ANIMS),
    'rime_colossus': dict(base='creature:Imp', canvas=(240, 160), pxm=66, eye=(150, 235, 255), mul=(0.5, 0.68, 1.0), sat=0.5, val=0.95, props=['ice_mantle'], anims=BOSS_ANIMS),
    'forge_tyrant': dict(base='creature:Imp', canvas=(240, 160), pxm=64, eye=(255, 190, 50), mul=(0.85, 0.32, 0.2), sat=0.9, val=0.6, props=['horns', 'molten_plate'], anims=BOSS_ANIMS),
    'storm_king': dict(base='outfit:Male_Ranger', canvas=(176, 112), pxm=42, eye=(170, 225, 255), mul=(0.25, 0.3, 0.55), sat=0.7, val=0.7, props=['king_crown', 'breastplate', 'pauldrons', 'storm_sword'], anims=BOSS_ANIMS),
    'storm_wisp': dict(base='proc:wisp', canvas=(48, 48), pxm=50, eye=(255, 250, 200), anims={}, light=0.0, core=(170, 190, 255), glow=(50, 80, 255)),
}
SPEC = SPECS[ENEMY]
CW, CH = SPEC['canvas']
PXM = SPEC['pxm']
FEET_X = 0.40                      # feet at 40% across the frame, like the hero

# ------------------------------------------------------------------ helpers

bpy.ops.wm.read_factory_settings(use_empty=True)   # first, or it would wipe the materials made below

def mat(name, rgb, rough=0.6, metal=0.0, emit=None, strength=0.0):
    if name.startswith('P_') and not emit: rgb = tuple(int(v * 0.32) for v in rgb)   # the lights are strong; props start dark
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = tuple(v / 255.0 for v in rgb) + (1,)
    b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = tuple(v / 255.0 for v in emit) + (1,)
        b.inputs['Emission Strength'].default_value = strength
    return m

def add(kind, loc, scale, m, rot=(0, 0, 0), **kw):
    if kind == 'sphere': bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=loc, segments=20, ring_count=12)
    elif kind == 'cyl': bpy.ops.mesh.primitive_cylinder_add(radius=1, depth=1, location=loc, vertices=20)
    elif kind == 'cone': bpy.ops.mesh.primitive_cone_add(radius1=1, radius2=0, depth=1, location=loc, vertices=16)
    elif kind == 'torus': bpy.ops.mesh.primitive_torus_add(major_radius=1, minor_radius=kw.get('minor', 0.12), location=loc)
    else: bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object; o.scale = scale; o.rotation_euler = rot
    o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = kind in ('sphere', 'cyl', 'cone', 'torus')
    return o

def attach(obj, rig, bone):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True); rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    rig.data.bones.active = rig.data.bones[bone]
    bpy.ops.object.parent_set(type='BONE')

def tint_materials():
    for m in bpy.data.materials:
        if not m.use_nodes or m.name.startswith(('P_',)): continue
        b = m.node_tree.nodes.get('Principled BSDF')
        if not b: continue
        mix = m.node_tree.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
        mix.inputs['Factor'].default_value = 1.0
        mix.inputs['B'].default_value = tuple(SPEC['mul']) + (1,)
        hs = m.node_tree.nodes.new('ShaderNodeHueSaturation')
        hs.inputs['Saturation'].default_value = SPEC['sat']; hs.inputs['Value'].default_value = SPEC['val']
        if b.inputs['Base Color'].links: m.node_tree.links.new(b.inputs['Base Color'].links[0].from_socket, hs.inputs['Color'])
        else: hs.inputs['Color'].default_value = b.inputs['Base Color'].default_value
        m.node_tree.links.new(hs.outputs['Color'], mix.inputs['A'])
        m.node_tree.links.new(mix.outputs['Result'], b.inputs['Base Color'])

STEEL = mat('P_steel', (150, 155, 175), 0.3, 1.0); IRON = mat('P_iron', (40, 40, 52), 0.5, 0.9)
GOLD = mat('P_gold', (220, 170, 60), 0.3, 1.0); WOOD = mat('P_wood', (110, 70, 40), 0.8)
BONE = mat('P_bone', (225, 220, 205), 0.7); DARK = mat('P_dark', (12, 8, 16), 0.9)
CLOTH = mat('P_cloth', (120, 30, 40), 0.8)
SKIN = mat('P_skin', (120, 160, 100), 0.8)
FUSE = mat('P_fuse', (255, 150, 40), 0.4, 0, (255, 120, 20), 20.0)
ICE = mat('P_ice', (170, 220, 255), 0.15, 0, (120, 200, 255), 1.5)
FROST_SKIN = mat('P_fskin', (150, 175, 210), 0.7)
HORN = mat('P_horn', (60, 40, 30), 0.6)
EMBER_GLOW = mat('P_eglow', (255, 120, 30), 0.4, 0, (255, 110, 20), 6.0)
STORM = mat('P_storm', (120, 170, 255), 0.3, 0, (110, 160, 255), 5.0)

def build_props(rig, props):
    for p in props:
        if p == 'zombie_head':
            attach(add('sphere', (0, -0.02, 1.70), (0.10, 0.105, 0.12), SKIN), rig, 'Head')
            attach(add('cube', (0, -0.085, 1.64), (0.07, 0.05, 0.05), SKIN), rig, 'Head')               # slack jaw
            attach(add('sphere', (0, -0.095, 1.705), (0.075, 0.03, 0.03), DARK), rig, 'Head')           # sunken eyes
        elif p == 'helm':
            attach(add('sphere', (0, -0.02, 1.70), (0.125, 0.13, 0.13), STEEL), rig, 'Head')
            attach(add('cube', (0, -0.14, 1.69), (0.10, 0.02, 0.025), DARK), rig, 'Head')          # visor slit
            attach(add('cube', (0, -0.02, 1.84), (0.02, 0.16, 0.07), GOLD), rig, 'Head')           # crest
        elif p == 'breastplate':
            attach(add('cube', (0, -0.02, 1.36), (0.34, 0.22, 0.34), STEEL), rig, 'spine_03')
            attach(add('cube', (0, -0.13, 1.38), (0.06, 0.02, 0.30), GOLD), rig, 'spine_03')
        elif p == 'pauldrons':
            for sx in (-1, 1):
                attach(add('sphere', (0.23 * sx, 0.0, 1.50), (0.13, 0.14, 0.10), STEEL), rig, 'upperarm_r' if sx < 0 else 'upperarm_l')
        elif p == 'sword':
            hx, hy, hz = -0.76, 0.07, 1.44
            for part in (add('cube', (hx, hy, hz), (0.03, 0.17, 0.03), DARK), add('cube', (hx, hy - 0.19, hz), (0.02, 0.03, 0.19), GOLD),
                         add('cube', (hx, hy - 0.62, hz), (0.045, 0.80, 0.045), STEEL)):
                attach(part, rig, 'hand_r')
        elif p == 'spear':
            hx, hy, hz = -0.76, 0.07, 1.44
            attach(add('cyl', (hx, hy - 0.30, hz), (0.018, 0.018, 1.7), WOOD, rot=(math.radians(90), 0, 0)), rig, 'hand_r')
            attach(add('cone', (hx, hy - 1.25, hz), (0.045, 0.045, 0.28), STEEL, rot=(math.radians(90), 0, 0)), rig, 'hand_r')
        elif p == 'shield':
            hx, hy, hz = 0.76, 0.07, 1.44
            attach(add('cube', (hx, hy - 0.22, hz - 0.12), (0.035, 0.46, 0.95), IRON), rig, 'hand_l')
            attach(add('cube', (hx + 0.02, hy - 0.22, hz - 0.12), (0.01, 0.40, 0.08), BONE), rig, 'hand_l')
            attach(add('cube', (hx + 0.02, hy - 0.22, hz + 0.08), (0.01, 0.08, 0.50), BONE), rig, 'hand_l')
        elif p == 'keg':
            sb = 'spine_02' if 'spine_02' in rig.data.bones else 'spine_03'
            h = rig.data.bones[sb].head_local
            cx, cy, cz = h[0], h[1] + 0.20, h[2] + 0.12
            attach(add('cyl', (cx, cy, cz), (0.13, 0.13, 0.28), WOOD), rig, sb)
            for dz in (-0.08, 0.08):
                attach(add('torus', (cx, cy, cz + dz), (0.135, 0.135, 0.2), IRON, minor=0.015), rig, sb)
            attach(add('sphere', (cx, cy, cz + 0.17), (0.03, 0.03, 0.03), FUSE), rig, sb)
        elif p == 'frost_head':
            attach(add('sphere', (0, -0.02, 1.70), (0.10, 0.105, 0.12), FROST_SKIN), rig, 'Head')
            attach(add('cube', (0, -0.085, 1.63), (0.07, 0.05, 0.06), FROST_SKIN), rig, 'Head')
            attach(add('sphere', (0, -0.095, 1.705), (0.075, 0.03, 0.03), DARK), rig, 'Head')
            for k, dx in enumerate((-0.06, 0.0, 0.06)):                                         # a crown of ice shards
                attach(add('cone', (dx, -0.01, 1.84 + (0.03 if k == 1 else 0)), (0.03, 0.03, 0.12 + (0.05 if k == 1 else 0)), ICE), rig, 'Head')
        elif p == 'ice_spikes':
            for sx in (-1, 1):
                for k in range(3):
                    attach(add('cone', (0.16 * sx, 0.06 + k * 0.03, 1.48 + k * 0.04), (0.035, 0.035, 0.16), ICE, rot=(math.radians(-25), math.radians(30 * sx), 0)), rig, 'spine_03')
            for k in range(4):
                attach(add('cone', (0.0, 0.14, 1.2 + k * 0.1), (0.03, 0.03, 0.13), ICE, rot=(math.radians(-60), 0, 0)), rig, 'spine_03')
        elif p == 'horns':
            hb = rig.data.bones['Head'].tail_local
            for sx in (-1, 1):
                attach(add('cone', (hb[0] + 0.09 * sx, hb[1], hb[2] + 0.08), (0.045, 0.045, 0.2), HORN, rot=(0, math.radians(-35 * sx), 0)), rig, 'Head')
        elif p == 'hammer':
            hand = rig.data.bones['hand_r'].head_local
            hx, hy, hz = hand[0], hand[1], hand[2]
            # held by the end of the haft with the head trailing behind the fist, so it never hides the face
            attach(add('cyl', (hx, hy + 0.25, hz), (0.03, 0.03, 0.75), WOOD, rot=(math.radians(90), 0, 0)), rig, 'hand_r')
            attach(add('cube', (hx, hy + 0.62, hz), (0.22, 0.16, 0.30), IRON), rig, 'hand_r')
            attach(add('cube', (hx, hy + 0.62, hz + 0.155), (0.23, 0.17, 0.02), EMBER_GLOW), rig, 'hand_r')
        elif p == 'storm_helm':
            attach(add('sphere', (0, -0.02, 1.70), (0.125, 0.13, 0.13), STEEL), rig, 'Head')
            attach(add('cube', (0, -0.14, 1.69), (0.10, 0.02, 0.025), STORM), rig, 'Head')
            for sx in (-1, 1):
                attach(add('cone', (0.11 * sx, 0.0, 1.80), (0.03, 0.03, 0.14), GOLD, rot=(0, math.radians(-40 * sx), 0)), rig, 'Head')
        elif p == 'storm_sword':
            hx, hy, hz = -0.76, 0.07, 1.44
            for part in (add('cube', (hx, hy, hz), (0.03, 0.17, 0.03), DARK), add('cube', (hx, hy - 0.19, hz), (0.02, 0.03, 0.19), GOLD),
                         add('cube', (hx, hy - 0.62, hz), (0.05, 0.80, 0.05), STEEL), add('cube', (hx, hy - 0.62, hz + 0.03), (0.055, 0.78, 0.01), STORM)):
                attach(part, rig, 'hand_r')
        elif p == 'mitre':
            attach(add('cone', (0, 0.0, 1.95), (0.11, 0.08, 0.26), CLOTH), rig, 'Head')
            attach(add('cube', (0, -0.075, 1.93), (0.03, 0.01, 0.2), GOLD), rig, 'Head')
            attach(add('cube', (0, -0.075, 1.95), (0.12, 0.01, 0.03), GOLD), rig, 'Head')
            attach(add('sphere', (0, -0.02, 1.70), (0.10, 0.10, 0.11), BONE), rig, 'Head')               # a skull under the hood
            attach(add('sphere', (0, -0.095, 1.705), (0.07, 0.03, 0.03), DARK), rig, 'Head')
        elif p == 'crozier':
            hx, hy, hz = -0.76, 0.07, 1.44
            attach(add('cyl', (hx, hy, hz - 0.2), (0.025, 0.025, 1.9), GOLD), rig, 'hand_r')            # an upright staff
            attach(add('torus', (hx, hy - 0.1, hz + 0.85), (0.12, 0.12, 0.12), GOLD, rot=(math.radians(90), 0, 0), minor=0.25), rig, 'hand_r')
            attach(add('sphere', (hx, hy - 0.1, hz + 0.85), (0.05, 0.05, 0.05), FUSE), rig, 'hand_r')
        elif p == 'ice_mantle':
            sb = 'spine_02' if 'spine_02' in rig.data.bones else 'spine_03'
            h = rig.data.bones[sb].head_local
            hb = rig.data.bones['Head'].tail_local
            for k in range(7):                                                                   # a ridge of ice down the back
                a = (k - 3) * 0.32
                attach(add('cone', (h[0] + math.sin(a) * 0.14, h[1] + 0.16, h[2] + 0.1 + math.cos(a) * 0.12), (0.05, 0.05, 0.22 + 0.06 * (3 - abs(k - 3))), ICE, rot=(math.radians(-50), math.radians(a * 40), 0)), rig, sb)
            for k, dx in enumerate((-0.07, 0.0, 0.07)):
                attach(add('cone', (hb[0] + dx, hb[1], hb[2] + 0.08 + (0.04 if k == 1 else 0)), (0.035, 0.035, 0.14 + (0.06 if k == 1 else 0)), ICE), rig, 'Head')
        elif p == 'molten_plate':
            sb = 'spine_02' if 'spine_02' in rig.data.bones else 'spine_03'
            h = rig.data.bones[sb].head_local
            attach(add('cube', (h[0], h[1] - 0.14, h[2] + 0.08), (0.28, 0.06, 0.26), IRON), rig, sb)
            attach(add('cube', (h[0], h[1] - 0.18, h[2] + 0.08), (0.16, 0.02, 0.14), EMBER_GLOW), rig, sb)
        elif p == 'king_crown':
            hb = rig.data.bones['Head'].tail_local
            cz = hb[2] + 0.02
            attach(add('torus', (hb[0], hb[1], cz), (0.11, 0.11, 0.2), GOLD, minor=0.03), rig, 'Head')
            for k in range(7):
                a = k * math.tau / 7
                attach(add('cone', (hb[0] + math.cos(a) * 0.11, hb[1] + math.sin(a) * 0.11, cz + 0.1), (0.03, 0.03, 0.14), GOLD), rig, 'Head')
            attach(add('sphere', (hb[0], hb[1] - 0.11, cz + 0.02), (0.025, 0.025, 0.025), STORM), rig, 'Head')
        elif p == 'cape':
            attach(add('cube', (0, 0.14, 1.1), (0.42, 0.03, 0.85), CLOTH), rig, 'spine_03')
        elif p == 'crown':
            hb = rig.data.bones['Head'].tail_local
            cz = hb[2] + 0.16
            attach(add('torus', (hb[0], hb[1], cz), (0.11, 0.11, 0.2), GOLD, minor=0.026), rig, 'Head')
            for k in range(6):
                a = k * math.tau / 6
                attach(add('cone', (hb[0] + math.cos(a) * 0.11, hb[1] + math.sin(a) * 0.11, cz + 0.09), (0.028, 0.028, 0.12), GOLD), rig, 'Head')

# ------------------------------------------------------------------ scene

sc = bpy.context.scene
base = SPEC['base']
rig = None
eye_obj = None
if base.startswith(('outfit:', 'creature:', 'base:')):
    bpy.ops.import_scene.gltf(filepath=UAL)
    old = list(bpy.data.objects)
    for o in [o for o in old if o.type == 'MESH']: bpy.data.objects.remove(o, do_unlink=True)
    actions = {a.name: a for a in bpy.data.actions}
    kind, name = base.split(':')
    path = {'outfit': os.path.join(OUTFITS, name + '.gltf'), 'creature': os.path.join(BEST, name + '.glb'), 'base': os.path.join(BASES, name + '.gltf')}[kind]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    rig = [o for o in bpy.data.objects if o not in before and o.type == 'ARMATURE'][0]
    for o in [o for o in bpy.data.objects if o not in before and o.type == 'MESH' and o.name.startswith('Icosphere')]:
        bpy.data.objects.remove(o, do_unlink=True)
    tint_materials()
    build_props(rig, SPEC['props'])
    ht = rig.data.bones['Head'].tail_local
    eye_obj = bpy.data.objects.new('eye', None); sc.collection.objects.link(eye_obj)
    eye_obj.location = (0.0, -0.105, 1.70) if kind == 'outfit' else (ht[0], ht[1] - 0.07, ht[2] + SPEC.get('eye_dz', 0.0))
    attach(eye_obj, rig, 'Head')
    rig.animation_data_create()

def setup_scene():
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 36; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
    sc.render.film_transparent = True
    if base.startswith('proc:'): sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x, sc.render.resolution_y = CW * SHRINK, CH * SHRINK
    sc.render.image_settings.color_mode = 'RGBA'
    width_m = CW / PXM
    yaw = math.radians(SPEC.get('yaw', 0))
    cd = bpy.data.cameras.new('c'); cd.type = 'ORTHO'; cd.ortho_scale = width_m
    cam = bpy.data.objects.new('c', cd); sc.collection.objects.link(cam)
    shift = (0.5 - FEET_X) * width_m
    cz = -2.0 / PXM + CH / PXM / 2.0
    # camera on the -X side looks along +X (skeleton faces -Y -> image right); yaw swings it round the feet
    pos = mathutils.Vector((-6.0, -shift, cz))
    pos = mathutils.Matrix.Rotation(yaw, 3, 'Z') @ pos
    cam.location = (pos.x, pos.y, cz)
    cam.rotation_euler = (math.radians(90), 0, math.radians(-90) + yaw)
    sc.camera = cam
    def light(name, loc, energy, color):
        d = bpy.data.lights.new(name, 'AREA'); d.energy = energy * SPEC.get('light', 1.0); d.color = color; d.size = 1.8
        o = bpy.data.objects.new(name, d)
        v = mathutils.Matrix.Rotation(yaw, 3, 'Z') @ mathutils.Vector(loc)
        o.location = v
        o.rotation_euler = (math.radians(90), 0, (math.radians(90) if loc[0] > 0 else math.radians(-90)) + yaw)
        sc.collection.objects.link(o)
    light('key', (-3.5, -1.5, 2.2), 1000, (1.0, 0.86, 0.72)); light('rim', (3.5, 1.2, 2.2), 1100, (0.5, 0.6, 1.0)); light('fill', (-3.5, 2, 0.6), 200, (0.9, 0.8, 1.0))
    sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
    sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.04, 0.04, 0.06, 1)
    sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6
    return cam

cam = setup_scene()
EYES = {}

def eye_px(obj):
    dg = bpy.context.evaluated_depsgraph_get(); dg.update()
    p = obj.evaluated_get(dg).matrix_world.translation
    c = world_to_camera_view(sc, cam, p)
    return [round(c.x * CW, 1), round((1 - c.y) * CH, 1)]

def render_to(anim, i):
    d = os.path.join(OUT, ENEMY, anim); os.makedirs(d, exist_ok=True)
    sc.render.filepath = os.path.join(d, f'{i}.png')
    bpy.ops.render.render(write_still=True)

# ---------------------------------------------------------- procedural creatures

def build_wisp():
    c = SPEC.get('core', (255, 240, 170)); g = SPEC.get('glow', (255, 120, 30))
    core = mat('P_wcore', c, 0.5, 0, c, 1.0)
    glow = mat('P_wglow', g, 0.5, 0, g, 10.0)
    ember = mat('P_wemb', g, 0.5, 0, g, 1.0)
    return core, glow, ember

def pose_wisp(anim, t, objs):
    core, glow, tail1, tail2, tail3, eyeo = objs
    bob = math.sin(t * math.tau) * 0.03
    s = 1.0; lean = 0.0; dim = 1.0
    if anim == 'Move': lean = 0.04
    elif anim == 'Windup': s = 1.0 + 0.45 * t; bob += 0.0
    elif anim == 'Strike': s = 1.45 - 0.35 * t; lean = 0.08
    elif anim == 'Recover': s = 1.1 - 0.1 * t
    elif anim == 'Stun': s = 0.8; lean = -0.05
    elif anim == 'Death': s = max(0.05, 1.0 - t); dim = 1 - t
    base_z = 0.55 + bob
    for o, k in ((core, 0.55), (glow, 1.0)): o.scale = (0.13 * k * s, 0.13 * k * s, 0.15 * k * s)
    glow.location = (0, -lean, base_z)
    core.location = (-0.07, -lean, base_z + 0.01)
    for n, o in enumerate((tail1, tail2, tail3), 1):
        o.location = (0, 0.10 * n + 0.015 * math.sin(t * 6 + n) - lean, base_z - 0.05 * n - 0.02 * math.sin(t * math.tau + n))
        o.scale = tuple(0.09 * (1 - 0.22 * n) * s for _ in range(3))
    eyeo.location = (0, -0.13 * s - lean, base_z + 0.03)

def build_bat():
    body = mat('P_bbody', SPEC.get('body', (50, 30, 45)), 0.6)
    wc = SPEC.get('wing', (90, 30, 40))
    wing = mat('P_bwing', wc, 0.7, 0, wc if SPEC.get('wing_glow') else None, SPEC.get('wing_glow', 0.0))
    eyem = mat('P_beye', (255, 200, 80), 0.4, 0, (255, 190, 60), 1.0)
    return body, wing, eyem

# ------------------------------------------------------------------ rendering

def sample_t(count, loops, i):
    return i / count if loops else (i / (count - 1) if count > 1 else 0.0)

if base == 'proc:wisp':
    cm, gm, em = build_wisp()
    core = add('sphere', (0, 0, 0.55), (1, 1, 1), cm); glow = add('sphere', (0, 0, 0.55), (1, 1, 1), gm)
    glow.data.materials[0] = mat('P_wglow2', SPEC.get('glow', (255, 100, 20)), 0.5, 0, SPEC.get('glow', (255, 120, 30)), 1.0)
    tails = [add('sphere', (0, 0.1, 0.5), (0.05, 0.05, 0.05), em) for _ in range(3)]
    eyeo = bpy.data.objects.new('eye', None); sc.collection.objects.link(eyeo)
    objs = (core, glow, tails[0], tails[1], tails[2], eyeo)
    plan = {'Idle': (6, True), 'Move': (6, True), 'Windup': (4, False), 'Strike': (3, False), 'Recover': (3, False), 'Stun': (3, False), 'Death': (6, False)}
    for anim, (count, loops) in plan.items():
        if ONLY and anim not in ONLY: continue
        for i in range(count):
            pose_wisp(anim, sample_t(count, loops, i), objs)
            EYES.setdefault(anim, []).append(eye_px(eyeo))
            render_to(anim, i)
elif base == 'proc:bat':
    body_m, wing_m, eye_m = build_bat()
    body = add('sphere', (0, 0, 0.5), (0.07, 0.11, 0.07), body_m)
    head = add('sphere', (0, -0.12, 0.54), (0.055, 0.06, 0.055), body_m)
    ears = [add('cone', (sx * 0.03, -0.12, 0.60), (0.018, 0.018, 0.05), body_m) for sx in (-1, 1)]
    eyeo = add('sphere', (0.0, -0.17, 0.56), (0.012, 0.012, 0.012), eye_m)
    wings = []
    def make_wing(side):
        me = bpy.data.meshes.new('w'); ob = bpy.data.objects.new('wing', me); sc.collection.objects.link(ob)
        ob.data.materials.append(wing_m); return ob
    wings = [make_wing(-1), make_wing(1)]
    def pose_bat(anim, t):
        flap = math.sin(t * math.tau * (2 if anim in ('Idle', 'Move') else 1))
        dive = anim in ('Windup', 'Strike')
        up = 0.9 * flap + (0.2 if anim == 'Windup' else 0.0)
        if anim == 'Windup': up = 0.9 + 0.5 * t          # wings rear back
        if anim == 'Strike': up = -0.6                     # folded for the dive
        if anim == 'Stun': up = -0.2
        if anim == 'Death': up = -0.9 - 0.6 * t
        tilt = {'Windup': 0.5, 'Strike': -0.7, 'Stun': 0.3, 'Death': 1.2 * t}.get(anim, 0.0)
        for ob, side in zip(wings, (-1, 1)):
            L = 0.34
            sx = side * L * math.cos(up); sz = L * math.sin(up) * 1.1
            verts = [(side * 0.04, 0.0, 0.52), (sx, -0.04, 0.5 + sz), (side * 0.30 * math.cos(up), 0.14, 0.45 + 0.25 * sz), (side * 0.04, 0.12, 0.47), (sx * 0.62, 0.10, 0.50 + sz * 0.5)]
            ob.data.clear_geometry(); ob.data.from_pydata(verts, [], [(0, 1, 4), (0, 4, 2), (0, 2, 3)]); ob.data.update()
        for o in (body, head, eyeo, *ears):
            o.rotation_euler = (tilt, 0, 0)
        bob = 0.03 * flap if anim in ('Idle', 'Move') else 0.0
        for o, loc in ((body, (0, 0, 0.5)), (head, (0, -0.12, 0.54)), (eyeo, (0, -0.17, 0.56)), (ears[0], (-0.03, -0.12, 0.60)), (ears[1], (0.03, -0.12, 0.60))):
            o.location = (loc[0], loc[1], loc[2] + bob)
    plan = {'Idle': (6, True), 'Move': (8, True), 'Windup': (4, False), 'Strike': (3, False), 'Recover': (3, False), 'Stun': (3, False), 'Death': (6, False)}
    for anim, (count, loops) in plan.items():
        if ONLY and anim not in ONLY: continue
        for i in range(count):
            pose_bat(anim, sample_t(count, loops, i))
            EYES.setdefault(anim, []).append(eye_px(eyeo))
            render_to(anim, i)
else:
    for anim, (action, t0, t1, count, loops) in SPEC['anims'].items():
        if ONLY and anim not in ONLY: continue
        act = actions[action]
        rig.animation_data.action = act
        if hasattr(rig.animation_data, 'action_slot') and act.slots: rig.animation_data.action_slot = act.slots[0]
        f0, f1 = act.frame_range
        for i in range(count):
            t = t0 + (t1 - t0) * sample_t(count, loops, i)
            sc.frame_set(round(f0 + (f1 - f0) * t))
            EYES.setdefault(anim, []).append(eye_px(eye_obj))
            render_to(anim, i)
os.makedirs(os.path.join(OUT, ENEMY), exist_ok=True)
json.dump({'eyes': EYES, 'canvas': [CW, CH], 'eye_colour': SPEC['eye']}, open(os.path.join(OUT, ENEMY, 'eyes.json'), 'w'))
print('enemy done', ENEMY)
