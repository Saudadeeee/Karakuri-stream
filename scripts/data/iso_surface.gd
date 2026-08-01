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

## Time-sliced variant of build(): identical output, yields whenever
## `budget_usec` of work has accumulated. KEEP THE MATH IN SYNC WITH build()
## — tools/isohash.gd verifies both produce the same mesh.
static func build_async(samples: PackedFloat32Array, dims: Vector3i, cell_size: float,
		iso: float, budget_usec: int) -> ArrayMesh:
	var tree: SceneTree = Engine.get_main_loop()
	var deadline: int = Time.get_ticks_usec() + budget_usec
	var stride_y: int = dims.x
	var stride_z: int = dims.x * dims.y

	var vertices: PackedVector3Array = PackedVector3Array()
	var cell_index: Dictionary = {}

	# Pass 1 — vertices. Checkpoint per z-slab.
	for z in range(dims.z - 1):
		if Time.get_ticks_usec() > deadline:
			await tree.process_frame
			deadline = Time.get_ticks_usec() + budget_usec
		for y in range(dims.y - 1):
			var row0: int = y * stride_y + z * stride_z
			var row1: int = row0 + stride_y
			var row2: int = row0 + stride_z
			var row3: int = row1 + stride_z
			for x in range(dims.x - 1):
				var v0: float = samples[x + row0]
				var v1: float = samples[x + 1 + row0]
				var v2: float = samples[x + row1]
				var v3: float = samples[x + 1 + row1]
				var v4: float = samples[x + row2]
				var v5: float = samples[x + 1 + row2]
				var v6: float = samples[x + row3]
				var v7: float = samples[x + 1 + row3]
				var b0: bool = v0 > iso
				var b1: bool = v1 > iso
				var b2: bool = v2 > iso
				var b3: bool = v3 > iso
				var b4: bool = v4 > iso
				var b5: bool = v5 > iso
				var b6: bool = v6 > iso
				var b7: bool = v7 > iso
				if b0 == b1 and b0 == b2 and b0 == b3 and b0 == b4 \
						and b0 == b5 and b0 == b6 and b0 == b7:
					continue
				var sum := Vector3.ZERO
				var crossings: int = 0
				var t: float
				if b0 != b1:
					t = (iso - v0) / (v1 - v0)
					sum += Vector3(t, 0.0, 0.0); crossings += 1
				if b2 != b3:
					t = (iso - v2) / (v3 - v2)
					sum += Vector3(t, 1.0, 0.0); crossings += 1
				if b4 != b5:
					t = (iso - v4) / (v5 - v4)
					sum += Vector3(t, 0.0, 1.0); crossings += 1
				if b6 != b7:
					t = (iso - v6) / (v7 - v6)
					sum += Vector3(t, 1.0, 1.0); crossings += 1
				if b0 != b2:
					t = (iso - v0) / (v2 - v0)
					sum += Vector3(0.0, t, 0.0); crossings += 1
				if b1 != b3:
					t = (iso - v1) / (v3 - v1)
					sum += Vector3(1.0, t, 0.0); crossings += 1
				if b4 != b6:
					t = (iso - v4) / (v6 - v4)
					sum += Vector3(0.0, t, 1.0); crossings += 1
				if b5 != b7:
					t = (iso - v5) / (v7 - v5)
					sum += Vector3(1.0, t, 1.0); crossings += 1
				if b0 != b4:
					t = (iso - v0) / (v4 - v0)
					sum += Vector3(0.0, 0.0, t); crossings += 1
				if b1 != b5:
					t = (iso - v1) / (v5 - v1)
					sum += Vector3(1.0, 0.0, t); crossings += 1
				if b2 != b6:
					t = (iso - v2) / (v6 - v2)
					sum += Vector3(0.0, 1.0, t); crossings += 1
				if b3 != b7:
					t = (iso - v3) / (v7 - v3)
					sum += Vector3(1.0, 1.0, t); crossings += 1
				var local: Vector3 = sum / float(crossings)
				cell_index[Vector3i(x, y, z)] = vertices.size()
				vertices.append((Vector3(x, y, z) + local) * cell_size)

	if vertices.is_empty():
		return ArrayMesh.new()

	# Pass 2 — quads. Checkpoint per z-slab.
	var indices: PackedInt32Array = PackedInt32Array()
	var axis_dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
	for z in range(dims.z - 1):
		if Time.get_ticks_usec() > deadline:
			await tree.process_frame
			deadline = Time.get_ticks_usec() + budget_usec
		for y in range(dims.y - 1):
			for x in range(dims.x - 1):
				var cell := Vector3i(x, y, z)
				if not cell_index.has(cell):
					continue
				var v0: float = samples[x + y * stride_y + z * stride_z]
				for axis in 3:
					var d: Vector3i = axis_dirs[axis]
					var v1: float = samples[(x + d.x) + (y + d.y) * stride_y + (z + d.z) * stride_z]
					if (v0 > iso) == (v1 > iso):
						continue
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
					if v0 > iso:
						indices.append_array([i0, i1, i2, i0, i2, i3])
					else:
						indices.append_array([i0, i3, i2, i0, i2, i1])

	if indices.is_empty():
		return ArrayMesh.new()

	# Smoothing — mirror of _smooth() with budget checkpoints. Same adjacency,
	# same order, same result.
	var n_verts: int = vertices.size()
	var nbr := PackedInt32Array()
	nbr.resize(n_verts * MAX_VALENCE)
	var nbr_count := PackedInt32Array()
	nbr_count.resize(n_verts)
	var tri_count: int = indices.size()
	var ti: int = 0
	while ti < tri_count:
		var stop: int = mini(ti + 6000, tri_count)
		while ti < stop:
			var a: int = indices[ti]
			var b: int = indices[ti + 1]
			var c: int = indices[ti + 2]
			_add_neighbor(nbr, nbr_count, a, b); _add_neighbor(nbr, nbr_count, a, c)
			_add_neighbor(nbr, nbr_count, b, a); _add_neighbor(nbr, nbr_count, b, c)
			_add_neighbor(nbr, nbr_count, c, a); _add_neighbor(nbr, nbr_count, c, b)
			ti += 3
		if ti < tri_count and Time.get_ticks_usec() > deadline:
			await tree.process_frame
			deadline = Time.get_ticks_usec() + budget_usec
	for it in SMOOTH_PASSES * 2:
		var factor: float = SMOOTH_LAMBDA if (it % 2 == 0) else -SMOOTH_MU
		var moved := PackedVector3Array()
		moved.resize(n_verts)
		var vi: int = 0
		while vi < n_verts:
			var vstop: int = mini(vi + 4000, n_verts)
			while vi < vstop:
				var count: int = nbr_count[vi]
				if count == 0:
					moved[vi] = vertices[vi]
					vi += 1
					continue
				var vsum := Vector3.ZERO
				var vbase: int = vi * MAX_VALENCE
				for s in count:
					vsum += vertices[nbr[vbase + s]]
				moved[vi] = vertices[vi].lerp(vsum / float(count), factor)
				vi += 1
			if vi < n_verts and Time.get_ticks_usec() > deadline:
				await tree.process_frame
				deadline = Time.get_ticks_usec() + budget_usec
		for i in n_verts:
			vertices[i] = moved[i]

	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(n_verts)
	var ni: int = 0
	while ni < tri_count:
		var nstop: int = mini(ni + 9000, tri_count)
		while ni < nstop:
			var a: int = indices[ni]
			var b: int = indices[ni + 1]
			var c: int = indices[ni + 2]
			var fn: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			normals[a] += fn
			normals[b] += fn
			normals[c] += fn
			ni += 3
		if ni < tri_count and Time.get_ticks_usec() > deadline:
			await tree.process_frame
			deadline = Time.get_ticks_usec() + budget_usec
	for i in n_verts:
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

