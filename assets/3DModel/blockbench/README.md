# Blockbench → Godot pipeline

Blockbench MCP builds chunky low-poly geometry (cubes + sphere meshes, one named
part per colour). gltf export from the MCP is broken (async → empty), so:

1. Build model in Blockbench (name parts by role: body / eye / mouth / blush / ...).
2. Export **OBJ** to this folder (`export_model` codec `obj`, with `path`).
3. Bridge to GLB with Blender — assigns a flat matte colour per part by name,
   bevels (relative to size) + smooth-shades, joins, exports GLB:

   blender --background --python bb_bridge.py -- <in.obj> <colormap.json> <out.glb> [bevel_frac]

   colormap.json: { "eye":"#22304a", "blush":"#f2a9a0", "_default":"#48CAE4" }
   Keyword matched against lowercased part name; `_default` is the fallback.
   bevel_frac ~0.05 normal, ~0.08 for soft "jelly" rounding.

4. Godot imports the GLB. In-game route it through MeshFit.fit_* + MeshFit.matte.

NOTE: Blockbench is Y-up (same as Godot) → import obj with up=Y / forward=-Z
(no axis rotation) or faces land on the wrong side.

Palette (artstyle.md): Wood #D4A373, Bamboo #8CB369, Jelly Water #48CAE4,
Stone #BDBDBD, Accent #E07A5F.
