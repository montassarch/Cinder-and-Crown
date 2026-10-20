# Blender script: pre-rendered lightning sprites (blue for Storm, red for Rend). Built from curves, flat emissive
# colours (outline / body / core), orthographic camera, transparent background. lightning_pixel.py shrinks them.
#   blender -b -P lightning_render.py -- <out_dir>
# Output: <out_dir>/<name>/<n>.png   names: bolt_blue, bolt_red, crackle_blue, crackle_red, wave_red
import bpy, math, os, random, sys

out = sys.argv[sys.argv.index('--') + 1]
PALETTES = {
    'blue': {'outline': (8, 16, 60), 'body': (60, 210, 255), 'core': (255, 252, 230)},
    'red': {'outline': (45, 0, 12), 'body': (255, 64, 40), 'core': (255, 236, 205)},
}
PX_PER_M = 100.0


def srgb_to_linear(c):
    return tuple(((v / 255.0) / 12.92) if v / 255.0 <= 0.04045 else (((v / 255.0) + 0.055) / 1.055) ** 2.4 for v in c)


def emission(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = srgb_to_linear(rgb) + (1.0,)
    e.inputs['Strength'].default_value = 1.0
    o = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    return m


def jag(rnd, a, b, segs, amp):
    """A jagged line from a to b in the (x, z) plane: every middle point is pushed sideways."""
    (x0, z0), (x1, z1) = a, b
    dx, dz = x1 - x0, z1 - z0
    n = math.hypot(dx, dz) or 1.0
    nx, nz = -dz / n, dx / n
    pts = [a]
    for i in range(1, segs):
        u = i / segs
        off = rnd.uniform(-amp, amp)
        pts.append((x0 + dx * u + nx * off, z0 + dz * u + nz * off))
    pts.append(b)
    return pts


def tube(pts, radius, mat, y):
    cu = bpy.data.curves.new('c', 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    cu.fill_mode = 'FULL'
    sp = cu.splines.new('POLY')
    sp.points.add(len(pts) - 1)
    for p, (x, z) in zip(sp.points, pts):
        p.co = (x, y, z, 1.0)
    ob = bpy.data.objects.new('t', cu)
    ob.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def bolt(paths, palette_name, thickness=1.0, r_outline=0.032, r_body=0.022, r_core=0.009):
    """Every path drawn three times, fat to thin, the thin ones nearer the camera."""
    pal = MATS[palette_name]
    objs = []
    for pts, weight in paths:
        w = thickness * weight
        objs.append(tube(pts, r_outline * w, pal['outline'], 0.00))
        objs.append(tube(pts, r_body * w, pal['body'], -0.05))
        objs.append(tube(pts, r_core * w, pal['core'], -0.10))
    return objs


def clear(objs):
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)


def setup(res_x, res_y, width_m, centre_z):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 8
    sc.cycles.device = 'CPU'
    sc.cycles.use_denoising = False
    sc.render.film_transparent = True
    sc.render.resolution_x, sc.render.resolution_y = res_x, res_y
    sc.render.image_settings.color_mode = 'RGBA'
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    for o in [o for o in bpy.data.objects if o.type == 'CAMERA']:
        bpy.data.objects.remove(o, do_unlink=True)
    cd = bpy.data.cameras.new('cam')
    cd.type = 'ORTHO'
    cd.ortho_scale = width_m
    cam = bpy.data.objects.new('cam', cd)
    sc.collection.objects.link(cam)
    cam.location = (0.0, -5.0, centre_z)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = cam
    sc.world = bpy.data.worlds.new('w')
    return sc


def render(sc, folder, i):
    os.makedirs(folder, exist_ok=True)
    sc.render.filepath = os.path.join(folder, f'{i}.png')
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ sprites

def strike_bolt(palette):
    """A tall bolt from the sky (top of the frame) to the bottom centre, 40 x 160 px, with forks. 8 frames."""
    sc = setup(400, 1600, 0.4, 0.8)
    thickness = [0.6, 1.0, 1.0, 0.95, 0.9, 0.75, 0.5, 0.3]
    for i, t in enumerate(thickness):
        rnd = random.Random(100 + i * 7)
        main = jag(rnd, (rnd.uniform(-0.03, 0.03), 1.56), (0.0, 0.03), 16, 0.055)
        paths = [(main, 1.0)]
        for k in range(3):
            root = main[rnd.randint(4, 12)]
            ang = math.radians(rnd.choice([-1, 1]) * rnd.uniform(25, 55))
            ln = rnd.uniform(0.18, 0.34)
            tip = (root[0] + math.sin(ang) * ln, root[1] - math.cos(ang) * ln)
            paths.append((jag(rnd, root, tip, 5, 0.025), 0.55))
        objs = bolt(paths, palette, thickness=t)
        render(sc, os.path.join(out, f'bolt_{palette}'), i)
        clear(objs)


def crackle(palette):
    """Short arcs spitting off a point, 32 x 32 px, 6 frames: the charged sword's crackle."""
    sc = setup(320, 320, 0.32, 0.0)
    for i in range(6):
        rnd = random.Random(500 + i * 13)
        paths = []
        for k in range(4):
            ang = rnd.uniform(0, math.tau)
            ln = rnd.uniform(0.09, 0.145)
            paths.append((jag(rnd, (0.0, 0.0), (math.cos(ang) * ln, math.sin(ang) * ln), 4, 0.022), 0.8))
        objs = bolt(paths, palette, r_outline=0.016, r_body=0.011, r_core=0.0045)
        render(sc, os.path.join(out, f'crackle_{palette}'), i)
        clear(objs)


def wave(palette):
    """Rend's head: a bolt along the ground and a tall one at the front, 64 x 48 px, 6 frames. Faces right."""
    sc = setup(640, 480, 0.64, 0.24)
    for i in range(6):
        rnd = random.Random(900 + i * 11)
        ground = jag(rnd, (-0.30, 0.035), (0.27, 0.035), 12, 0.022)
        head = jag(rnd, (0.27, 0.035), (0.30 + rnd.uniform(-0.02, 0.03), 0.45), 8, 0.04)
        paths = [(ground, 1.0), (head, 1.0)]
        for k in range(3):
            root = ground[rnd.randint(3, 10)]
            tip = (root[0] + rnd.uniform(0.02, 0.10), root[1] + rnd.uniform(0.12, 0.30))
            paths.append((jag(rnd, root, tip, 4, 0.02), 0.6))
        objs = bolt(paths, palette, r_outline=0.026, r_body=0.018, r_core=0.0075)
        render(sc, os.path.join(out, f'wave_{palette}'), i)
        clear(objs)


bpy.ops.wm.read_factory_settings(use_empty=True)
MATS = {name: {k: emission(f'{name}_{k}', rgb) for k, rgb in pal.items()} for name, pal in PALETTES.items()}
for p in ('blue', 'red'):
    strike_bolt(p)
    crackle(p)
wave('red')
print('lightning done')
