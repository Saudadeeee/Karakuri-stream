class_name IsoSurface
extends RefCounted

## Naive Surface Nets isosurface extractor. Chosen over classic Marching Cubes
## because it needs no 256-entry triangle table (far less transcription risk),
## produces smooth blobby quads that suit metaball water, and is cheap enough
## to rebuild whenever the water set changes. Density convention: a sample is
## "inside" the solid when its value is GREATER than `iso` (metaballs pile
## density up inside the blob).

# 8 cube corners as (x,y,z) bit offsets, corner i = (i&1, (i>>1)&1, (i>>2)&1).
const CORNER: Array[Vector3i] = [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
	Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1),
]

const SMOOTH_PASSES: int = 1
# Taubin smoothing: a shrink step (+lambda toward centroid) followed by an
# inflate step (-mu away from centroid, mu slightly larger). Plain Laplacian
# shrinks the mesh every pass — on thin merge necks that pulled faces apart and
# opened see-through gaps between blocks. Taubin smooths the scallop WITHOUT the
# net shrink, so merged blocks stay solid and watertight.
const SMOOTH_LAMBDA: float = 0.5
const SMOOTH_MU: float = 0.53

# 12 edges as corner-index pairs.
const EDGE: Array = [
	[0, 1], [2, 3], [4, 5], [6, 7], # along X
	[0, 2], [1, 3], [4, 6], [5, 7], # along Y
	[0, 4], [1, 5], [2, 6], [3, 7], # along Z
]

## samples: flat PackedFloat32Array, index = x + y*dims.x + z*dims.x*dims.y.
## Returns an ArrayMesh (with smooth normals) in local space; caller positions it.
static func build(samples: PackedFloat32Array, dims: Vector3i, cell_size: float, iso: float) -> ArrayMesh:
	var sx: int = dims.x
	var sy: int = dims.y
	var stride_y: int = sx
	var stride_z: int = sx * sy

	var vertices: PackedVector3Array = PackedVector3Array()
	var cell_index: Dictionary = {} # Vector3i cell -> vertex index

	# Pass 1 — one vertex per straddling cell, at the average of its edge crossings.
	for z in range(dims.z - 1):
		for y in range(dims.y - 1):
			for x in range(dims.x - 1):
				var vals: Array[float] = []
				var inside_count: int = 0
				for c in 8:
					var co: Vector3i = CORNER[c]
					var v: float = samples[(x + co.x) + (y + co.y) * stride_y + (z + co.z) * stride_z]
					vals.append(v)
					if v > iso:
						inside_count += 1
				if inside_count == 0 or inside_count == 8:
					continue

				var sum := Vector3.ZERO
				var crossings: int = 0
				for e in EDGE:
					var a: int = e[0]
					var b: int = e[1]
					var va: float = vals[a]
					var vb: float = vals[b]
					if (va > iso) == (vb > iso):
						continue
					var t: float = (iso - va) / (vb - va)
					var p: Vector3 = Vector3(CORNER[a]).lerp(Vector3(CORNER[b]), t)
					sum += p
					crossings += 1
				var local: Vector3 = sum / float(crossings)
				var world: Vector3 = (Vector3(x, y, z) + local) * cell_size
				cell_index[Vector3i(x, y, z)] = vertices.size()
				vertices.append(world)

	if vertices.is_empty():
		return ArrayMesh.new()

	# Pass 2 — for each grid edge that crosses, stitch the 4 surrounding cell
	# vertices into a quad. Only the three minimal edges from each cell's origin
	# corner are considered so every crossing edge is handled exactly once.
	var indices: PackedInt32Array = PackedInt32Array()
	var axis_dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
	for z in range(dims.z - 1):
		for y in range(dims.y - 1):
			for x in range(dims.x - 1):
				var cell := Vector3i(x, y, z)
				if not cell_index.has(cell):
					continue
				var base_idx: int = (x) + (y) * stride_y + (z) * stride_z
				var v0: float = samples[base_idx]
				for axis in 3:
					var d: Vector3i = axis_dirs[axis]
					var n: Vector3i = cell + d
					var v1: float = samples[(x + d.x) + (y + d.y) * stride_y + (z + d.z) * stride_z]
					if (v0 > iso) == (v1 > iso):
						continue
					# The 4 cells around this edge: current minus the two
					# perpendicular axis directions.
					var u: Vector3i = axis_dirs[(axis + 1) % 3]
					var w: Vector3i = axis_dirs[(axis + 2) % 3]
					var c0: Vector3i = cell
					var c1: Vector3i = cell - u
					var c2: Vector3i = cell - u - w
					var c3: Vector3i = cell - w
					if not (cell_index.has(c0) and cell_index.has(c1) and cell_index.has(c2) and cell_index.has(c3)):
						continue
					var i0: int = cell_index[c0]
					var i1: int = cell_index[c1]
					var i2: int = cell_index[c2]
					var i3: int = cell_index[c3]
					# Wind so the surface faces "outward" (toward lower density).
					if v0 > iso:
						indices.append_array([i0, i1, i2, i0, i2, i3])
					else:
						indices.append_array([i0, i3, i2, i0, i2, i1])

	if indices.is_empty():
		return ArrayMesh.new()

	# Laplacian smoothing — Surface Nets at a low sample rate leaves visible
	# facet "scalloping" on flat spans. A couple of passes pulling each vertex
	# toward the average of its edge-neighbours flattens that ripple into clean
	# gentle surfaces without changing the silhouette much. Cheap: builds the
	# adjacency once from the triangle list, then averages in place.
	_smooth(vertices, indices, SMOOTH_PASSES)

	# Smooth vertex normals = normalized sum of adjacent face normals.
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0, indices.size(), 3):
		var a: int = indices[i]
		var b: int = indices[i + 1]
		var c: int = indices[i + 2]
		var fn: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		normals[a] += fn
		normals[b] += fn
		normals[c] += fn
	for i in normals.size():
		var nrm: Vector3 = normals[i]
		normals[i] = nrm.normalized() if nrm.length_squared() > 0.0 else Vector3.UP

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## In-place Laplacian smoothing: each pass moves every vertex a fraction
## `factor` toward the centroid of its edge-connected neighbours. Adjacency is
## the set of vertices sharing a triangle edge (built once from `indices`).
static func _smooth(verts: PackedVector3Array, indices: PackedInt32Array, passes: int) -> void:
	if passes <= 0 or verts.is_empty():
		return
	# Neighbour sets (dedup via Dictionary key) per vertex.
	var adj: Array = []
	adj.resize(verts.size())
	for i in verts.size():
		adj[i] = {}
	for t in range(0, indices.size(), 3):
		var a: int = indices[t]
		var b: int = indices[t + 1]
		var c: int = indices[t + 2]
		adj[a][b] = true; adj[a][c] = true
		adj[b][a] = true; adj[b][c] = true
		adj[c][a] = true; adj[c][b] = true

	# 2 iterations per pass: shrink (+lambda) then inflate (-mu). Net ~volume-preserving.
	for it in passes * 2:
		var factor: float = SMOOTH_LAMBDA if (it % 2 == 0) else -SMOOTH_MU
		var moved := PackedVector3Array()
		moved.resize(verts.size())
		for i in verts.size():
			var neighbours: Dictionary = adj[i]
			if neighbours.is_empty():
				moved[i] = verts[i]
				continue
			var sum := Vector3.ZERO
			for n in neighbours:
				sum += verts[n]
			var centroid: Vector3 = sum / float(neighbours.size())
			moved[i] = verts[i].lerp(centroid, factor)
		for i in verts.size():
			verts[i] = moved[i]
