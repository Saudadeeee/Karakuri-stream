extends Node

const GROW_TIME: float = 10.0
const FLAG_HEIGHT_THRESHOLD: int = 5
const GRASS_TUFT: PackedScene = preload("res://assets/3DModel/generated/grass_tuft.glb")

var _timers: Dictionary = {} # Vector3i -> float elapsed
var _has_moss: Dictionary = {} # Vector3i -> true
var _has_flag: Dictionary = {} # Vector3i -> true
var _flag_data: Array = [] # [{node, phase}]
var _grass_data: Array = [] # [{node, phase, base_y}] — gentle wind sway

## Townscaper-style "life finds a way": EVERY wood block with an open top face
## quietly sprouts a little something after a while (flower, pebbles, sprout) —
## so whatever the player piles up decorates itself. Removed the moment a block
## is stacked on top.
var _top_timers: Dictionary = {}  # Vector3i -> float remaining
var _top_decor: Dictionary = {}   # Vector3i -> Node3D (or null = rolled no-decor)

func _ready() -> void:
	GridManager.block_placed.connect(_on_grid_changed)
	GridManager.block_removed.connect(_on_grid_changed)
	GridManager.grid_cleared.connect(_on_grid_cleared)

## A change at `cell` can only affect moss/flag status on `cell` itself
## (if it's Wood) or on a Wood neighbor whose water-adjacency just changed
## — never on wood elsewhere in the grid, so there's no need to rescan every
## Wood block in the build on every single placement/removal.
func _on_grid_changed(cell: Vector3i) -> void:
	_check_wood_cell(cell)
	for dir in GridManager.DIRECTIONS:
		_check_wood_cell(cell + dir)

## Moss/flag nodes are children of the Wood block itself, so
## GridManager.clear_all() already frees them — just drop our bookkeeping.
func _on_grid_cleared() -> void:
	_timers.clear()
	_has_moss.clear()
	_has_flag.clear()
	_flag_data.clear()
	_grass_data.clear()
	_top_timers.clear()
	_top_decor.clear()

func _check_wood_cell(cell: Vector3i) -> void:
	var block: BlockData = GridManager.get_block(cell)
	if block == null or block.type != BlockData.Type.WOOD:
		_timers.erase(cell)
		return

	if not _has_moss.has(cell):
		var near_water := false
		for neighbor in GridManager.get_neighbors(cell).values():
			if neighbor.type == BlockData.Type.WATER:
				near_water = true
				break
		if near_water:
			if not _timers.has(cell):
				_timers[cell] = 0.0
		else:
			_timers.erase(cell)

	if not _has_flag.has(cell) and cell.y > FLAG_HEIGHT_THRESHOLD:
		_spawn_flag(cell)

	# Open-top sprouting: start (or cancel) this wood cell's little garden.
	var top_free: bool = not GridManager.has_block(cell + Vector3i(0, 1, 0))
	if top_free:
		if not _top_decor.has(cell) and not _top_timers.has(cell):
			_top_timers[cell] = randf_range(5.0, 13.0)
	else:
		_top_timers.erase(cell)
		if _top_decor.has(cell):
			var d = _top_decor[cell]
			if d != null and is_instance_valid(d):
				d.queue_free()
			_top_decor.erase(cell)

func _process(delta: float) -> void:
	for cell in _timers.keys():
		_timers[cell] += delta
		if _timers[cell] >= GROW_TIME:
			_spawn_moss(cell)
			_timers.erase(cell)

	for cell in _top_timers.keys():
		_top_timers[cell] -= delta
		if _top_timers[cell] <= 0.0:
			_top_timers.erase(cell)
			# 45%: a tiny flower / pebble pair / sprout. 55%: stays bare (null
			# marks the roll as done so it never re-rolls).
			_top_decor[cell] = _spawn_top_decor(cell) if randf() < 0.45 else null

	var t: float = Time.get_ticks_msec() / 1000.0
	for flag in _flag_data:
		if not is_instance_valid(flag["node"]):
			continue
		flag["node"].rotation.z = sin(t * 2.0 + flag["phase"]) * 0.3

	# Grass leans gently back and forth like a soft breeze passing through.
	for g in _grass_data:
		if not is_instance_valid(g["node"]):
			continue
		var ph: float = g["phase"]
		g["node"].rotation.z = sin(t * 1.3 + ph) * 0.08
		g["node"].rotation.x = cos(t * 1.1 + ph) * 0.06

