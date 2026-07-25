extends Node

## Ambient scenery ringing the floating island — pines, bushes, reeds, rocks,
## a lantern, a bonsai, a THEME FEATURE TREE (sakura / maple / snow pine /
## lantern) — plus a distant ring of backdrop mountains. Everything is
## recoloured per map theme (MapThemes): foliage lerps to the theme colour and
## mountains take the theme tint, so each map reads differently at a glance.
## `rebuild()` re-places it all — called at startup and when the menu switches
## theme. Purely decorative backdrop; never touches the block grid.

const PINE := preload("res://assets/3DModel/generated/pine_tree.glb")
const BUSH := preload("res://assets/3DModel/generated/bush.glb")
const REEDS := preload("res://assets/3DModel/generated/reeds.glb")
const ROCKS := preload("res://assets/3DModel/generated/rock_cluster.glb")
const LANTERN := preload("res://assets/3DModel/generated/lantern.glb")
const BONSAI := preload("res://assets/3DModel/generated/bonsai.glb")
const SAKURA := preload("res://assets/3DModel/generated/sakura_tree.glb")
const MOUNTAIN := preload("res://assets/3DModel/generated/mountain.glb")

## (scene_key, angle°, radius, height). "feature" resolves per theme.
const PROPS: Array = [
	["pine", 20.0, 7.2, 1.9],
	["feature", 45.0, 7.7, 2.5],
	["bush", 65.0, 7.6, 0.9],
	["rocks", 110.0, 7.4, 0.9],
	["reeds", 150.0, 7.0, 1.5],
	["lantern", 195.0, 7.5, 1.7],
	["bush", 235.0, 7.3, 0.8],
	["feature", 258.0, 7.7, 2.3],
	["pine", 285.0, 7.6, 1.6],
	["bonsai", 315.0, 7.1, 1.1],
	["rocks", 345.0, 7.5, 0.8],
]

## Distant backdrop mountains: (angle°, radius, height, y).
const MOUNTAINS: Array = [
	[10.0, 34.0, 26.0, -12.0], [55.0, 40.0, 20.0, -11.0],
	[95.0, 32.0, 30.0, -13.0], [140.0, 38.0, 22.0, -11.0],
	[185.0, 36.0, 27.0, -12.5], [230.0, 42.0, 19.0, -10.0],
	[275.0, 33.0, 29.0, -13.0], [320.0, 39.0, 23.0, -11.0],
]

## Rim props sit on grid cells the player can build over. When a block lands on
## a prop's cell, the prop SHATTERS (a puff of its own leaves/wood) instead of
## clipping through the new block.
var _prop_cells: Dictionary = {}   # Vector3i -> {root:Node3D, kind:String}

func _ready() -> void:
	MapThemes.load_current()
	GridManager.block_placed.connect(_on_block_placed)
	# Defer so the main scene (ground/island) exists first.
	rebuild.call_deferred()

## Wipe + re-place everything for the CURRENT theme.
func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_prop_cells.clear()
	var t: Dictionary = MapThemes.theme()
	for p in PROPS:
		_place_ring_model(_scene_for(p[0], t), deg_to_rad(p[1]), p[2], p[3], 0.0, t, false, p[0])
	for m in MOUNTAINS:
		_place_ring_model(MOUNTAIN, deg_to_rad(m[0]), m[1], m[2], m[3], t, true)

## A block was placed — if it lands on a rim prop's cell, shatter that prop.
func _on_block_placed(cell: Vector3i) -> void:
	if _prop_cells.has(cell):
		var e: Dictionary = _prop_cells[cell]
		_prop_cells.erase(cell)
		if is_instance_valid(e["root"]):
			_shatter(e["root"], e["kind"])

