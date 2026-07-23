extends Node

const WATER_SHADER: Shader = preload("res://shaders/water.gdshader")

const CARDINAL_DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## Falling cells (the actual cascade) get a generous budget — it's naturally
## bounded by height anyway. Sideways-pooling cells get a smaller one, so a
## source over open flat ground forms a bounded pool instead of flooding
## forever — but every open direction is still tried (see below), so if the
## player blocks one path the water actually finds another, like real water.
const MAX_FALL_CELLS: int = 60
const MAX_POOL_CELLS: int = 24

## How long between revealing each new step of a flow path — water should
## trickle down bit by bit, not pop into existence all at once the instant
## a source can reach that cell.
const REVEAL_INTERVAL: float = 0.09

var _active_flows: Dictionary = {} # Vector3i -> MeshInstance3D
var _source_audio: Dictionary = {} # Vector3i (source cell) -> AudioStreamPlayer3D

## BFS discovery order of the most recently computed flow (Vector3i -> from_dir).
## Dictionaries preserve insertion order in GDScript, so iterating this in
## order IS the BFS order — that's what makes the staggered reveal look like
## water actually traveling outward/downward instead of a random pop-in.
var _last_flow_cells: Dictionary = {}
var _reveal_queue: Array[Vector3i] = []
var _reveal_timer: float = 0.0

func _ready() -> void:
	GridManager.block_placed.connect(_on_grid_changed)
	GridManager.block_removed.connect(_on_grid_changed)
	GridManager.grid_cleared.connect(_on_grid_cleared)

func _on_grid_changed(_cell: Vector3i) -> void:
	_refresh()

## Flow segments and their loop players are children of THIS node, not of
## any block — GridManager.clear_all() can't free them for us, so drop them
## explicitly instead of leaving stale dict entries pointing at freed cells.
func _on_grid_cleared() -> void:
	for node in _active_flows.values():
		if is_instance_valid(node):
			node.queue_free()
	_active_flows.clear()
	for player in _source_audio.values():
		if is_instance_valid(player):
			player.queue_free()
	_source_audio.clear()
	_reveal_queue.clear()
	_last_flow_cells.clear()
	_reveal_timer = 0.0

## A water cell "spills" when it's the top of its stack (nothing above it)
## and elevated (y>0) — matches a fountain source or the top of a filled pool.
func _get_spill_sources() -> Array[Vector3i]:
	var sources: Array[Vector3i] = []
	for cell in GridManager.get_all_cells_of_type(BlockData.Type.WATER):
		var above: Vector3i = cell + Vector3i(0, 1, 0)
		if cell.y > 0 and not GridManager.has_block(above):
			sources.append(cell)
	return sources

## BFS from every spill source through empty space: prefer falling straight
## down, and once blocked, flood outward into open neighbors at that level
## (so it pools/cascades instead of stopping dead). Returns cell -> the
## direction it was reached from, used to orient the flow-streak shader.
func _compute_flow_cells() -> Dictionary:
	var flow_cells: Dictionary = {}
	var sources: Array[Vector3i] = _get_spill_sources()
	var visited: Dictionary = {}
	for s in sources:
		visited[s] = true

	var queue: Array = sources.duplicate()
	var fall_count := 0
	var pool_count := 0
	while queue.size() > 0:
		var current: Vector3i = queue.pop_front()
		var below: Vector3i = current + Vector3i(0, -1, 0)
		if current.y > 0 and not GridManager.has_block(below) and not visited.has(below):
			if fall_count >= MAX_FALL_CELLS:
				continue
			visited[below] = true
			flow_cells[below] = Vector3i(0, -1, 0)
			fall_count += 1
			queue.append(below)
		else:
			# Real water doesn't commit to one side and give up when that
			# path gets blocked — it presses into every open direction, so
			# blocking one route just makes it find another.
			for dir in CARDINAL_DIRS:
				if pool_count >= MAX_POOL_CELLS:
					break
				var side: Vector3i = current + dir
				if GridManager.has_block(side) or visited.has(side):
					continue
				visited[side] = true
				flow_cells[side] = dir
				pool_count += 1
				queue.append(side)
	return flow_cells

