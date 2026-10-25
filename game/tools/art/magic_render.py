# Blender script: concept renders of six magic effects (glowing, drawn on black; the game adds them over the scene).
#   blender -b -P magic_render.py -- <out_dir>
# Output <out_dir>/<name>.png, 512x512 at 150 px/m (the game shows them at 25 px/m), RGB on black:
#   bolt_fly bolt_hit  fire_fly fire_hit  frost_fly frost_hit  chain_a chain_b chain_c chain_hit  void_fly void_hit  nova_ring nova_pillar
import bpy, math, os, random, sys

OUT = sys.argv[sys.argv.index('--') + 1]
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
RES, PPM = 512, 150


def emission(name, rgb, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    e = nt.nodes.new('ShaderNodeEmission'); e.inputs['Color'].default_value = rgb + (1,); e.inputs['Strength'].default_value = strength
    o = nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    return m


def palette(prefix, halo, mid, core=(1.0, 1.0, 1.0)):
    return (emission(prefix + 'h', halo, 0.8), emission(prefix + 'm', mid, 2.6), emission(prefix + 'c', core, 7.0))


VIOLET = palette('v', (0.55, 0.25, 1.0), (0.78, 0.6, 1.0))
FIRE = palette('f', (1.0, 0.32, 0.05), (1.0, 0.7, 0.2), (1.0, 0.97, 0.8))
ICE = palette('i', (0.25, 0.7, 1.0), (0.65, 0.92, 1.0))
BOLT = palette('b', (0.5, 0.3, 1.0), (0.8, 0.7, 1.0))
VOID = palette('o', (0.7, 0.1, 0.9), (1.0, 0.45, 1.0), (1.0, 0.9, 1.0))
GOLD = palette('g', (1.0, 0.55, 0.12), (1.0, 0.85, 0.45), (1.0, 1.0, 0.9))
objs = []


def clear():
    for o in objs: bpy.data.objects.remove(o, do_unlink=True)
    objs.clear()


def keep(o):
    objs.append(o); return o


# Depth by layer (the camera looks along +Y, so smaller Y is nearer): core in front of mid in front of halo,
# otherwise overlapping glowing shapes fight over the same plane.
LAYER_Y = {'h': 0.06, 'm': 0.0, 'c': -0.06}


def ribbon(a, b, mat):
    # a filled strip between two same-length polylines in the XZ plane
    me = bpy.data.meshes.new('r')
    y = LAYER_Y.get(mat.name[-1], 0.0)
    verts = [(p[0], y, p[1]) for p in a] + [(p[0], y, p[1]) for p in b]
    n = len(a)
    me.from_pydata(verts, [], [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)]); me.update()
    ob = bpy.data.objects.new('r', me); ob.data.materials.append(mat); sc.collection.objects.link(ob)
    return keep(ob)


def stroke(points, width_fn, mat):
    # a ribbon along a polyline, its width given by width_fn(0..1)
    left, right = [], []
    n = len(points)
    for i, p in enumerate(points):
        q = points[min(i + 1, n - 1)]; r = points[max(i - 1, 0)]
        dx, dz = q[0] - r[0], q[1] - r[1]
        L = math.hypot(dx, dz) or 1.0
        nx, nz = -dz / L, dx / L
        w = width_fn(i / (n - 1)) / 2
        left.append((p[0] + nx * w, p[1] + nz * w)); right.append((p[0] - nx * w, p[1] - nz * w))
    return ribbon(left, right, mat)


def layered(points, w, pal, taper=lambda s: 1.0):
    stroke(points, lambda s: w * 3.2 * taper(s), pal[0])
    stroke(points, lambda s: w * 1.6 * taper(s), pal[1])
    stroke(points, lambda s: w * 0.6 * taper(s), pal[2])


def sphere(loc, r, mat, scale=(1, 1, 1)):
    y = {'h': 0.6, 'm': 0.0, 'c': -0.6}.get(mat.name[-1], 0.0)      # a sphere is deep: inner ones must reach in front
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(loc[0], y, loc[1]), segments=24, ring_count=16)
    o = bpy.context.object; o.scale = scale; o.data.materials.append(mat)
    return keep(o)


def orb(loc, r, pal):
    sphere(loc, r * 1.7, pal[0]); sphere(loc, r * 1.15, pal[1]); sphere(loc, r * 0.7, pal[2])


def circle(r, w, mat, a0=0, a1=360, cx=0.0, cz=0.0):
    n = max(8, int(abs(a1 - a0) / 6))
    pts = [(cx + math.cos(math.radians(a0 + (a1 - a0) * k / n)) * r, cz + math.sin(math.radians(a0 + (a1 - a0) * k / n)) * r) for k in range(n + 1)]
    stroke(pts, lambda s: w, mat)


