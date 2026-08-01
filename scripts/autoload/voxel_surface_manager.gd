extends Node

## Renders Wood AND Water as smooth merged isosurfaces. Cells are grouped by
## (type, VARIANT) — each variant (wood/dirt/moss/stone, or the different water
## colours) fuses only with its own kind and gets its own coloured mesh, so a
## dirt pile and a wood pile sitting together stay distinct. The density field is
## an "union of rounded boxes": each cell fills its cube with soft edges and the
## fields SUM so neighbours merge into one solid mass.

const WOOD_SHADER: Shader = preload("res://shaders/wood.gdshader")
const WATER_SHADER: Shader = preload("res://shaders/water.gdshader")

const HALF: float = 0.5
const ROUND_R: float = 0.16
const ISO: float = 0.5             # wood: surface exactly on the cell face
const WATER_ISO: float = 0.4       # water inflates down a touch to cover the seam on wood
## Samples per cell along each axis, so cost scales with the CUBE of this. The
## web LITE profile takes 3 (0.42x the work) — the merged blobs get very slightly
## softer corners, which at this art style is invisible next to the frame it buys.
const SAMPLES_PER_CELL: int = 4
const SAMPLES_PER_CELL_LITE: int = 3
const MARGIN: float = 0.85
const REBUILD_INTERVAL: float = 0.05

var _groups: Dictionary = {}       # "wood:2" -> MeshInstance3D
## Cell-set signature per group; rebuilds are skipped when a group's cells
## did not change (water reveal ticks must not re-solve the wood).
var _built: Dictionary = {}        # group key -> int signature
## Cached density field per group. An edit only disturbs samples within its
## cell's reach (~0.66), so the field is patched around the edit; a spacing
## change invalidates, outgrowing the box regrows (copy + fresh slabs).
var _field_cache: Dictionary = {}  # group key -> {min, dims, spacing, samples, occ}
const MAX_LOCAL_EDITS: int = 16
var _materials: Dictionary = {}    # "wood:#hex" -> ShaderMaterial
var _dirty: bool = true
var _timer: float = 0.0

func _ready() -> void:
	GridManager.block_placed.connect(_on_changed)
	GridManager.block_removed.connect(_on_changed)
	GridManager.grid_cleared.connect(_on_changed)
	WaterFlowManager.flow_changed.connect(_on_changed)

func _on_changed(_a = null) -> void:
	_dirty = true

## The solve runs as a worker coroutine yielding every ~4.5 ms of work and
## commits the mesh atomically — the old mesh stays up while the new one is
## being built, so nothing flickers.
const BUILD_BUDGET_USEC: int = 4500
var _running: bool = false

func _process(delta: float) -> void:
	if not _dirty or _running:
		return
	_timer += delta
	if _timer < REBUILD_INTERVAL:
		return
	_timer = 0.0
	_running = true
	_worker()

func _worker() -> void:
	# Consume-and-loop: mid-flight edits do not restart the solve (continuous
	# water flow would starve it) — the snapshot finishes and commits, then
	# the worker goes again with the newest state.
	while true:
		_dirty = false
		await _rebuild_all()
		if not _dirty:
			break
	_running = false

func _samples_per_cell() -> int:
	return SAMPLES_PER_CELL_LITE if QualityManager.lite else SAMPLES_PER_CELL

# ------------------------------------------------------------- grouping
func _variant_of(cell: Vector3i) -> int:
	var b: BlockData = GridManager.get_block(cell)
	return int(b.state.get("variant", 0)) if b != null else 0

func _rebuild_all() -> void:
	# key -> Array[Vector3] world centres
	var groups: Dictionary = {}
	for cell in GridManager.get_all_cells_of_type(BlockData.Type.WOOD):
		_add(groups, "wood:%d" % _variant_of(cell), GridManager.cell_to_world(cell))
	for cell in GridManager.get_all_cells_of_type(BlockData.Type.WATER):
		_add(groups, "water:%d" % _variant_of(cell), GridManager.cell_to_world(cell))
	for cell in WaterFlowManager._active_flows:
		_add(groups, "water:0", GridManager.cell_to_world(cell))

	# Rebuild present groups (skipping unchanged cell sets), free absent ones.
	for key in groups.keys():
		var sig: int = _signature(groups[key])
		if _groups.has(key) and int(_built.get(key, 0)) == sig:
			continue
		var mi: MeshInstance3D = _groups.get(key)
		if mi == null:
			mi = MeshInstance3D.new()
			mi.material_override = _material_for(key)
			add_child(mi)
			_groups[key] = mi
		var iso: float = WATER_ISO if key.begins_with("water") else ISO
		await _build(key, mi, groups[key], iso, key.begins_with("wood"))
		_built[key] = sig
	for key in _groups.keys():
		if not groups.has(key):
			_groups[key].queue_free()
			_groups.erase(key)
			_built.erase(key)
			_field_cache.erase(key)