## One small prop on the open top face, grown in with a scale tween. Parented
## to the wood block's node so removal frees it automatically.
func _spawn_top_decor(cell: Vector3i) -> Node3D:
	var block: BlockData = GridManager.get_block(cell)
	if block == null or not is_instance_valid(block.node):
		return null
	var root := Node3D.new()
	root.position = Vector3(randf_range(-0.24, 0.24), 0.5, randf_range(-0.24, 0.24))
	root.rotation.y = randf_range(0.0, TAU)
	root.scale = Vector3.ZERO
	block.node.add_child(root)

	match randi() % 3:
		0:  # little flower: stem + warm head + two leaves
			var stem := _cyl(root, 0.015, 0.16, Color(0.42, 0.56, 0.3), Vector3(0, 0.08, 0))
			var head := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.05; s.height = 0.09; s.radial_segments = 7; s.rings = 4
			head.mesh = s
			head.material_override = _flat([Color(0.93, 0.55, 0.55), Color(0.95, 0.75, 0.4), Color(0.85, 0.6, 0.85)].pick_random())
			head.position = Vector3(0, 0.18, 0)
			root.add_child(head)
			stem.rotation.z = randf_range(-0.12, 0.12)
		1:  # pebble pair
			for i in 2:
				var p := MeshInstance3D.new()
				var ps := SphereMesh.new()
				var r: float = randf_range(0.05, 0.09)
				ps.radius = r; ps.height = r * 1.2; ps.radial_segments = 7; ps.rings = 4
				p.mesh = ps
				p.material_override = _flat(Color(0.72, 0.72, 0.7).lerp(Color(0.6, 0.62, 0.6), randf()))
				p.position = Vector3(randf_range(-0.08, 0.08), 0.02, randf_range(-0.08, 0.08))
				root.add_child(p)
		2:  # fresh sprout: two tiny leaning leaves
			for i in 2:
				var leaf := _cyl(root, 0.02, 0.14, Color(0.5, 0.68, 0.36), Vector3(0.03 * (i * 2 - 1), 0.07, 0))
				leaf.rotation.z = 0.35 * (i * 2 - 1)

	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root

func _cyl(parent: Node3D, r: float, h: float, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r; c.bottom_radius = r * 1.3; c.height = h; c.radial_segments = 6
	mi.mesh = c
	mi.material_override = _flat(col)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _flat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	return m

func _spawn_moss(cell: Vector3i) -> void:
	var block: BlockData = GridManager.get_block(cell)
	if block == null or not is_instance_valid(block.node):
		return
	_has_moss[cell] = true

	# A styled grass tuft (art model) sprouting on the wood, with a couple of
	# low mossy blobs at its base for fuzz. Grows in via the scale tween.
	var clump := Node3D.new()
	clump.position = Vector3(randf_range(-0.2, 0.2), 0.5, randf_range(-0.2, 0.2))
	clump.scale = Vector3.ZERO
	block.node.add_child(clump)

	var grass: Node3D = GRASS_TUFT.instantiate()
	clump.add_child(grass)
	MeshFit.fit_bottom(grass, randf_range(0.38, 0.58), 0.0)
	MeshFit.matte(grass)
	grass.rotation.y = randf_range(0.0, TAU)
	_grass_data.append({"node": grass, "phase": randf_range(0.0, TAU)})

	for i in randi_range(2, 3):
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r: float = randf_range(0.09, 0.14)
		sphere.radius = r
		sphere.height = r * 1.3
		sphere.radial_segments = 7
		sphere.rings = 4
		blob.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.24, 0.4, 0.18).lerp(Color(0.36, 0.5, 0.26), randf())
		material.roughness = 1.0
		blob.material_override = material
		blob.position = Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
		clump.add_child(blob)

	var tween: Tween = create_tween()
	tween.tween_property(clump, "scale", Vector3.ONE, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Small pennant on a pole, auto-attached to Wood at high altitude (Y>5).
## Sways with a sine wave in _process — a stand-in for a true wind shader.
func _spawn_flag(cell: Vector3i) -> void:
	var block: BlockData = GridManager.get_block(cell)
	if block == null or not is_instance_valid(block.node):
		return
	_has_flag[cell] = true

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.02
	pole_mesh.bottom_radius = 0.02
	pole_mesh.height = 0.4
	pole.mesh = pole_mesh
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.3, 0.22, 0.12)
	pole.material_override = pole_material
	pole.position = Vector3(0.4, 0.7, 0.4)
	block.node.add_child(pole)

	var flag := MeshInstance3D.new()
	var flag_mesh := PlaneMesh.new()
	flag_mesh.size = Vector2(0.3, 0.18)
	flag.mesh = flag_mesh
	var flag_material := StandardMaterial3D.new()
	flag_material.albedo_color = Color(0.85, 0.25, 0.2)
	flag_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag.material_override = flag_material
	flag.position = Vector3(0.15, 0.15, 0.0)
	flag.rotation.y = PI * 0.5
	pole.add_child(flag)

	_flag_data.append({"node": flag, "phase": randf_range(0.0, TAU)})