def spike(angle, length, w, pal, start=0.0, cx=0.0, cz=0.0):
    a = math.radians(angle)
    p0 = (cx + math.cos(a) * start, cz + math.sin(a) * start)
    p1 = (cx + math.cos(a) * (start + length), cz + math.sin(a) * (start + length))
    pts = [(p0[0] + (p1[0] - p0[0]) * k / 6, p0[1] + (p1[1] - p0[1]) * k / 6) for k in range(7)]
    layered(pts, w, pal, lambda s: 1.0 - s * 0.95)


def motes(rng, count, region, rmin, rmax, mat):
    for _ in range(count):
        sphere((rng.uniform(region[0], region[1]), rng.uniform(region[2], region[3])), rng.uniform(rmin, rmax), mat)


def setup():
    cd = bpy.data.cameras.new('c'); cd.type = 'ORTHO'; cd.ortho_scale = RES / PPM
    cam = bpy.data.objects.new('c', cd); sc.collection.objects.link(cam)
    cam.location = (0, -6, 0); cam.rotation_euler = (math.radians(90), 0, 0); sc.camera = cam
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 16; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
    sc.render.film_transparent = False; sc.view_settings.view_transform = 'Standard'
    sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
    sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0, 0, 0, 1)
    sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.0
    sc.use_nodes = True; nt = sc.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    rl = nt.nodes.new('CompositorNodeRLayers'); gl = nt.nodes.new('CompositorNodeGlare'); comp = nt.nodes.new('CompositorNodeComposite')
    gl.glare_type = 'FOG_GLOW'; gl.quality = 'HIGH'; gl.threshold = 0.6; gl.size = 7; gl.mix = 0.0
    nt.links.new(rl.outputs['Image'], gl.inputs['Image']); nt.links.new(gl.outputs['Image'], comp.inputs['Image'])


def save(name):
    sc.render.filepath = os.path.join(OUT, name + '.png')
    bpy.ops.render.render(write_still=True)
    clear()
    print('done', name)


setup()

# 1. Arcane Bolt: a comet with a tapering tail and a few sparks (travels right, head at the centre)
rng = random.Random(1)
tail = [(-1.6 + 1.6 * k / 20, 0.02 * math.sin(k * 0.9)) for k in range(21)]
layered(tail, 0.08, VIOLET, lambda s: s ** 1.4)
orb((0, 0), 0.1, VIOLET)
motes(rng, 9, (-1.5, -0.1, -0.2, 0.2), 0.012, 0.03, VIOLET[1])
save('bolt_fly')
for i in range(8):
    spike(i * 45 + 10, 0.55 + 0.45 * (i % 2), 0.07, VIOLET, 0.12)
circle(0.8, 0.045, VIOLET[0]); circle(0.8, 0.02, VIOLET[1]); orb((0, 0), 0.17, VIOLET)
motes(rng, 10, (-0.9, 0.9, -0.9, 0.9), 0.012, 0.03, VIOLET[2])
save('bolt_hit')

# 2. Fire Orb: a fireball trailing flame, and the explosion
rng = random.Random(2)
for k in range(5):
    pts = [(-0.2 - 1.3 * s, (k - 2) * 0.05 * (1 - s) + 0.07 * math.sin(s * 9 + k)) for s in [i / 14 for i in range(15)]]
    layered(pts, 0.1 - abs(k - 2) * 0.012, FIRE, lambda s: (1 - s) ** 0.8)
orb((0, 0), 0.17, FIRE)
motes(rng, 14, (-1.6, -0.2, -0.3, 0.3), 0.01, 0.028, FIRE[1])
save('fire_fly')
for i in range(14):
    spike(i * 360 / 14 + rng.uniform(-8, 8), rng.uniform(0.6, 1.25), 0.1, FIRE, 0.25)
orb((0, 0), 0.34, FIRE); circle(1.15, 0.06, FIRE[0]); circle(1.15, 0.025, FIRE[1])
motes(rng, 26, (-1.5, 1.5, -1.5, 1.5), 0.01, 0.03, FIRE[1])
save('fire_hit')

# 3. Frost Shards: a fan of ice spears, and the shatter
rng = random.Random(3)
for ang, ln in ((-26, 0.9), (-13, 1.1), (0, 1.3), (13, 1.1), (26, 0.9)):
    a = math.radians(ang); L = ln
    tip = (-0.1 + math.cos(a) * L, math.sin(a) * L); base = (-0.1, 0.0)
    nx, nz = -math.sin(a) * 0.07, math.cos(a) * 0.07
    mid = (base[0] + (tip[0] - base[0]) * 0.35, base[1] + (tip[1] - base[1]) * 0.35)
    ribbon([base, mid, tip], [base, (mid[0] + nx * 2, mid[1] + nz * 2), tip], ICE[0])
    ribbon([base, mid, tip], [base, (mid[0] - nx * 2, mid[1] - nz * 2), tip], ICE[1])
    stroke([base, tip], lambda s: 0.03 * (1 - s), ICE[2])