func _process(delta: float) -> void:
	if _reveal_queue.is_empty():
		return
	_reveal_timer += delta
	while _reveal_timer >= REVEAL_INTERVAL and not _reveal_queue.is_empty():
		_reveal_timer -= REVEAL_INTERVAL
		var cell: Vector3i = _reveal_queue.pop_front()
		if _last_flow_cells.has(cell) and not _active_flows.has(cell):
			_add_segment(cell, _last_flow_cells[cell])

func _refresh() -> void:
	var flow_cells: Dictionary = _compute_flow_cells()
	_last_flow_cells = flow_cells

	for cell in _active_flows.keys():
		if not flow_cells.has(cell):
			_remove_segment(cell)

	# Drop queued reveals that a grid change mid-trickle has invalidated.
	_reveal_queue = _reveal_queue.filter(func(c): return flow_cells.has(c) and not _active_flows.has(c))

	for cell in flow_cells:
		if _active_flows.has(cell) or _reveal_queue.has(cell):
			continue
		_reveal_queue.append(cell)

	_refresh_source_audio()

func _add_segment(cell: Vector3i, from_dir: Vector3i) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh_instance.mesh = box
	mesh_instance.position = GridManager.cell_to_world(cell)

	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("flow_amount", 1.0)
	material.set_shader_parameter("foam_width", 0.04)
	if from_dir == Vector3i(0, -1, 0):
		material.set_shader_parameter("flow_dir", Vector2(0.0, 1.0))
	else:
		material.set_shader_parameter("flow_dir", Vector2(from_dir.x, from_dir.z))
	mesh_instance.material_override = material

	add_child(mesh_instance)
	_active_flows[cell] = mesh_instance

	# Soft "a drop arrives" pop: start thin/short and swell to full so each
	# newly revealed step reads as water reaching that cell, not blinking on.
	mesh_instance.scale = Vector3(0.4, 0.1, 0.4)
	var tween: Tween = create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Splash where a falling stream lands on something solid (a block below,
	# or the ground at y=0) — the moment water "hits" and would spray.
	var below: Vector3i = cell + Vector3i(0, -1, 0)
	if from_dir == Vector3i(0, -1, 0) and (cell.y == 0 or GridManager.has_block(below)):
		_spawn_splash(mesh_instance.position + Vector3(0.0, -0.5, 0.0))

func _spawn_splash(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.position = pos

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 45.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3(0.0, -3.0, 0.0)
	mat.scale_min = 0.04
	mat.scale_max = 0.08
	# Round droplet that shrinks to nothing (scale-to-0) as it falls back.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = curve
	mat.scale_curve = scale_curve
	particles.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.radial_segments = 6
	sphere.rings = 3
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.9, 0.97, 0.95)
	drop_mat.emission_enabled = true
	drop_mat.emission = Color(0.7, 0.9, 0.88)
	drop_mat.emission_energy_multiplier = 0.2
	sphere.material = drop_mat
	particles.draw_pass_1 = sphere

	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)

func _remove_segment(cell: Vector3i) -> void:
	var node: MeshInstance3D = _active_flows[cell]
	if is_instance_valid(node):
		node.queue_free()
	_active_flows.erase(cell)

func _refresh_source_audio() -> void:
	var sources: Dictionary = {}
	for s in _get_spill_sources():
		sources[s] = true

	for cell in _source_audio.keys():
		if not sources.has(cell):
			var player: AudioStreamPlayer3D = _source_audio[cell]
			if is_instance_valid(player):
				player.queue_free()
			_source_audio.erase(cell)

	for cell in sources:
		if not _source_audio.has(cell):
			var player: AudioStreamPlayer3D = AudioManager.make_water_loop_player()
			player.position = GridManager.cell_to_world(cell)
			add_child(player)
			player.play()
			_source_audio[cell] = player