## samples: flat PackedFloat32Array, index = x + y*dims.x + z*dims.x*dims.y.
## Returns an ArrayMesh (with smooth normals) in local space; caller positions it.
static func build(samples: PackedFloat32Array, dims: Vector3i, cell_size: float, iso: float) -> ArrayMesh:
	var sx: int = dims.x
	var sy: int = dims.y
	var stride_y: int = sx
	var stride_z: int = sx * sy

	var vertices: PackedVector3Array = PackedVector3Array()
	var cell_index: Dictionary = {} # Vector3i cell -> vertex index

	# Pass 1 — one vertex per straddling cell, at the average of its edge
	# crossings. Hand-unrolled hot loop: locals + explicit edges, no per-cell
	# allocation. Output is bit-identical to the table-driven form
	# (tools/isohash.gd).
	for z in range(dims.z - 1):
		for y in range(dims.y - 1):
			var row0: int = y * stride_y + z * stride_z
			var row1: int = row0 + stride_y
			var row2: int = row0 + stride_z
			var row3: int = row1 + stride_z
			for x in range(dims.x - 1):
				# Corner i = (i&1, (i>>1)&1, (i>>2)&1), same numbering as CORNER.
				var v0: float = samples[x + row0]
				var v1: float = samples[x + 1 + row0]
				var v2: float = samples[x + row1]
				var v3: float = samples[x + 1 + row1]
				var v4: float = samples[x + row2]
				var v5: float = samples[x + 1 + row2]
				var v6: float = samples[x + row3]
				var v7: float = samples[x + 1 + row3]
				var b0: bool = v0 > iso
				var b1: bool = v1 > iso
				var b2: bool = v2 > iso
				var b3: bool = v3 > iso
				var b4: bool = v4 > iso
				var b5: bool = v5 > iso
				var b6: bool = v6 > iso
				var b7: bool = v7 > iso
				if b0 == b1 and b0 == b2 and b0 == b3 and b0 == b4 \
						and b0 == b5 and b0 == b6 and b0 == b7:
					continue

				# Edge order matches the EDGE table — float sums are
				# order-sensitive.
				var sum := Vector3.ZERO
				var crossings: int = 0
				var t: float
				if b0 != b1:
					t = (iso - v0) / (v1 - v0)
					sum += Vector3(t, 0.0, 0.0); crossings += 1
				if b2 != b3:
					t = (iso - v2) / (v3 - v2)
					sum += Vector3(t, 1.0, 0.0); crossings += 1
				if b4 != b5:
					t = (iso - v4) / (v5 - v4)
					sum += Vector3(t, 0.0, 1.0); crossings += 1
				if b6 != b7:
					t = (iso - v6) / (v7 - v6)
					sum += Vector3(t, 1.0, 1.0); crossings += 1
				if b0 != b2:
					t = (iso - v0) / (v2 - v0)
					sum += Vector3(0.0, t, 0.0); crossings += 1
				if b1 != b3:
					t = (iso - v1) / (v3 - v1)
					sum += Vector3(1.0, t, 0.0); crossings += 1
				if b4 != b6:
					t = (iso - v4) / (v6 - v4)
					sum += Vector3(0.0, t, 1.0); crossings += 1
				if b5 != b7:
					t = (iso - v5) / (v7 - v5)
					sum += Vector3(1.0, t, 1.0); crossings += 1
				if b0 != b4:
					t = (iso - v0) / (v4 - v0)
					sum += Vector3(0.0, 0.0, t); crossings += 1
				if b1 != b5:
					t = (iso - v1) / (v5 - v1)
					sum += Vector3(1.0, 0.0, t); crossings += 1
				if b2 != b6:
					t = (iso - v2) / (v6 - v2)
					sum += Vector3(0.0, 1.0, t); crossings += 1
				if b3 != b7:
					t = (iso - v3) / (v7 - v3)
					sum += Vector3(1.0, 1.0, t); crossings += 1
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
	# Neighbour sets per vertex in one flat buffer (16 slots + count array).
	# A nested packed array would pay copy-on-write per append. Insertion
	# order is preserved — the centroid float-sum order must not change.
	var n_verts: int = verts.size()
	var nbr := PackedInt32Array()
	nbr.resize(n_verts * MAX_VALENCE)
	var nbr_count := PackedInt32Array()
	nbr_count.resize(n_verts)
	for t in range(0, indices.size(), 3):
		var a: int = indices[t]
		var b: int = indices[t + 1]
		var c: int = indices[t + 2]
		_add_neighbor(nbr, nbr_count, a, b); _add_neighbor(nbr, nbr_count, a, c)
		_add_neighbor(nbr, nbr_count, b, a); _add_neighbor(nbr, nbr_count, b, c)
		_add_neighbor(nbr, nbr_count, c, a); _add_neighbor(nbr, nbr_count, c, b)

	# 2 iterations per pass: shrink (+lambda) then inflate (-mu). Net ~volume-preserving.
	for it in passes * 2:
		var factor: float = SMOOTH_LAMBDA if (it % 2 == 0) else -SMOOTH_MU
		var moved := PackedVector3Array()
		moved.resize(n_verts)
		for i in n_verts:
			var count: int = nbr_count[i]
			if count == 0:
				moved[i] = verts[i]
				continue
			var sum := Vector3.ZERO
			var base: int = i * MAX_VALENCE
			for s in count:
				sum += verts[nbr[base + s]]
			var centroid: Vector3 = sum / float(count)
			moved[i] = verts[i].lerp(centroid, factor)
		for i in n_verts:
			verts[i] = moved[i]

const MAX_VALENCE: int = 16

static func _add_neighbor(nbr: PackedInt32Array, nbr_count: PackedInt32Array, a: int, b: int) -> void:
	var base: int = a * MAX_VALENCE
	var count: int = nbr_count[a]
	for s in count:
		if nbr[base + s] == b:
			return
	if count >= MAX_VALENCE:
		push_error("IsoSurface._smooth: vertex valence exceeded %d" % MAX_VALENCE)
		return
	nbr[base + count] = b
	nbr_count[a] = count + 1
