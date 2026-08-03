extends Node

## A soft dark patch under everything that stands on the ground.
##
## The compatibility renderer has no SSAO — no screen-space anything — so where
## an object meets the ground there was simply nothing: no darkening, no occluded
## crease, just two flat colours meeting at a hard edge. That is the single
## strongest reason the game read as plastic toys sitting on a plastic lawn. The
## sun's cast shadow is not the same cue: it is offset, it disappears when a
## block is in another shadow, and it says nothing about CONTACT.
##
## One mesh for the whole island, rebuilt on a throttle like the other grid
## managers, so a garden of hundreds of blocks costs ONE transparent draw call.
## Each patch is an 8-sided fan whose rim is fully transparent, which is the
## cheapest way to get a round falloff without a texture.

const RING: int = 8
const RADIUS: float = 0.72        # wider than a cell: contact shade spreads
const LIFT: float = 0.012         # above the ground, or it z-fights the lawn
const CENTRE_ALPHA: float = 0.34
const REBUILD_INTERVAL: float = 0.12

var _mesh: MeshInstance3D
var _dirty: bool = true
var _since: float = 0.0

func _ready() -> void:
	GridManager.block_placed.connect(func(_c: Vector3i) -> void: _dirty = true)
	GridManager.block_removed.connect(func(_c: Vector3i) -> void: _dirty = true)
	GridManager.grid_cleared.connect(func() -> void: _dirty = true)

func _process(delta: float) -> void:
	_since += delta
	if not _dirty or _since < REBUILD_INTERVAL:
		return
	_since = 0.0
	_dirty = false
	_rebuild()

func _rebuild() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.queue_free()
	_mesh = null

	# Only the lowest block of each column, and only where it rests on something:
	# a patch under a stacked block is hidden by the block below it, and a house
	# on stilts is not touching anything to cast contact shade onto.
	var lowest: Dictionary = {}    # Vector2i(x,z) -> min y
	for cell in GridManager.get_all_cells():
		var key := Vector2i(cell.x, cell.z)
		if not lowest.has(key) or cell.y < int(lowest[key]):
			lowest[key] = cell.y
	if lowest.is_empty():
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint: Color = _shade_colour()
	var rim := Color(tint.r, tint.g, tint.b, 0.0)
	var any := false
	for key in lowest:
		var cell := Vector3i(int(key.x), int(lowest[key]), int(key.y))
		if cell.y > 0 and not GridManager.has_block(cell + Vector3i(0, -1, 0)):
			continue   # floating: nothing under it to darken
		# The BOTTOM of the cell. cell_to_world returns its CENTRE, at (y + 0.5) —
		# subtracting 0.5 from the cell INDEX instead put every patch half a unit
		# under the island, where the only ones that showed were the few standing
		# over a dip in the terrain.
		var at: Vector3 = GridManager.cell_to_world(cell)
		at.y -= 0.5 * GridManager.CELL_SIZE
		at.y += LIFT
		for i in RING:
			var a: float = TAU * float(i) / float(RING)
			var b: float = TAU * float(i + 1) / float(RING)
			st.set_color(tint)
			st.add_vertex(at)
			st.set_color(rim)
			st.add_vertex(at + Vector3(cos(a), 0.0, sin(a)) * RADIUS)
			st.set_color(rim)
			st.add_vertex(at + Vector3(cos(b), 0.0, sin(b)) * RADIUS)
		any = true
	if not any:
		return

	_mesh = MeshInstance3D.new()
	_mesh.mesh = st.commit()
	_mesh.material_override = _material()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_mesh)

## Contact shade is not black — it is the ground in its own shadow. Taking the
## colour from the map theme keeps a snow island's shade blue and an autumn one's
## warm, instead of dropping a grey stain on both.
func _shade_colour() -> Color:
	var t: Dictionary = MapThemes.theme()
	var base: Color = t["island_base"]
	return Color(base.r * 0.55, base.g * 0.55, base.b * 0.6, CENTRE_ALPHA)

func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# No depth write: these are decals lying ON the ground and must never occlude
	# the things standing in them.
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m
