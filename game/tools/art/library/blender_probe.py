# blender -b --factory-startup --disable-autoexec -P blender_probe.py -- <model> [model ...]
# Prints the size of each model, its objects (type, parent, parent bone), armatures and every animation action.
import bpy, sys, os, mathutils
args = sys.argv[sys.argv.index('--') + 1:]
for path in args:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = os.path.splitext(path)[1].lower()
    if ext in ('.glb', '.gltf'): bpy.ops.import_scene.gltf(filepath=path)
    elif ext == '.fbx': bpy.ops.import_scene.fbx(filepath=path)
    elif ext == '.obj': bpy.ops.wm.obj_import(filepath=path)
    elif ext == '.blend':
        with bpy.data.libraries.load(path, link=False) as (src, dst): dst.objects = src.objects
        for o in dst.objects:
            if o is not None: bpy.context.scene.collection.objects.link(o)
    lo = mathutils.Vector((1e9,) * 3); hi = mathutils.Vector((-1e9,) * 3)
    for o in bpy.context.scene.objects:
        if o.type != 'MESH': continue
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            lo = mathutils.Vector(map(min, lo, w)); hi = mathutils.Vector(map(max, hi, w))
    arms = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    print('MODEL', os.path.basename(path), 'size', [round(v, 2) for v in (hi - lo)], 'min', [round(v, 2) for v in lo], 'arm', [(a.name, len(a.data.bones)) for a in arms])
    if os.environ.get('OBJECTS'):
        for o in bpy.context.scene.objects:
            print('  OBJ', o.type, o.name, 'parent', o.parent.name if o.parent else None, o.parent_bone or '', 'mats', [m.name for m in getattr(o.data, 'materials', [])][:3])
        for a in arms: print('  BONES', [b.name for b in a.data.bones])
    for a in bpy.data.actions: print('  ACTION', a.name, tuple(round(v) for v in a.frame_range))
