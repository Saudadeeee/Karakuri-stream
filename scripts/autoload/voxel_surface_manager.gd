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
const SAMPLES_PER_CELL: int = 4
const MARGIN: float = 0.85
const REBUILD_INTERVAL: float = 0.05

var _groups: Dictionary = {}       # "wood:2" -> MeshInstance3D
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

	var spacing: float = GridManager.CELL_SIZE / float(SAMPLES_PER_CELL)
	var dims := Vector3i(
		int(ceil((region_max.x - region_min.x) / spacing)) + 1,
		int(ceil((region_max.y - region_min.y) / spacing)) + 1,
		int(ceil((region_max.z - region_min.z) / spacing)) + 1)

	var reach: float = HALF + ROUND_R
	var samples := PackedFloat32Array()
	samples.resize(dims.x * dims.y * dims.z)
	for z in dims.z:
		for y in dims.y:
			for x in dims.x:
				var p := region_min + Vector3(x, y, z) * spacing
				var d := 0.0
				for c in centers:
					var qx: float = absf(p.x - c.x)
					if qx >= reach:
						continue
					var qy: float = absf(p.y - c.y)
					if qy >= reach:
						continue
					var qz: float = absf(p.z - c.z)
					if qz >= reach:
						continue
					var ax: float = 1.0 - smoothstep(HALF - ROUND_R, HALF + ROUND_R, qx)
					var ay: float = 1.0 - smoothstep(HALF - ROUND_R, HALF + ROUND_R, qy)
					var az: float = 1.0 - smoothstep(HALF - ROUND_R, HALF + ROUND_R, qz)
					d += minf(ax, minf(ay, az))
				samples[x + y * dims.x + z * dims.x * dims.y] = d

	var mesh: ArrayMesh = IsoSurface.build(samples, dims, spacing, iso)
	if bake_ao and mesh != null and mesh.get_surface_count() > 0:
		mesh = _bake_vertex_ao(mesh, region_min)
	mi.mesh = mesh
	mi.position = region_min

## Cheap baked AO: for each vertex, count occupied grid cells at a handful of
## probe offsets around/above it — more neighbours = deeper crevice = darker
## vertex colour (the wood shader multiplies it in). Grid-dict lookups only,
## no field re-sampling, so a few thousand verts stay well under the rebuild
## throttle.
const AO_PROBES: Array[Vector3] = [
	Vector3(0, 0.7, 0),
	Vector3(0.7, 0.35, 0), Vector3(-0.7, 0.35, 0),
	Vector3(0, 0.35, 0.7), Vector3(0, 0.35, -0.7),
]

func _bake_vertex_ao(mesh: ArrayMesh, origin: Vector3) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		var wp: Vector3 = origin + verts[i]
		var occ := 0
		for p in AO_PROBES:
			if GridManager.has_block(GridManager.world_to_cell(wp + p)):
				occ += 1
		var ao: float = 1.0 - 0.16 * float(occ)
		colors[i] = Color(ao, ao, ao)
	arrays[Mesh.ARRAY_COLOR] = colors
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
