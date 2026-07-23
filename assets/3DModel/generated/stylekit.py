"""Karakuri Stream — Blender style kit. Implements artstyle.md master prompt:
chunky+beveled low-poly, auto-smooth, matte flat diffuse (roughness 1), strict
pastel palette, fits a 2x2x2 grid. Shared by gen_assets.py."""
import bpy, bmesh, math

# --- strict palette (sRGB hex from artstyle.md) ---
def _srgb_to_linear(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def hexc(h):
    h = h.lstrip("#")
    return (_srgb_to_linear(int(h[0:2], 16)),
            _srgb_to_linear(int(h[2:4], 16)),
            _srgb_to_linear(int(h[4:6], 16)), 1.0)

WOOD   = hexc("D4A373")
BAMBOO = hexc("8CB369")
WATER  = hexc("48CAE4")
STONE  = hexc("BDBDBD")
ACCENT = hexc("E07A5F")
PAPER  = hexc("F2E9D8")   # lantern paper (warm off-white, derived)
LEAF_D = hexc("6E9350")   # darker bamboo-green for depth

_mat_cache = {}
def mat(color):
    key = tuple(round(x, 4) for x in color)
    if key in _mat_cache:
        return _mat_cache[key]
    m = bpy.data.materials.new("m")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.1
    _mat_cache[key] = m
    return m

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mat_cache.clear()

# --- primitive builders (each links into the active scene) ---
def _link(me, name):
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

def cyl(r, h, seg=20, name="cyl"):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                          radius1=r, radius2=r, depth=h)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return _link(me, name)

def cone(r1, r2, h, seg=20, name="cone"):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                          radius1=r1, radius2=r2, depth=h)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return _link(me, name)

def box(sx, sy, sz, name="box"):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return _link(me, name)

def ico(r, subd=2, name="ico"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subd, radius=r)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return _link(me, name)

def uvsphere(r, seg=16, rings=8, name="sph"):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return _link(me, name)

def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob

# --- finishing: bevel 0.05/seg2 + auto-smooth, apply modifiers ---
def finish(ob, bevel=0.05, angle=35.0):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    b = ob.modifiers.new("bevel", 'BEVEL')
    b.width = bevel; b.segments = 2; b.limit_method = 'ANGLE'
    b.angle_limit = math.radians(30)
    bpy.ops.object.modifier_apply(modifier="bevel")
    bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))

def set_mat(ob, color):
    ob.data.materials.clear()
    ob.data.materials.append(mat(color))

def export(ob, path):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                              use_selection=True)
    print("EXPORTED", path)