## Order-independent set signature: count + wrapped sum of per-cell hashes.
func _signature(centers: Array) -> int:
	var h: int = centers.size()
	for c in centers:
		h = (h + hash(Vector3i(roundi(c.x * 2.0), roundi(c.y * 2.0), roundi(c.z * 2.0)))) \
			& 0x7FFFFFFFFFFFFFF
	return h

func _add(groups: Dictionary, key: String, pos: Vector3) -> void:
	if not groups.has(key):
		groups[key] = []
	groups[key].append(pos)

# ------------------------------------------------------------- materials
func _material_for(key: String) -> ShaderMaterial:
	var parts: Array = key.split(":")
	var type: int = BlockData.Type.WOOD if parts[0] == "wood" else BlockData.Type.WATER
	var variant: int = int(parts[1])
	var col: Color = BlockVariants.color_of(type, variant)
	var mkey: String = "%s:%s" % [parts[0], col.to_html()]
	if _materials.has(mkey):
		return _materials[mkey]
	var mat := ShaderMaterial.new()
	if parts[0] == "wood":
		mat.shader = WOOD_SHADER
		mat.set_shader_parameter("base_color", col)
		mat.set_shader_parameter("grain_color", col.darkened(0.28))
		mat.set_shader_parameter("grain_scale", 4.0)
		mat.set_shader_parameter("grain_strength", 0.15)
		mat.set_shader_parameter("rim_color", col.lightened(0.35))
		mat.set_shader_parameter("rim_power", 4.0)
		mat.set_shader_parameter("rim_strength", 0.26)
	else:
		mat.shader = WATER_SHADER
		mat.set_shader_parameter("water_color", Color(col.r, col.g, col.b, 1.0))
		var deep: Color = col.darkened(0.24)
		mat.set_shader_parameter("deep_color", Color(deep.r, deep.g, deep.b, 1.0))
	_materials[mkey] = mat
	return mat

# ------------------------------------------------------------- isosurface
func _build(key: String, mi: MeshInstance3D, centers: Array, iso: float, bake_ao: bool = false) -> void:
	if centers.is_empty():
		mi.mesh = null
		_field_cache.erase(key)
		return

	var spacing: float = GridManager.CELL_SIZE / float(_samples_per_cell())
	var reach: float = HALF + ROUND_R

	# LOOK UP the few cells near each sample instead of scanning them all: a
	# cell only reaches `reach` (0.66) from its centre, so a sample is touched
	# by at most a 2x2x2 neighbourhood of cells.
	var occ: Dictionary = {}
	for c in centers:
		occ[Vector3i(roundi(c.x), roundi(c.y - HALF), roundi(c.z))] = c

	var req_min: Vector3 = centers[0]
	var req_max: Vector3 = centers[0]
	for c in centers:
		req_min = req_min.min(c)
		req_max = req_max.max(c)
	req_min -= Vector3.ONE * MARGIN
	req_max += Vector3.ONE * MARGIN

	# Field reuse tiers:
	#   fits + few edits     -> patch the zones around changed cells
	#   outgrown + few edits -> grow the box, copy overlap, sample fresh slabs
	#   otherwise            -> full resample (first build, load, clear)
	var region_min: Vector3
	var dims: Vector3i
	var samples: PackedFloat32Array
	var reused := false
	var cache: Dictionary = _field_cache.get(key, {})
	if not cache.is_empty() and is_equal_approx(float(cache["spacing"]), spacing):
		var changed: Array = _changed_cells(occ, cache["occ"])
		if changed.size() <= MAX_LOCAL_EDITS:
			var c_min: Vector3 = cache["min"]
			var c_dims: Vector3i = cache["dims"]
			var c_max: Vector3 = c_min + Vector3(c_dims - Vector3i.ONE) * spacing
			if _contains(c_min, c_max, req_min, req_max):
				region_min = c_min
				dims = c_dims
				samples = cache["samples"]
				for c in changed:
					_patch_zone(samples, region_min, dims, spacing, occ, c, reach)
				reused = true
			else:
				var grown: Dictionary = await _grow_field(cache, req_min, req_max, spacing, occ, reach)
				if not grown.is_empty():
					region_min = grown["min"]
					dims = grown["dims"]
					samples = grown["samples"]
					for c in changed:
						_patch_zone(samples, region_min, dims, spacing, occ, c, reach)
					reused = true

	if not reused:
		region_min = req_min
		dims = Vector3i(
			int(ceil((req_max.x - req_min.x) / spacing)) + 1,
			int(ceil((req_max.y - req_min.y) / spacing)) + 1,
			int(ceil((req_max.z - req_min.z) / spacing)) + 1)
		samples = PackedFloat32Array()
		samples.resize(dims.x * dims.y * dims.z)
		var deadline: int = Time.get_ticks_usec() + BUILD_BUDGET_USEC
		for z in dims.z:
			if Time.get_ticks_usec() > deadline:
				await get_tree().process_frame
				deadline = Time.get_ticks_usec() + BUILD_BUDGET_USEC
			for y in dims.y:
				var row: int = y * dims.x + z * dims.x * dims.y
				for x in dims.x:
					samples[x + row] = _density(region_min + Vector3(x, y, z) * spacing, occ, reach)

	_field_cache[key] = {
		"min": region_min, "dims": dims, "spacing": spacing,
		"samples": samples, "occ": occ,
	}

	var mesh: ArrayMesh = await IsoSurface.build_async(samples, dims, spacing, iso, BUILD_BUDGET_USEC)
	if bake_ao and mesh != null and mesh.get_surface_count() > 0:
		mesh = await _bake_vertex_ao(mesh, region_min)
	if not is_instance_valid(mi):
		return
	mi.mesh = mesh
	mi.position = region_min