motes(rng, 16, (-1.0, 0.8, -0.5, 0.5), 0.008, 0.022, ICE[2])
save('frost_fly')
for i in range(11):
    spike(i * 360 / 11 + rng.uniform(-10, 10), rng.uniform(0.5, 1.2), 0.09, ICE, 0.1)
circle(0.95, 0.05, ICE[0]); circle(0.95, 0.02, ICE[1]); orb((0, 0), 0.18, ICE)
motes(rng, 24, (-1.4, 1.4, -1.4, 1.4), 0.008, 0.024, ICE[2])
save('frost_hit')

# 4. Chain Lightning: a jagged violet bolt from (-1.6, 0) to (1.6, 0), three variations, and the flash where it lands
for name, seed in (('chain_a', 11), ('chain_b', 12), ('chain_c', 13)):
    rng = random.Random(seed)
    pts = [(-1.6, 0.0)]
    for k in range(1, 12):
        pts.append((-1.6 + 3.2 * k / 12, rng.uniform(-0.17, 0.17)))
    pts.append((1.6, 0.0))
    layered(pts, 0.035, BOLT)
    for _ in range(3):                                           # little forks
        i = rng.randint(2, 9); p = pts[i]; sgn = rng.choice((-1, 1))
        fork = [p, (p[0] + 0.25, p[1] + sgn * 0.18), (p[0] + 0.5, p[1] + sgn * 0.3)]
        layered(fork, 0.02, BOLT, lambda s: 1 - s * 0.8)
    save(name)
rng = random.Random(14)
for i in range(9):
    spike(i * 40 + rng.uniform(-10, 10), rng.uniform(0.3, 0.8), 0.05, BOLT, 0.08)
orb((0, 0), 0.2, BOLT); circle(0.55, 0.03, BOLT[1])
save('chain_hit')

# 5. Void Orb: a ring of violet fire round a dark centre with spiral arms; the game draws a dark disc inside it
rng = random.Random(5)
for arm in range(4):
    a0 = arm * 90
    pts = [(math.cos(math.radians(a0 + s * 200)) * (0.95 - 0.6 * s), math.sin(math.radians(a0 + s * 200)) * (0.95 - 0.6 * s)) for s in [i / 24 for i in range(25)]]
    layered(pts, 0.05, VOID, lambda s: 0.25 + 0.75 * s)
circle(0.36, 0.07, VOID[0]); circle(0.36, 0.045, VOID[1]); circle(0.36, 0.015, VOID[2])
motes(rng, 16, (-0.9, 0.9, -0.9, 0.9), 0.01, 0.025, VOID[1])
save('void_fly')
for arm in range(6):
    a0 = arm * 60
    pts = [(math.cos(math.radians(a0 + s * 160)) * (0.4 + 1.1 * s), math.sin(math.radians(a0 + s * 160)) * (0.4 + 1.1 * s)) for s in [i / 24 for i in range(25)]]
    layered(pts, 0.06, VOID, lambda s: 1 - 0.85 * s)
circle(0.45, 0.09, VOID[0]); circle(0.45, 0.05, VOID[1]); orb((0, 0), 0.22, VOID)
save('void_hit')

# 6. Rune Nova: a rune ring seen from above (the game squashes it onto the floor) and a pillar of light
rng = random.Random(6)
circle(1.6, 0.07, GOLD[0]); circle(1.6, 0.035, GOLD[1]); circle(1.38, 0.04, GOLD[0]); circle(1.38, 0.018, GOLD[1])
for i in range(24):
    a = math.radians(i * 15); r0 = 1.42 if i % 2 else 1.46; r1 = 1.58
    stroke([(math.cos(a) * r0, math.sin(a) * r0), (math.cos(a) * r1, math.sin(a) * r1)], lambda s: 0.045, GOLD[2])
for tri in (0, 60):                                              # a six-pointed star
    pts = [(math.cos(math.radians(tri + 120 * k + 90)) * 1.3, math.sin(math.radians(tri + 120 * k + 90)) * 1.3) for k in range(4)]
    stroke(pts, lambda s: 0.03, GOLD[1])
orb((0, 0), 0.12, GOLD)
save('nova_ring')
stroke([(0.0, -1.7), (0.0, 0.9)], lambda s: 0.5 * (1 - s * 0.55), GOLD[0])
stroke([(0.0, -1.7), (0.0, 0.9)], lambda s: 0.26 * (1 - s * 0.6), GOLD[1])
stroke([(0.0, -1.7), (0.0, 0.9)], lambda s: 0.09 * (1 - s * 0.7), GOLD[2])
motes(rng, 16, (-0.4, 0.4, -1.5, 0.9), 0.01, 0.028, GOLD[2])
save('nova_pillar')
