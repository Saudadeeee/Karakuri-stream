extends Node

## Renders Wood AND Water as smooth merged isosurfaces. Cells are grouped by
## (type, VARIANT) — each variant (wood/dirt/moss/stone, or the different water
## colours) fuses only with its own kind and gets its own coloured mesh, so a
## dirt pile and a wood pile sitting together stay distinct. The density field is
## an "union of rounded boxes": each cell fills its cube with soft edges and the
## fields SUM so neighbours merge into one solid mass.

## Timber and water are ONE shader with a `surface_mode` uniform. Two shaders
## meant two programs, and on gl_compatibility a program is compiled the first
## time it is drawn — through ANGLE that measured 7.8 seconds EACH from cold.
## See `shaders/surface.gdshader`.
const SURFACE_SHADER: Shader = preload("res://shaders/surface.gdshader")
const MODE_WOOD := 0
const MODE_WATER := 1

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
## Last built cell set per group. WaterFlowManager.flow_changed and every grid
## edit mark the whole manager dirty, but a rebuild only produces a DIFFERENT
## mesh when that group's cells changed — and re-solving an unchanged isosurface
## was costing a full frame every time water moved. Compare first, build second.
var _built: Dictionary = {}        # group key -> String signature
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

func _process(delta: float) -> void:
	if not _dirty:
		return
	_timer += delta
	if _timer < REBUILD_INTERVAL:
		return
	_timer = 0.0
	_dirty = false
	_rebuild_all()

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

	# rebuild present groups, free absent ones
	for key in groups.keys():
		var mi: MeshInstance3D = _groups.get(key)
		if mi == null:
			mi = MeshInstance3D.new()
			mi.material_override = _material_for(key)
			add_child(mi)
			_groups[key] = mi
		var iso: float = WATER_ISO if key.begins_with("water") else ISO
		_build(mi, groups[key], iso, key.begins_with("wood"))
	for key in _groups.keys():
		if not groups.has(key):
			_groups[key].queue_free()
			_groups.erase(key)

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
		mat.shader = SURFACE_SHADER
		mat.set_shader_parameter("surface_mode", MODE_WOOD)
		mat.set_shader_parameter("base_color", col)
		mat.set_shader_parameter("grain_color", col.darkened(0.28))
		mat.set_shader_parameter("grain_scale", 4.0)
		mat.set_shader_parameter("grain_strength", 0.15)
		mat.set_shader_parameter("rim_color", col.lightened(0.35))
		mat.set_shader_parameter("rim_power", 4.0)
		mat.set_shader_parameter("rim_strength", 0.26)
	else:
		mat.shader = SURFACE_SHADER
		mat.set_shader_parameter("surface_mode", MODE_WATER)
		mat.set_shader_parameter("water_color", Color(col.r, col.g, col.b, 1.0))
		var deep: Color = col.darkened(0.24)
		mat.set_shader_parameter("deep_color", Color(deep.r, deep.g, deep.b, 1.0))
	_materials[mkey] = mat
	return mat

# ------------------------------------------------------------- isosurface
func _build(mi: MeshInstance3D, centers: Array, iso: float, bake_ao: bool = false) -> void:
	if centers.is_empty():
		mi.mesh = null
		return
	var region_min: Vector3 = centers[0]
	var region_max: Vector3 = centers[0]
	for c in centers:
		region_min = region_min.min(c)
		region_max = region_max.max(c)
	region_min -= Vector3.ONE * MARGIN
	region_max += Vector3.ONE * MARGIN

	var spacing: float = GridManager.CELL_SIZE / float(_samples_per_cell())
	var dims := Vector3i(
		int(ceil((region_max.x - region_min.x) / spacing)) + 1,
		int(ceil((region_max.y - region_min.y) / spacing)) + 1,
		int(ceil((region_max.z - region_min.z) / spacing)) + 1)

	var reach: float = HALF + ROUND_R
	# LOOK UP the few cells near each sample instead of scanning them all.
	#
	# This loop used to test EVERY cell for EVERY sample point — O(samples x
	# cells) — and with 4 samples per cell the sample count grows with the
	# build's bounding box, so the two terms multiply as you build. Measured:
	#
	#     9 water cells          14.7 ms per rebuild
	#     + 25 wood               64.7 ms
	#     + 60 wood              177.7 ms
	#
	# on DESKTOP, against an 11 ms budget at 90 fps, re-run every time water
	# flows. That is the frame-rate drop.
	#
	# A cell only reaches `reach` (0.66) from its centre, so a sample can be
	# touched by at most a 2x2x2 neighbourhood. Indexing the cells and visiting
	# just those makes the cost per sample constant instead of proportional to
	# the build.
	var occ: Dictionary = {}
	for c in centers:
		occ[Vector3i(roundi(c.x), roundi(c.y - HALF), roundi(c.z))] = c

	var samples := PackedFloat32Array()
	samples.resize(dims.x * dims.y * dims.z)
	for z in dims.z:
		for y in dims.y:
			for x in dims.x:
				var p := region_min + Vector3(x, y, z) * spacing
				var d := 0.0
				# Cell centres sit at integer x/z and y+0.5, so these ranges hold
				# every cell whose field can reach p — at most two per axis.
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
				samples[x + y * dims.x + z * dims.x * dims.y] = d

	var mesh: ArrayMesh = IsoSurface.build(samples, dims, spacing, iso)
	if bake_ao and mesh != null and mesh.get_surface_count() > 0:
		mesh = _bake_vertex_ao(mesh, region_min)
	mi.mesh = mesh
	mi.position = region_min

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
	for i in verts.size():
		var wp: Vector3 = origin + verts[i]
		var n: Vector3 = norms[i].normalized() if have_normals else Vector3.UP
		var occ := 0
		for r in AO_RAYS:
			var probe: Vector3 = wp + (n + r).normalized() * AO_REACH
			if GridManager.has_block(GridManager.world_to_cell(probe)):
				occ += 1
		var ao: float = 1.0 - AO_BITE * float(occ)
		colors[i] = Color(ao, ao, ao)
	arrays[Mesh.ARRAY_COLOR] = colors
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
