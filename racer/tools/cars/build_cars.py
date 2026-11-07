"""Builds the low-poly car models and exports them as .glb files for Godot.

Run with a Python that has Blender's module installed (pip install bpy):

    python build_cars.py --out ../../assets/cars [--render ./renders] [--only f80]

Each car is a lofted body shell, a glass canopy, four separate wheel nodes (Wheel_FL, Wheel_FR,
Wheel_RL, Wheel_RR, origin at the hub so the game can spin and steer them), lights and a wing.
The body is stylized: proportions are approximate, not scans. The nose points to -Y in Blender,
which exports as +Z in glTF/Godot (the game's forward axis).
"""
import argparse
import math
import os

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Vector

# Approximate stylized proportions. Station tuples: (t, half-width fraction, bottom z, top z),
# t runs from the nose (0) to the tail (1).
CARS = {
    "f80": {
        "paint": (0.75, 0.02, 0.03),
        "length": 4.84, "width": 2.06, "height": 1.14, "wheelbase": 2.78, "front_overhang": 0.95,
        "roundness": 0.55,
        "stations": [(0.00, 0.55, 0.20, 0.42), (0.04, 0.80, 0.17, 0.52), (0.12, 0.92, 0.15, 0.62),
                     (0.25, 0.97, 0.15, 0.74), (0.40, 1.00, 0.15, 0.86), (0.55, 1.00, 0.15, 0.93),
                     (0.70, 0.98, 0.17, 0.93), (0.85, 0.92, 0.22, 0.88), (0.95, 0.80, 0.28, 0.84),
                     (1.00, 0.62, 0.32, 0.80)],
        "canopy": (0.30, 0.68, 0.22), "wing": "active", "taillight": "bar", "intake": "side",
    },
    "w1": {
        "paint": (0.95, 0.30, 0.02),
        "length": 4.64, "width": 2.19, "height": 1.07, "wheelbase": 2.68, "front_overhang": 0.92,
        "roundness": 0.7,
        "stations": [(0.00, 0.50, 0.18, 0.38), (0.05, 0.78, 0.15, 0.50), (0.14, 0.90, 0.14, 0.60),
                     (0.28, 0.97, 0.14, 0.70), (0.42, 1.00, 0.14, 0.80), (0.58, 1.00, 0.14, 0.88),
                     (0.74, 0.98, 0.16, 0.90), (0.88, 0.90, 0.22, 0.84), (0.96, 0.78, 0.28, 0.78),
                     (1.00, 0.60, 0.32, 0.74)],
        "canopy": (0.27, 0.62, 0.19), "wing": "tall", "taillight": "slit", "intake": "side",
    },
    "temerario": {
        "paint": (0.35, 0.65, 0.05),
        "length": 4.71, "width": 2.02, "height": 1.20, "wheelbase": 2.66, "front_overhang": 0.98,
        "roundness": 0.32,
        "stations": [(0.00, 0.58, 0.22, 0.46), (0.04, 0.82, 0.18, 0.56), (0.12, 0.93, 0.16, 0.66),
                     (0.26, 0.98, 0.16, 0.78), (0.42, 1.00, 0.16, 0.88), (0.58, 1.00, 0.16, 0.94),
                     (0.72, 0.98, 0.18, 0.94), (0.86, 0.92, 0.24, 0.90), (0.95, 0.82, 0.30, 0.86),
                     (1.00, 0.66, 0.34, 0.82)],
        "canopy": (0.32, 0.68, 0.26), "wing": "none", "taillight": "hex", "intake": "side",
    },
    "zr1": {
        "paint": (0.05, 0.25, 0.85),
        "length": 4.63, "width": 1.98, "height": 1.22, "wheelbase": 2.72, "front_overhang": 0.90,
        "roundness": 0.6,
        "stations": [(0.00, 0.58, 0.20, 0.44), (0.04, 0.82, 0.17, 0.54), (0.12, 0.93, 0.15, 0.64),
                     (0.24, 0.97, 0.15, 0.76), (0.38, 1.00, 0.15, 0.86), (0.52, 1.00, 0.15, 0.92),
                     (0.68, 1.00, 0.17, 0.96), (0.84, 0.98, 0.22, 0.98), (0.95, 0.90, 0.28, 0.94),
                     (1.00, 0.76, 0.32, 0.90)],
        "canopy": (0.22, 0.60, 0.24), "wing": "tall", "taillight": "quad", "intake": "side",
    },
}

WHEEL_RADIUS_FRONT = 0.34
WHEEL_RADIUS_REAR = 0.35
WHEEL_WIDTH_FRONT = 0.27
WHEEL_WIDTH_REAR = 0.33


# ---------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name, color, metallic=0.0, roughness=0.5, emission=None, emission_strength=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return material


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def apply_modifier(obj, modifier):
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def object_from_bmesh(name, bm, material=None, smooth=True):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if material is not None:
        obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = smooth
    return obj