## Topple + shrink the prop while a coloured puff bursts from it, then free it —
## foliage sheds leaves, rocks pop grey chips, lanterns/bonsai shed wood.
func _shatter(root: Node3D, kind: String) -> void:
	var pos: Vector3 = root.global_position + Vector3(0, 0.35, 0)
	var tint := Color(0.5, 0.68, 0.36)                     # leaf green default
	if kind == "rocks":
		tint = Color(0.72, 0.72, 0.7)
	elif kind == "lantern" or kind == "bonsai":
		tint = Color(0.72, 0.55, 0.36)
	burst(pos, tint)
	AudioManager.play_wood_pitch(pos, 1.35, -4.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "rotation:z", randf_range(-1.1, 1.1), 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)

## Public: a small coloured leaf/chip puff (DecorManager reuses it for the
## flowers/sprouts a placed block buries).
func burst(pos: Vector3, tint: Color) -> void:
	var p := GPUParticles3D.new()
	p.amount = QualityManager.particles(14)
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.95
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 75.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 2.4
	mat.gravity = Vector3(0, -3.2, 0)
	mat.angular_velocity_min = -220.0
	mat.angular_velocity_max = 220.0
	mat.scale_min = 0.05
	mat.scale_max = 0.11
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.albedo_color = tint
	qm.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = qm
	p.draw_pass_1 = quad
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func _scene_for(key: String, t: Dictionary) -> PackedScene:
	match key:
		"pine": return PINE
		"bush": return BUSH
		"reeds": return REEDS
		"rocks": return ROCKS
		"lantern": return LANTERN
		"bonsai": return BONSAI
		"feature":
			match t["feature"]:
				"sakura": return SAKURA
				"maple": return PINE      # pine silhouette, maple-orange foliage
				"lantern": return LANTERN
				_: return PINE
	return PINE

func _place_ring_model(scene: PackedScene, ang: float, radius: float, height: float, y: float, t: Dictionary, is_mountain: bool = false, kind: String = "") -> void:
	var model: Node3D = scene.instantiate()
	# Wrapper: MeshFit.local_aabb treats the queried root's own transform as
	# identity, so any straightening rotation must live on a CHILD (the model)
	# and the fit must run on the wrapper for the rotation to count.
	var holder := Node3D.new()
	holder.add_child(model)
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(cos(ang) * radius, y, sin(ang) * radius)
	root.rotation.y = ang
	root.add_child(holder)
	# The lantern GLB is authored lying on its side — stand it up before fitting
	# (a standing lantern is TALLER than wide; wider-than-tall = fallen).
	if scene == LANTERN:
		var box: AABB = MeshFit.local_aabb(holder)
		if box.size.y < maxf(box.size.x, box.size.z) * 0.9:
			# Long side may run along X or Z — rotate about the other axis.
			if box.size.x >= box.size.z:
				model.rotation.z = PI / 2.0
			else:
				model.rotation.x = PI / 2.0
	MeshFit.fit_bottom(holder, height, 0.0)
	MeshFit.matte(holder)
	if is_mountain:
		var tint: Color = t["mountain_tint"]
		if tint != Color(1, 1, 1):
			_tint_all(holder, tint)
	else:
		MeshFit.recolor_foliage(holder, t["foliage"])
		# Register the on-island prop's cell so a block placed here shatters it.
		_prop_cells[GridManager.world_to_cell(root.position)] = {"root": root, "kind": kind}

## Multiply every surface's albedo (mountains take the theme haze tint).
func _tint_all(root: Node, mul: Color) -> void:
	for node in root.get_children():
		_tint_all(node, mul)
	if not (root is MeshInstance3D):
		return
	var mi: MeshInstance3D = root
	if mi.mesh == null:
		return
	for s in range(mi.mesh.get_surface_count()):
		var m: Material = mi.get_active_material(s)
		if m is StandardMaterial3D:
			var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
			d.albedo_color = Color(d.albedo_color.r * mul.r, d.albedo_color.g * mul.g, d.albedo_color.b * mul.b, d.albedo_color.a)
			mi.set_surface_override_material(s, d)
