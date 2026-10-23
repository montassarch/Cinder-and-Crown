# Blender script: smooth, glowing lightning for the game (the "real lightning" look), rendered on black so the game
# can add it over the scene (additive blending). Orthographic camera, emissive fractal bolts, compositor glow.
#   blender -b -P lightning_hd_render.py -- <out_dir> [set ...]
# Sets (each in blue and red; the wave in red only):
#   blade_<c>  512x256 @150px/m: lightning wrapped round a 0.93 m blade lying along +x with its guard at x=0 (pixel 106,128)
#   bolt_<c>   288x608 @100px/m: a bolt from the sky (top) down to a point at the bottom centre (pixel 144,600)
#   wave_red   384x288 @150px/m: Rend's ground wave, head at the right edge, ground at the bottom
# Output: <out_dir>/<set>/<n>.png (RGB, black background)
import bpy, math, os, random, sys, mathutils

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = argv[0]
ONLY = set(argv[1:])
PAL = {'blue': dict(core=(0.93, 0.97, 1.0), glow=(0.25, 0.45, 1.0)), 'red': dict(core=(1.0, 0.9, 0.82), glow=(1.0, 0.14, 0.08))}
def V(*a): return mathutils.Vector(a)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

def emission(name, rgb, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for nd in list(nt.nodes): nt.nodes.remove(nd)
    e = nt.nodes.new('ShaderNodeEmission'); e.inputs['Color'].default_value = rgb + (1,); e.inputs['Strength'].default_value = strength
    o = nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    return m

MATS = {}
for flavour, p in PAL.items():
    MATS[flavour] = (emission(flavour + 'core', p['core'], 40.0),
                     emission(flavour + 'mid', tuple(min(1.0, c * 0.55 + 0.45) for c in p['glow']), 12.0),
                     emission(flavour + 'halo', p['glow'], 3.0))

class Painter:
    def __init__(self, flavour, rnd):
        self.mats, self.rnd, self.objs = MATS[flavour], rnd, []

    def tube(self, pts, r):
        for scale, m in ((0.5, self.mats[2]), (0.2, self.mats[1]), (0.075, self.mats[0])):
            cu = bpy.data.curves.new('t', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r * scale * 1.5; cu.bevel_resolution = 3; cu.fill_mode = 'FULL'
            sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
            n = max(len(pts) - 1, 1)
            for i, (p, co) in enumerate(zip(sp.points, pts)):
                p.co = (co.x, co.y, co.z, 1.0); p.radius = 1.0 - 0.6 * (i / n)
            ob = bpy.data.objects.new('t', cu); ob.data.materials.append(m); sc.collection.objects.link(ob); self.objs.append(ob)

    def displace(self, a, b, offset, gens):
        pts = [a, b]
        for g in range(gens):
            new = [pts[0]]
            for p, q in zip(pts, pts[1:]):
                mid = (p + q) / 2; d = q - p
                n1 = d.cross(V(0, 1, 0)); n1 = n1.normalized() if n1.length > 1e-6 else V(1, 0, 0)
                n2 = d.cross(n1); n2 = n2.normalized() if n2.length > 1e-6 else V(0, 1, 0)
                mid += n1 * self.rnd.uniform(-offset, offset) + n2 * self.rnd.uniform(-offset, offset) * 0.4
                new += [mid, q]
            pts = new; offset *= 0.52
        return pts

    def bolt(self, a, b, r, depth, gens=6, spread=0.16, forks=(1, 3)):
        pts = self.displace(a, b, (b - a).length * spread, gens)
        self.tube(pts, r)
        if depth > 0:
            d = (b - a).normalized()
            for _ in range(self.rnd.randint(*forks)):
                i = self.rnd.randint(len(pts) // 4, len(pts) - len(pts) // 5)
                dirn = (d + V(self.rnd.uniform(-1, 1), self.rnd.uniform(-0.4, 0.4), self.rnd.uniform(-1, 1)) * 0.9).normalized()
                self.bolt(pts[i], pts[i] + dirn * (b - a).length * self.rnd.uniform(0.28, 0.48), r * 0.55, depth - 1, gens - 1, spread, forks)

    def clear(self):
        for o in self.objs: bpy.data.objects.remove(o, do_unlink=True)
        self.objs = []

def camera(res_x, res_y, ortho, centre):
    for o in [o for o in bpy.data.objects if o.type == 'CAMERA']: bpy.data.objects.remove(o, do_unlink=True)
    cd = bpy.data.cameras.new('c'); cd.type = 'ORTHO'; cd.ortho_scale = ortho
    cam = bpy.data.objects.new('c', cd); sc.collection.objects.link(cam)
    cam.location = (centre[0], -6.0, centre[1]); cam.rotation_euler = (math.radians(90), 0, 0); sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res_x, res_y

sc.render.engine = 'CYCLES'; sc.cycles.samples = 16; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
sc.render.film_transparent = False
sc.view_settings.view_transform = 'Standard'
sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0, 0, 0, 1)
sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.0
sc.use_nodes = True; nt = sc.node_tree
for n in list(nt.nodes): nt.nodes.remove(n)
rl = nt.nodes.new('CompositorNodeRLayers'); gl = nt.nodes.new('CompositorNodeGlare'); comp = nt.nodes.new('CompositorNodeComposite')
gl.glare_type = 'FOG_GLOW'; gl.quality = 'HIGH'; gl.threshold = 0.5; gl.size = 7; gl.mix = 0.0
nt.links.new(rl.outputs['Image'], gl.inputs['Image']); nt.links.new(gl.outputs['Image'], comp.inputs['Image'])

def save(setname, i):
    d = os.path.join(OUT, setname); os.makedirs(d, exist_ok=True)
    sc.render.filepath = os.path.join(d, f'{i}.png'); sc.render.image_settings.color_mode = 'RGB'
    bpy.ops.render.render(write_still=True)

def blade_frame(painter, rnd):
    L = 0.93
    guard, tip = V(0, 0, 0), V(L, 0, 0)
    u, v = V(0, 1, 0), V(0, 0, 1)
    for phase in (0.0, math.pi):
        pts = []
        for k in range(70):
            s = k / 69.0
            centre = guard + V(L * (0.04 + 0.96 * s), 0, 0)
            ang = phase + s * math.tau * 3.2 + rnd.uniform(-0.15, 0.15)
            rad = 0.05 + 0.03 * math.sin(s * 9 + phase) + rnd.uniform(0, 0.02)
            pts.append(centre + (u * math.cos(ang) + v * math.sin(ang)) * rad)
        painter.tube(pts, 0.012)
    for _ in range(9):
        root = guard + V(L * rnd.uniform(0.1, 1.0), 0, 0)
        ang = rnd.uniform(0, math.tau)
        dirn = (u * math.cos(ang) + v * math.sin(ang) + V(rnd.uniform(-0.2, 0.5), 0, 0)).normalized()
        painter.bolt(root, root + dirn * rnd.uniform(0.2, 0.5), 0.011, 1, gens=5)
    for _ in range(3):
        dirn = (V(rnd.uniform(0.7, 1.0), 0, 0) + u * rnd.uniform(-0.5, 0.5) + v * rnd.uniform(-0.8, 0.8)).normalized()
        painter.bolt(tip, tip + dirn * rnd.uniform(0.6, 1.3), 0.016, 2, gens=7, spread=0.14)

def bolt_frame(painter, rnd):
    top = V(rnd.uniform(-0.05, 0.05), 0, 5.95); end = V(0, 0, 0.04)
    painter.bolt(top, end, 0.03, 3, gens=8, spread=0.1, forks=(3, 5))

def wave_frame(painter, rnd):
    ground = painter.displace(V(-1.2, 0, 0.07), V(1.15, 0, 0.07), 0.07, 7)
    painter.tube(ground, 0.02)
    painter.bolt(V(1.15, 0, 0.07), V(1.18 + rnd.uniform(-0.1, 0.04), 0, 1.38), 0.022, 2, gens=7, spread=0.16, forks=(2, 3))
    for _ in range(5):
        root = ground[rnd.randint(8, len(ground) - 6)]
        tip = root + V(rnd.uniform(0.0, 0.3), 0, rnd.uniform(0.35, 1.0))
        painter.bolt(root, tip, 0.012, 1, gens=5, spread=0.1)

SETS = {
    'blade': dict(res=(512, 256), ortho=512 / 150.0, centre=(1.0, 0.0), frames=8, draw=blade_frame, flavours=('blue', 'red')),
    'bolt': dict(res=(288, 608), ortho=6.08, centre=(0.0, 2.96), frames=8, draw=bolt_frame, flavours=('blue', 'red')),
    'wave': dict(res=(384, 288), ortho=384 / 150.0, centre=(0.0, 0.91), frames=6, draw=wave_frame, flavours=('red',)),
}
for name, spec in SETS.items():
    if ONLY and name not in ONLY: continue
    camera(spec['res'][0], spec['res'][1], spec['ortho'], spec['centre'])
    for flavour in spec['flavours']:
        for i in range(spec['frames']):
            rnd = random.Random(1000 + i * 37 + (0 if flavour == 'blue' else 5))
            painter = Painter(flavour, rnd)
            spec['draw'](painter, rnd)
            save(f'{name}_{flavour}', i)
            painter.clear()
print('hd lightning done')