def box(name, size, location, material, rotation=(0.0, 0.0, 0.0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vertex in bm.verts:
        vertex.co.x *= size[0]
        vertex.co.y *= size[1]
        vertex.co.z *= size[2]
    obj = object_from_bmesh(name, bm, material, smooth=False)
    obj.location = location
    obj.rotation_euler = rotation
    return obj


def cylinder_x(name, radius, length, location, material, segments=24):
    """Cylinder whose axis is the X axis (a wheel lying on its side)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length)
    for vertex in bm.verts:
        vertex.co = Vector((vertex.co.z, vertex.co.y, vertex.co.x))  # swap axes: Z axis -> X axis
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = object_from_bmesh(name, bm, material, smooth=False)
    obj.location = location
    return obj


def lerp_profile(stations, t):
    """Smooth interpolation of the station table at position t."""
    for index in range(len(stations) - 1):
        t0, t1 = stations[index][0], stations[index + 1][0]
        if t0 <= t <= t1:
            u = (t - t0) / (t1 - t0)
            u = u * u * (3.0 - 2.0 * u)
            a, b = stations[index], stations[index + 1]
            return tuple(a[k] + (b[k] - a[k]) * u for k in (1, 2, 3))
    last = stations[-1]
    return last[1], last[2], last[3]


def loft(name, rings, material, closed_ends=True):
    """Builds a closed shell through rings (lists of Vector) of equal length."""
    bm = bmesh.new()
    verts = [[bm.verts.new(point) for point in ring] for ring in rings]
    count = len(rings[0])
    for r in range(len(rings) - 1):
        for i in range(count):
            j = (i + 1) % count
            bm.faces.new((verts[r][i], verts[r][j], verts[r + 1][j], verts[r + 1][i]))
    if closed_ends:
        bm.faces.new(list(reversed(verts[0])))
        bm.faces.new(verts[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return object_from_bmesh(name, bm, material, smooth=True)


def ring_points(y, half_width, z_bottom, z_top, roundness, count=20, taper=0.18):
    """A rounded cross-section; roundness 1 is an ellipse, smaller is boxier."""
    centre_z = (z_bottom + z_top) / 2.0
    half_height = (z_top - z_bottom) / 2.0
    points = []
    for i in range(count):
        angle = 2.0 * math.pi * i / count
        c, s = math.cos(angle), math.sin(angle)
        x = half_width * math.copysign(abs(c) ** roundness, c)
        z = centre_z + half_height * math.copysign(abs(s) ** roundness, s)
        if s > 0:
            x *= 1.0 - taper * s  # narrower shoulders at the top
        points.append(Vector((x, y, z)))
    return points


# ---------------------------------------------------------------------------------------
# car parts
# ---------------------------------------------------------------------------------------

def build_body(spec, materials):
    length, width = spec["length"], spec["width"]
    rings = []
    samples = 30
    for k in range(samples):
        t = k / (samples - 1)
        hw, zb, zt = lerp_profile(spec["stations"], t)
        # pinch the very first and last rings so the shell closes to a rounded point
        pinch = 1.0
        if k == 0 or k == samples - 1:
            pinch = 0.55
        y = -length / 2.0 + t * length
        rings.append(ring_points(y, hw * width / 2.0 * pinch, zb, zt, spec["roundness"]))
    body = loft("Body", rings, materials["Paint"])
    sub = body.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    apply_modifier(body, sub)
    return body


def cut_wheel_arches(body, spec, wheel_positions):
    for name, (x, y, z, radius) in wheel_positions.items():
        cutter = cylinder_x("Cutter_" + name, radius + 0.07, 0.62, (x, y, z), None, segments=20)
        boolean = body.modifiers.new("Arch_" + name, "BOOLEAN")
        boolean.operation = "DIFFERENCE"
        boolean.object = cutter
        boolean.solver = "EXACT"
        apply_modifier(body, boolean)
        bpy.data.objects.remove(cutter, do_unlink=True)


def build_canopy(spec, materials):
    length, width, height = spec["length"], spec["width"], spec["height"]
    t0, t1, rise = spec["canopy"]
    rings = []
    samples = 12
    for k in range(samples):
        u = k / (samples - 1)
        t = t0 + (t1 - t0) * u
        hw, zb, zt = lerp_profile(spec["stations"], t)
        bump = math.sin(math.pi * u) ** 0.7
        top = zt + rise * bump
        half_width = hw * width / 2.0 * (0.50 + 0.30 * bump)
        y = -length / 2.0 + t * length
        rings.append(ring_points(y, max(half_width, 0.05), zt - 0.04, max(top, zt - 0.03), 0.8, count=14, taper=0.35))
    canopy = loft("Glass", rings, materials["Glass"])
    return canopy


def build_wheel(side, axle, spec, materials, radius, width, x, y):
    """One wheel: tyre + rim joined into a single mesh whose origin is the hub."""
    outward = 1.0 if side == "R" else -1.0
    tyre = cylinder_x("Tyre", radius, width, (0, 0, 0), materials["Tyre"], segments=22)
    rim_radius = radius * 0.72
    rim = cylinder_x("Rim", rim_radius, width * 0.9, (outward * width * 0.04, 0, 0), materials["Rim"], segments=22)
    parts = [tyre, rim]
    spokes = 6
    for k in range(spokes):
        angle = 2.0 * math.pi * k / spokes
        spoke = box("Spoke", (0.025, rim_radius * 1.7, 0.07), (outward * width * 0.47, 0, 0), materials["Rim"],
                    rotation=(angle, 0.0, 0.0))
        parts.append(spoke)
    cap = cylinder_x("Cap", rim_radius * 0.22, 0.04, (outward * width * 0.5, 0, 0), materials["Rim"], segments=10)
    parts.append(cap)
    activate(parts[0])
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    wheel = bpy.context.view_layer.objects.active
    wheel.name = "Wheel_%s%s" % (axle, side)
    wheel.location = (x, y, radius)
    return wheel


def build_details(spec, materials, hub_positions):
    length, width, height = spec["length"], spec["width"], spec["height"]
    objects = []
    front_y = -length / 2.0
    rear_y = length / 2.0
    hw_nose, zb_nose, zt_nose = lerp_profile(spec["stations"], 0.06)
    # front splitter and rear diffuser
    objects.append(box("Splitter", (width * 0.86, 0.5, 0.05), (0, front_y + 0.12, 0.13), materials["Carbon"]))
    objects.append(box("Diffuser", (width * 0.62, 0.55, 0.10), (0, rear_y - 0.2, 0.22), materials["Carbon"]))
    # headlights
    for sign in (-1, 1):
        objects.append(box("Headlight", (0.42, 0.12, 0.07),
                           (sign * width * 0.30, front_y + 0.30, zt_nose - 0.07), materials["LightFront"],
                           rotation=(0.0, 0.0, sign * -0.25)))
    # tail lights by style
    hw_t, zb_t, zt_t = lerp_profile(spec["stations"], 0.97)
    tail_z = zt_t - 0.12
    style = spec["taillight"]
    if style == "bar":
        objects.append(box("Taillight", (width * 0.72, 0.08, 0.07), (0, rear_y - 0.02, tail_z), materials["LightRear"]))
    elif style == "slit":
        for sign in (-1, 1):
            objects.append(box("Taillight", (width * 0.30, 0.08, 0.05), (sign * width * 0.25, rear_y - 0.02, tail_z), materials["LightRear"]))
    elif style == "hex":
        for sign in (-1, 1):
            objects.append(box("Taillight", (0.34, 0.08, 0.16), (sign * width * 0.28, rear_y - 0.02, tail_z - 0.02), materials["LightRear"],
                               rotation=(0.0, 0.0, sign * 0.5)))
    elif style == "quad":
        for sign in (-1, 1):
            for dz in (0.0, -0.13):
                objects.append(box("Taillight", (0.30, 0.08, 0.09), (sign * width * 0.30, rear_y - 0.02, tail_z + dz), materials["LightRear"]))
    # side intakes in front of the rear wheels
    rear_x_y = hub_positions["RL"][1]
    for sign in (-1, 1):
        objects.append(box("Intake", (0.06, 0.62, 0.22), (sign * (width / 2.0 * 0.985), rear_x_y - 0.95, 0.52), materials["Carbon"]))
    # mirrors
    t0, t1, rise = spec["canopy"]
    mirror_y = -length / 2.0 + (t0 + 0.04) * length
    mhw, mzb, mzt = lerp_profile(spec["stations"], t0 + 0.04)
    for sign in (-1, 1):
        objects.append(box("Mirror", (0.14, 0.10, 0.07), (sign * (mhw * width / 2.0 * 0.62), mirror_y, mzt + 0.05), materials["Carbon"]))
    # rear wing
    wing = spec["wing"]
    if wing != "none":
        span = width * (0.86 if wing == "tall" else 0.74)
        wing_z = 1.0 if wing == "tall" else 0.95
        wing_y = rear_y - 0.28
        objects.append(box("Wing", (span, 0.34, 0.035), (0, wing_y, wing_z + 0.12 * (height - 1.0)), materials["Carbon"], rotation=(-0.12, 0.0, 0.0)))
        for sign in (-1, 1):
            objects.append(box("WingEnd", (0.03, 0.40, 0.18), (sign * span / 2.0, wing_y, wing_z + 0.05), materials["Carbon"]))
            objects.append(box("WingPylon", (0.05, 0.10, 0.34), (sign * span * 0.22, wing_y + 0.02, wing_z - 0.15), materials["Carbon"]))
    # exhaust tips
    for sign in (-1, 1):
        tip = cylinder_x("Exhaust", 0.045, 0.12, (sign * 0.28, rear_y - 0.05, 0.42), materials["Rim"], segments=10)
        tip.rotation_euler = (0.0, 0.0, math.pi / 2.0)
        objects.append(tip)
    return objects


def build_car(car_id, spec):
    reset_scene()
    paint = spec["paint"]
    materials = {
        "Paint": make_material("Paint", paint, metallic=0.75, roughness=0.28),
        "Glass": make_material("Glass", (0.02, 0.03, 0.05), metallic=0.9, roughness=0.06),
        "Tyre": make_material("Tyre", (0.03, 0.03, 0.035), metallic=0.0, roughness=0.85),
        "Rim": make_material("Rim", (0.80, 0.82, 0.86), metallic=0.45, roughness=0.3),
        "Carbon": make_material("Carbon", (0.025, 0.025, 0.03), metallic=0.3, roughness=0.45),
        "LightFront": make_material("LightFront", (1.0, 1.0, 1.0), emission=(0.8, 0.9, 1.0), emission_strength=6.0),
        "LightRear": make_material("LightRear", (1.0, 0.05, 0.05), emission=(1.0, 0.05, 0.03), emission_strength=6.0),
        "Underbody": make_material("Underbody", (0.01, 0.01, 0.012), roughness=0.9),
    }
    length, width = spec["length"], spec["width"]
    front_axle_y = -length / 2.0 + spec["front_overhang"]
    rear_axle_y = front_axle_y + spec["wheelbase"]
    track_x = width / 2.0 - 0.17
    hubs = {
        "FL": (-track_x, front_axle_y, WHEEL_RADIUS_FRONT, WHEEL_RADIUS_FRONT),
        "FR": (track_x, front_axle_y, WHEEL_RADIUS_FRONT, WHEEL_RADIUS_FRONT),
        "RL": (-track_x, rear_axle_y, WHEEL_RADIUS_REAR, WHEEL_RADIUS_REAR),
        "RR": (track_x, rear_axle_y, WHEEL_RADIUS_REAR, WHEEL_RADIUS_REAR),
    }
    body = build_body(spec, materials)
    cut_wheel_arches(body, spec, hubs)
    # dark inner floor so the wheel arches do not show through the hollow shell
    floor = box("Underbody", (width * 0.80, length * 0.86, 0.34), (0, 0, 0.30), materials["Underbody"])
    canopy = build_canopy(spec, materials)
    wheels = []
    for key, (x, y, z, radius) in hubs.items():
        axle, side = key[0], key[1]
        width_w = WHEEL_WIDTH_FRONT if axle == "F" else WHEEL_WIDTH_REAR
        wheels.append(build_wheel(side, axle, spec, materials, radius, width_w, x, y))
    details = build_details(spec, materials, {k: (v[0], v[1]) for k, v in hubs.items()})
    # a single flat-shaded look for the small details
    for obj in details + [floor]:
        for polygon in obj.data.polygons:
            polygon.use_smooth = False
    return {"body": body, "canopy": canopy, "wheels": wheels, "details": details, "floor": floor}


def count_triangles():
    total = 0
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return total


def export_glb(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False)


def render_previews(car_id, folder):
    """Renders a front-three-quarter and a rear-three-quarter view with Cycles on the CPU."""
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.42, 0.55, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.2
    scene.world = world
    ground = bpy.data.objects.new("Ground", bpy.data.meshes.new("Ground"))
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=2, y_segments=2, size=30.0)
    bm.to_mesh(ground.data)
    bm.free()
    ground.data.materials.append(make_material("GroundMat", (0.12, 0.12, 0.13), roughness=0.9))
    bpy.context.collection.objects.link(ground)
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 4.0
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.context.collection.objects.link(sun)
    camera_data = bpy.data.cameras.new("Cam")
    camera_data.lens = 45
    camera = bpy.data.objects.new("Cam", camera_data)
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    views = {"front": Vector((-5.6, -6.2, 1.9)), "rear": Vector((5.4, 6.4, 1.9))}
    for label, position in views.items():
        camera.location = position
        direction = Vector((0.0, 0.0, 0.55)) - position
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (car_id, label))
        bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--render", default="")
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for car_id, spec in CARS.items():
        if args.only and car_id != args.only:
            continue
        build_car(car_id, spec)
        triangles = count_triangles()
        export_glb(os.path.join(args.out, car_id + ".glb"))
        print("built %s: %d triangles" % (car_id, triangles))
        if args.render:
            render_previews(car_id, args.render)


if __name__ == "__main__":
    main()
