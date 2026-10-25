# Blender script: smooth, glowing combat effects drawn on black (the game adds them over the scene).
#   blender -b -P fx_render.py -- <out_dir> [set ...]
# Sets (all white/cool so the game can tint them with a colour):
#   slash_a / slash_b / slash_c  512x512 @150px/m  a sweeping crescent, centred on the hero's chest (pixel 256,256); faces right
#   spark                        384x384 @150px/m  a hit flash: star, streaks, ring (pixel 192,192)
#   ring                         384x384 @150px/m  an expanding shock ring (pixel 192,192)
# Output: <out_dir>/<set>/<n>.png (RGB, black background)
import bpy, math, os, random, sys

argv = sys.argv[sys.argv.index('--') + 1:]
OUT, ONLY = argv[0], set(argv[1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def emission(name, rgb, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    e = nt.nodes.new('ShaderNodeEmission'); e.inputs['Color'].default_value = rgb + (1,); e.inputs['Strength'].default_value = strength
    o = nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    return m


HALO = emission('halo', (0.45, 0.65, 1.0), 2.5)
MID = emission('mid', (0.75, 0.88, 1.0), 9.0)
CORE = emission('core', (1.0, 1.0, 1.0), 30.0)
WARM_HALO = emission('whalo', (1.0, 0.55, 0.15), 3.0)
WARM_MID = emission('wmid', (1.0, 0.85, 0.5), 10.0)
objs = []


def clear():
    for o in objs: bpy.data.objects.remove(o, do_unlink=True)
    objs.clear()


def ribbon(points_a, points_b, mat):
    """A filled strip between two polylines (same length), in the XZ plane."""
    me = bpy.data.meshes.new('r')
    verts = [(p[0], 0.0, p[1]) for p in points_a] + [(p[0], 0.0, p[1]) for p in points_b]
    n = len(points_a)
    faces = [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)]
    me.from_pydata(verts, [], faces); me.update()
    ob = bpy.data.objects.new('r', me); ob.data.materials.append(mat); sc.collection.objects.link(ob); objs.append(ob)


def arc_ribbon(angle_a, angle_b, r_out, width_fn, mat, steps=40):
    """A crescent along a circular arc from angle_a to angle_b (degrees, CCW from +x), tapered by width_fn(0..1)."""
    outer, inner = [], []
    for k in range(steps + 1):
        s = k / steps
        a = math.radians(angle_a + (angle_b - angle_a) * s)
        w = width_fn(s)
        outer.append((math.cos(a) * r_out, math.sin(a) * r_out))
        inner.append((math.cos(a) * (r_out - w), math.sin(a) * (r_out - w)))
    ribbon(outer, inner, mat)


def setup(res, ppm):
    for o in [o for o in bpy.data.objects if o.type == 'CAMERA']: bpy.data.objects.remove(o, do_unlink=True)
    cd = bpy.data.cameras.new('c'); cd.type = 'ORTHO'; cd.ortho_scale = res / ppm
    cam = bpy.data.objects.new('c', cd); sc.collection.objects.link(cam)
    cam.location = (0, -6, 0); cam.rotation_euler = (math.radians(90), 0, 0); sc.camera = cam
    sc.render.resolution_x = sc.render.resolution_y = res


sc.render.engine = 'CYCLES'; sc.cycles.samples = 16; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
sc.render.film_transparent = False; sc.view_settings.view_transform = 'Standard'
sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0, 0, 0, 1)
sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.0
sc.use_nodes = True; nt = sc.node_tree
for n in list(nt.nodes): nt.nodes.remove(n)
rl = nt.nodes.new('CompositorNodeRLayers'); gl = nt.nodes.new('CompositorNodeGlare'); comp = nt.nodes.new('CompositorNodeComposite')
gl.glare_type = 'FOG_GLOW'; gl.quality = 'HIGH'; gl.threshold = 0.45; gl.size = 7; gl.mix = 0.0
nt.links.new(rl.outputs['Image'], gl.inputs['Image']); nt.links.new(gl.outputs['Image'], comp.inputs['Image'])


def save(name, i):
    d = os.path.join(OUT, name); os.makedirs(d, exist_ok=True)
    sc.render.filepath = os.path.join(d, f'{i}.png'); sc.render.image_settings.color_mode = 'RGB'
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ slash arcs
# (start angle, end angle, radius m, max width m): a: down-slash, b: rising backhand, c: wide finisher
SLASHES = {'slash_a': (140, -50, 1.2, 0.34), 'slash_b': (-55, 135, 1.14, 0.30), 'slash_c': (130, -125, 1.3, 0.42)}
HEAD = [0.30, 0.62, 0.88, 1.0, 1.0, 1.0]
TAIL = [0.0, 0.0, 0.05, 0.25, 0.55, 0.85]
FADE = [1.0, 1.0, 0.95, 0.75, 0.45, 0.2]


def slash_set(name):
    a0, a1, radius, wmax = SLASHES[name]
    setup(512, 150.0)
    for i in range(6):
        head, tail, fade = HEAD[i], TAIL[i], FADE[i]
        span = max(head - tail, 0.02)
        ang_a = a0 + (a1 - a0) * tail
        ang_b = a0 + (a1 - a0) * head
        def taper(s, k=1.0):
            s = min(max(s, 0.0), 1.0)
            return wmax * fade * k * (0.06 + 0.94 * s ** 1.4) * (1.0 - 0.9 * s ** 9)   # thin tail, thick bright head, sharp tip
        arc_ribbon(ang_a, ang_b, radius * 1.02, lambda s: taper(s, 1.35), HALO)
        arc_ribbon(ang_a, ang_b, radius, lambda s: taper(s, 1.0), MID)
        arc_ribbon(ang_a, ang_b, radius, lambda s: taper(s, 0.45), CORE)
        save(name, i)
        clear()


# ------------------------------------------------------------------ hit spark
def spark_set():
    setup(384, 150.0)
    rnd = random.Random(7)
    angles = [rnd.uniform(0, math.tau) for _ in range(11)]
    lens = [rnd.uniform(0.55, 1.0) for _ in range(11)]
    for i in range(7):
        t = i / 6.0
        grow = math.sin(min(t * 1.25, 1.0) * math.pi * 0.5)
        fade = max(0.0, 1.0 - t ** 1.6)
        # star flash
        spikes = 8
        outer, inner = [], []
        for k in range(spikes * 2 + 1):
            a = math.pi * k / spikes + 0.3
            r = (0.62 if k % 2 == 0 else 0.13) * grow * (0.5 + 0.5 * fade) * (1.0 if (k // 2) % 2 == 0 else 0.7)
            outer.append((math.cos(a) * r, math.sin(a) * r))
        ribbon(outer, [(0.0, 0.0)] * len(outer), WARM_MID)
        ribbon([(p[0] * 1.35, p[1] * 1.35) for p in outer], [(0.0, 0.0)] * len(outer), WARM_HALO)
        ribbon([(p[0] * 0.55, p[1] * 0.55) for p in outer], [(0.0, 0.0)] * len(outer), CORE)
        # streaks flying out
        for a, ln in zip(angles, lens):
            r0 = 0.12 + 0.62 * t * ln
            r1 = r0 + 0.32 * ln * (1.0 - t) * fade
            if r1 - r0 < 0.02: continue
            n = (-math.sin(a), math.cos(a))
            w = 0.022 * fade + 0.004
            ribbon([(math.cos(a) * r0 - n[0] * w, math.sin(a) * r0 - n[1] * w), (math.cos(a) * r1, math.sin(a) * r1)],
                   [(math.cos(a) * r0 + n[0] * w, math.sin(a) * r0 + n[1] * w), (math.cos(a) * r1, math.sin(a) * r1)], WARM_MID)
        save('spark', i)
        clear()


# ------------------------------------------------------------------ shock ring
def ring_set():
    setup(384, 150.0)
    for i in range(6):
        t = i / 5.0
        r = 0.22 + 0.9 * (1 - (1 - t) ** 2)
        w = 0.16 * (1 - t) + 0.015
        fade = max(0.0, 1.0 - t ** 1.4)
        for scale, mat in ((1.6, HALO), (1.0, MID), (0.4, CORE)):
            arc_ribbon(0, 360, r + w * scale * 0.5, lambda s, sc_=scale: max(w * sc_ * fade, 0.004), mat, steps=72)
        save('ring', i)
        clear()


for name in SLASHES:
    if not ONLY or name in ONLY: slash_set(name)
if not ONLY or 'spark' in ONLY: spark_set()
if not ONLY or 'ring' in ONLY: ring_set()
print('fx done')
