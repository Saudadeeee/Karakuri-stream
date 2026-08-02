class_name MeshBatch
extends RefCounted

## Accumulates lots of little boxes into ONE ArrayMesh with one surface per
## colour, so a shape built from dozens of parts costs a handful of draw calls
## instead of dozens of nodes.
##
## Why this exists: a house cell is ~37 separate pieces (walls, window frames,
## panes, flower boxes, door, step, roof, ridge, chimney). As individual
## MeshInstance3D children that is ~37 draw calls EACH, and a twenty-house
## village would push 700+ — which is the number that actually hurts on the
## gl_compatibility web target, long before triangle count ever matters. Batched
## by colour it lands at four or five surfaces per cell no matter how much
## detail the shape grows.
##
## Triangles are emitted flat-shaded (a normal per face) to match the art style,
## and everything is baked in LOCAL space, so the caller positions one node.

var _verts: Dictionary = {}    # colour html -> PackedVector3Array
var _norms: Dictionary = {}    # colour html -> PackedVector3Array
var _colors: Dictionary = {}   # colour html -> Color

const _FACES: Array = [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
]

## A box, optionally rotated about its own centre.
func box(size: Vector3, pos: Vector3, col: Color, basis: Basis = Basis.IDENTITY) -> void:
	var h: Vector3 = size * 0.5
	for f in _FACES:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c: Vector3 = n * h
		var du: Vector3 = u * h
		var dv: Vector3 = v * h
		quad(pos + basis * (c - du - dv), pos + basis * (c + du - dv),
			pos + basis * (c + du + dv), pos + basis * (c - du + dv), col)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)

func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var key: String = col.to_html()
	if not _verts.has(key):
		_verts[key] = PackedVector3Array()
		_norms[key] = PackedVector3Array()
		_colors[key] = col
	var n: Vector3 = (b - a).cross(c - a)
	# Degenerate triangles (a zero-thickness slab folded flat) would produce a
	# NaN normal and blank the whole surface — drop them instead.
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var vs: PackedVector3Array = _verts[key]
	var ns: PackedVector3Array = _norms[key]
	vs.append(a); vs.append(b); vs.append(c)
	ns.append(n); ns.append(n); ns.append(n)
	_verts[key] = vs
	_norms[key] = ns

## Bake an arbitrary mesh's triangles into the batch, transformed into batch
## space. Lets shapes made of PRIMITIVES — the spheres and cylinders the animals
## are built from — join the same batch as the boxes, instead of each staying its
## own node and its own draw call.
func mesh(src: Mesh, xform: Transform3D, col: Color) -> void:
	for s in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(s)
		if arr.is_empty():
			continue
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() >= 3:
			for i in range(0, idx.size() - 2, 3):
				tri(xform * v[idx[i]], xform * v[idx[i + 1]], xform * v[idx[i + 2]], col)
		else:
			for i in range(0, v.size() - 2, 3):
				tri(xform * v[i], xform * v[i + 1], xform * v[i + 2], col)

func is_empty() -> bool:
	return _verts.is_empty()

## Bake into one mesh. `mat_for` is called once per colour so the caller can
## return a plain matte material, an emissive one for glass, and so on.
## ONE surface for the whole batch, colours carried per vertex.
##
## `build()` cuts a surface per colour, which is four or five draw calls for a
## house cell — fine for one house, 600 for a town of 120. Everything here shares
## one flat matte material, so the only reason for the split was the colour, and
## a vertex colour carries that for free: 120 draw calls instead of 600, and one
## material for the whole town instead of five per cell.
##
## `special` may return a Material for colours that genuinely need their own
## (the night window glow, which is emissive). Those keep a surface of their own.
##
## Colours are written into the vertex stream exactly as authored. Converting
## them to linear first (the usual advice) came out black on the compatibility
## renderer, which already treats a vertex colour the same way it treats an
## albedo colour.
func build_merged(shared: Material, special: Callable = Callable()) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for key in _verts:
		var col: Color = _colors[key]
		var mat: Variant = special.call(col) if special.is_valid() else null
		if mat != null:
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = _verts[key]
			arrays[Mesh.ARRAY_NORMAL] = _norms[key]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat as Material)
			continue
		verts.append_array(_verts[key])
		norms.append_array(_norms[key])
		for _i in (_verts[key] as PackedVector3Array).size():
			cols.append(col)
	if not verts.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, shared)
	return mesh

func build(mat_for: Callable) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var i := 0
	for key in _verts:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts[key]
		arrays[Mesh.ARRAY_NORMAL] = _norms[key]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(i, mat_for.call(_colors[key] as Color))
		i += 1
	return mesh