## Union-of-rounded-boxes density at one point. Cell centres sit at integer
## x/z and y+0.5, so the index ranges hold every cell whose field can reach p —
## at most two per axis.
func _density(p: Vector3, occ: Dictionary, reach: float) -> float:
	var d := 0.0
	var x0: int = ceili(p.x - reach)
	var x1: int = floori(p.x + reach)
	var y0: int = ceili(p.y - reach - HALF)
	var y1: int = floori(p.y + reach - HALF)
	var z0: int = ceili(p.z - reach)
	var z1: int = floori(p.z + reach)
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			for cz in range(z0, z1 + 1):
				var c = occ.get(Vector3i(cx, cy, cz))
				if c == null:
					continue
				var ax: float = 1.0 - smoothstep(HALF - ROUND_R, HALF + ROUND_R, absf(p.x - c.x))
				var ay: float = 1.0 - smoothstep(HALF - ROUND_R, HALF + ROUND_R, absf(p.y - c.y))
				var az: float = 1.0 - smoothstep(HALF - ROUND_R, HALF + ROUND_R, absf(p.z - c.z))
				d += minf(ax, minf(ay, az))
	return d

func _changed_cells(occ: Dictionary, old_occ: Dictionary) -> Array:
	var changed: Array = []
	for k in occ:
		if not old_occ.has(k):
			changed.append(occ[k])
	for k in old_occ:
		if not occ.has(k):
			changed.append(old_occ[k])
	return changed

func _contains(a_min: Vector3, a_max: Vector3, b_min: Vector3, b_max: Vector3) -> bool:
	return a_min.x <= b_min.x + 0.001 and a_min.y <= b_min.y + 0.001 and a_min.z <= b_min.z + 0.001 \
		and a_max.x >= b_max.x - 0.001 and a_max.y >= b_max.y - 0.001 and a_max.z >= b_max.z - 0.001

## Recompute every sample within one cell's reach from the current occupancy
## (recompute, not add/subtract — no accumulated drift).
func _patch_zone(samples: PackedFloat32Array, region_min: Vector3, dims: Vector3i,
		spacing: float, occ: Dictionary, c: Vector3, reach: float) -> void:
	var pad: float = reach + spacing
	var ix0: int = clampi(floori((c.x - pad - region_min.x) / spacing), 0, dims.x - 1)
	var ix1: int = clampi(ceili((c.x + pad - region_min.x) / spacing), 0, dims.x - 1)
	var iy0: int = clampi(floori((c.y - pad - region_min.y) / spacing), 0, dims.y - 1)
	var iy1: int = clampi(ceili((c.y + pad - region_min.y) / spacing), 0, dims.y - 1)
	var iz0: int = clampi(floori((c.z - pad - region_min.z) / spacing), 0, dims.z - 1)
	var iz1: int = clampi(ceili((c.z + pad - region_min.z) / spacing), 0, dims.z - 1)
	for z in range(iz0, iz1 + 1):
		for y in range(iy0, iy1 + 1):
			var row: int = y * dims.x + z * dims.x * dims.y
			for x in range(ix0, ix1 + 1):
				samples[x + row] = _density(region_min + Vector3(x, y, z) * spacing, occ, reach)

