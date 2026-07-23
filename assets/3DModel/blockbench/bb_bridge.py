"""Blockbench OBJ -> Godot GLB bridge.
Imports a Blockbench-exported .obj (chunky low-poly, per-part `o` groups),
assigns a flat matte material to each part by matching its name against a JSON
colour map (part-name keyword -> hex), applies a small bevel + smooth shading
(the artstyle look), and exports an optimized .glb for Godot.

Usage: blender --background --python bb_bridge.py -- <in.obj> <colormap.json> <out.glb>
"""
import bpy, sys, json, math, os

argv = sys.argv[sys.argv.index("--") + 1:]
OBJ, CMAP_PATH, OUT = argv[0], argv[1], argv[2]

with open(CMAP_PATH) as f:
    cmap = json.load(f)   # { "keyword": "#RRGGBB", ..., "_default": "#RRGGBB" }

def srgb_to_lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def hex_lin(h):
    h = h.lstrip("#")
    return (srgb_to_lin(int(h[0:2], 16)), srgb_to_lin(int(h[2:4], 16)), srgb_to_lin(int(h[4:6], 16)), 1.0)

def color_for(name):
    n = name.lower()
    for key, hx in cmap.items():
        if key != "_default" and key in n:
            return hx
    return cmap.get("_default", "#CCCCCC")

# Bevel as a fraction of overall model size (optional 4th arg overrides).
BEVEL_FRAC = float(argv[3]) if len(argv) > 3 else 0.05

bpy.ops.wm.read_factory_settings(use_empty=True)
# Blockbench is Y-up like Godot — import with NO axis rotation so a face on the
# Blockbench front (+Z) stays on the front in Godot (not rotated onto the top).
bpy.ops.wm.obj_import(filepath=OBJ, forward_axis='NEGATIVE_Z', up_axis='Y')

mats = {}
def get_mat(hx):
    if hx in mats:
        return mats[hx]
    m = bpy.data.materials.new(hx)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hex_lin(hx)
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.12
    mats[hx] = m
    return m

objs = [o for o in bpy.data.objects if o.type == 'MESH']

# Overall size → absolute bevel width, so rounding looks the same whatever units
# Blockbench exported in.
lo = [1e9, 1e9, 1e9]; hi = [-1e9, -1e9, -1e9]
for o in objs:
    for v in o.bound_box:
        wv = o.matrix_world @ __import__("mathutils").Vector(v)
        for i in range(3):
            lo[i] = min(lo[i], wv[i]); hi[i] = max(hi[i], wv[i])
max_dim = max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
bevel_w = max(0.001, max_dim * BEVEL_FRAC)

for o in objs:
    hx = color_for(o.name)
    o.data.materials.clear()
    o.data.materials.append(get_mat(hx))
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True); bpy.context.view_layer.objects.active = o
    bev = o.modifiers.new("bevel", 'BEVEL')
    bev.width = bevel_w; bev.segments = 3; bev.limit_method = 'ANGLE'; bev.angle_limit = math.radians(35)
    bpy.ops.object.modifier_apply(modifier="bevel")
    bpy.ops.object.shade_auto_smooth(angle=math.radians(40))

# join all parts into one mesh for a single tidy glb
bpy.ops.object.select_all(action='DESELECT')
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.join()

bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False)
print("BRIDGE_DONE", OUT)