## Grow the cached field box to cover [req_min, req_max]: allocate the union
## box, row-copy the old samples, sample fresh only where the box is new.
## Returns {} when the lattices don't align (fall back to a full resample —
## a misaligned copy shows as geometry corruption).
func _grow_field(cache: Dictionary, req_min: Vector3, req_max: Vector3,
		spacing: float, occ: Dictionary, reach: float) -> Dictionary:
	var c_min: Vector3 = cache["min"]
	var c_dims: Vector3i = cache["dims"]
	var c_max: Vector3 = c_min + Vector3(c_dims - Vector3i.ONE) * spacing
	var n_min: Vector3 = c_min.min(req_min)
	var n_max: Vector3 = c_max.max(req_max)
	var dims := Vector3i(
		int(ceil((n_max.x - n_min.x) / spacing)) + 1,
		int(ceil((n_max.y - n_min.y) / spacing)) + 1,
		int(ceil((n_max.z - n_min.z) / spacing)) + 1)
	var offf: Vector3 = (c_min - n_min) / spacing
	var off := Vector3i(roundi(offf.x), roundi(offf.y), roundi(offf.z))
	if absf(offf.x - off.x) > 0.01 or absf(offf.y - off.y) > 0.01 or absf(offf.z - off.z) > 0.01:
		return {}
	var old: PackedFloat32Array = cache["samples"]
	var samples := PackedFloat32Array()
	var deadline: int = Time.get_ticks_usec() + BUILD_BUDGET_USEC
	for z in dims.z:
		if Time.get_ticks_usec() > deadline:
			await get_tree().process_frame
			deadline = Time.get_ticks_usec() + BUILD_BUDGET_USEC
		var oz: int = z - off.z
		for y in dims.y:
			var oy: int = y - off.y
			if oz < 0 or oz >= c_dims.z or oy < 0 or oy >= c_dims.y:
				for x in dims.x:
					samples.append(_density(n_min + Vector3(x, y, z) * spacing, occ, reach))
				continue
			var old_row: int = oy * c_dims.x + oz * c_dims.x * c_dims.y
			for x in range(0, off.x):
				samples.append(_density(n_min + Vector3(x, y, z) * spacing, occ, reach))
			samples.append_array(old.slice(old_row, old_row + c_dims.x))
			for x in range(off.x + c_dims.x, dims.x):
				samples.append(_density(n_min + Vector3(x, y, z) * spacing, occ, reach))
	return {"min": n_min, "dims": dims, "samples": samples}

## Cheap baked AO: for each vertex, look OUTWARD along its own normal and count
## how much solid is in the way. A vertex on an open face sees nothing and stays
## bright; one down a crevice between two blocks is blocked from several
## directions and darkens.
##
## Outward is the whole point. This used to probe a fixed set of offsets — up,
## and four sideways — which on any flat surface just walked into the block's own
## neighbours. Every vertex of a plain wooden deck came back with the same three
## hits, so the "occlusion" was a CONSTANT 0.52: no crevice detail whatsoever,
## and a flat 22% darkening of everything. That is why a wooden deck rendered as
## a chocolate-brown hole in the lawn instead of warm timber — measured by
## dumping COLOR.r straight to ALBEDO, which came back an even grey.
## Three rays, not seven. Every ray is a dictionary lookup per VERTEX, and the
## isosurface has thousands of them: measured on an 80-block deck, baking cost
## 19 ms of the 74 ms that one block placement took. Three still tells a crevice
## from an open face, which is all this is for.
const AO_RAYS: Array[Vector3] = [
	Vector3(0, 0, 0),                            # straight out
	Vector3(0.7, 0.4, 0), Vector3(-0.7, -0.4, 0),  # and a wide pair either side
]
const AO_REACH: float = 0.85
const AO_BITE: float = 0.20   # darkening per blocked ray, of three

func _bake_vertex_ao(mesh: ArrayMesh, origin: Vector3) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	var have_normals: bool = norms.size() == verts.size()
	var deadline: int = Time.get_ticks_usec() + BUILD_BUDGET_USEC
	var i: int = 0
	var total: int = verts.size()
	while i < total:
		var stop: int = mini(i + 2000, total)
		while i < stop:
			var wp: Vector3 = origin + verts[i]
			var n: Vector3 = norms[i].normalized() if have_normals else Vector3.UP
			var occ := 0
			for r in AO_RAYS:
				var probe: Vector3 = wp + (n + r).normalized() * AO_REACH
				if GridManager.has_block(GridManager.world_to_cell(probe)):
					occ += 1
			var ao: float = 1.0 - AO_BITE * float(occ)
			colors[i] = Color(ao, ao, ao)
			i += 1
		if i < total and Time.get_ticks_usec() > deadline:
			await get_tree().process_frame
			deadline = Time.get_ticks_usec() + BUILD_BUDGET_USEC
	arrays[Mesh.ARRAY_COLOR] = colors
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
