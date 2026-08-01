extends Node

## Tracks which empty cells are currently "wet" from flowing water. It no
## longer renders anything itself — VoxelSurfaceManager reads _active_flows
## (plus placed water cells) and rebuilds one merged isosurface for the whole
## body. This manager just owns the BFS, the staggered trickle reveal, the
## looping stream audio, and the splash particles.

signal flow_changed

const CARDINAL_DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## Water now floods freely across the whole island and spills off every edge
## like a real waterfall. The isosurface only renders water sitting ON the
## island (within MAP_RADIUS); the moment water reaches the rim it pours off as
## a particle waterfall (see _refresh_waterfalls) instead of filling isosurface
## cells out into the empty sky — that keeps the merged mesh bounded/fast while
## still reading as endless cascades off the floating diorama.
## MODEST caps: a placed water block spreads to its immediate surroundings and
## trickles down a little (with the looping stream sound + rim waterfalls) so it
## feels alive — but it does NOT flood the whole island "lung tung". The routed
## SOURCE→PIPE stream (StreamManager) is the deliberate long-distance water.
## Placed water blocks stay CLEAN: elevated water still falls (a little cascade),
## but no sideways pooling (MAX_POOL 0) so a water block reads as a tidy pond
## cube — no messy spread. It keeps the looping stream sound. The routed
## SOURCE→PIPE stream is the deliberate flowing water.
const MAX_FALL_CELLS: int = 12
const MAX_POOL_CELLS: int = 0

## Visual radius of the floating island top (see main.tscn IslandTop = 9.0).
## Water pools within this; a cell whose neighbour lies beyond it is a rim cell
## that pours off the edge.
const MAP_RADIUS: float = 8.5
## Don't spawn more than this many waterfall emitters at once (perimeter is only
## ~50 cells, but cap defensively).
const MAX_WATERFALLS: int = 48

## How long between revealing each new step of a flow path — water should
## trickle down bit by bit, not pop into existence all at once the instant
## a source can reach that cell.
const REVEAL_INTERVAL: float = 0.09

var _active_flows: Dictionary = {} # Vector3i -> true (set of currently wet cells)
var _source_audio: Dictionary = {} # Vector3i (source cell) -> AudioStreamPlayer3D
var _pour_candidates: Dictionary = {} # Vector3i -> true, rim cells that spill off the island edge
var _waterfalls: Dictionary = {} # Vector3i (pour cell) -> GPUParticles3D

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

## Loop players are children of THIS node, not of any block — clear them
## explicitly. Flow cells are just dict entries now (no meshes to free).
func _on_grid_cleared() -> void:
	_active_flows.clear()
	for player in _source_audio.values():
		if is_instance_valid(player):
			player.queue_free()
	_source_audio.clear()
	for fall in _waterfalls.values():
		if is_instance_valid(fall):
			fall.queue_free()
	_waterfalls.clear()
	_pour_candidates.clear()
	_reveal_queue.clear()
	_last_flow_cells.clear()
	_reveal_timer = 0.0
	flow_changed.emit()

## A water cell "spills" when it's the top of its stack (nothing above it)
## and elevated (y>0) — matches a fountain source or the top of a filled pool.
## A water cell "spills" when it's the top of its stack (nothing above it) and
## elevated (y>0) — a fountain source or the top of a filled pool. Restored (with
## small caps above) so placed water flows locally + makes its stream sound; the
## SOURCE/PIPE stream is the separate deliberate routing.
func _get_spill_sources() -> Array[Vector3i]:
	var sources: Array[Vector3i] = []
	for cell in GridManager.get_all_cells_of_type(BlockData.Type.WATER):
		var above: Vector3i = cell + Vector3i(0, 1, 0)
		# Any exposed top surface spills: elevated water falls, ground-level water
		# still pools sideways to its neighbours (and both get the stream sound).
		if not GridManager.has_block(above):
			sources.append(cell)
	return sources

## BFS from every spill source through empty space: prefer falling straight
## down, and once blocked, flood outward into open neighbors at that level
## (so it pools/cascades instead of stopping dead). Returns cell -> the
## direction it was reached from, used to orient the flow-streak shader.
func _compute_flow_cells() -> Dictionary:
	var flow_cells: Dictionary = {}
	_pour_candidates = {}
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
				# Reached the island's edge: don't pool isosurface out into the
				# empty sky — mark THIS cell as a spill point that pours off as a
				# particle waterfall, and stop spreading that way.
				if _beyond_rim(side):
					_pour_candidates[current] = true
					continue
				visited[side] = true
				flow_cells[side] = dir
				pool_count += 1
				queue.append(side)
	return flow_cells

## A cell whose horizontal distance from the island centre exceeds the rim —
## water can't sit here, it falls off the edge.
func _beyond_rim(cell: Vector3i) -> bool:
	return Vector2(cell.x, cell.z).length() > MAP_RADIUS

func _process(delta: float) -> void:
	if _reveal_queue.is_empty():
		return
	_reveal_timer += delta
	var changed := false
	while _reveal_timer >= REVEAL_INTERVAL and not _reveal_queue.is_empty():
		_reveal_timer -= REVEAL_INTERVAL
		var cell: Vector3i = _reveal_queue.pop_front()
		if _last_flow_cells.has(cell) and not _active_flows.has(cell):
			_activate_cell(cell, _last_flow_cells[cell])
			changed = true
	if changed:
		_refresh_waterfalls()
		flow_changed.emit()

func _refresh() -> void:
	var flow_cells: Dictionary = _compute_flow_cells()
	_last_flow_cells = flow_cells

	var changed := false
	for cell in _active_flows.keys():
		if not flow_cells.has(cell):
			_active_flows.erase(cell)
			changed = true

	# Drop queued reveals that a grid change mid-trickle has invalidated.
	_reveal_queue = _reveal_queue.filter(func(c): return flow_cells.has(c) and not _active_flows.has(c))

	for cell in flow_cells:
		if _active_flows.has(cell) or _reveal_queue.has(cell):
			continue
		_reveal_queue.append(cell)

	_refresh_source_audio()
	_refresh_waterfalls()
	if changed:
		flow_changed.emit()

## Marks a cell wet (the merged isosurface picks it up) and, if the water
## just fell onto something solid, sprays a splash. No mesh here — the surface
## is one merged body rebuilt by VoxelSurfaceManager.
func _activate_cell(cell: Vector3i, from_dir: Vector3i) -> void:
	_active_flows[cell] = true
	var below: Vector3i = cell + Vector3i(0, -1, 0)
	if from_dir == Vector3i(0, -1, 0) and (cell.y == 0 or GridManager.has_block(below)):
		var splash_pos: Vector3 = GridManager.cell_to_world(cell) + Vector3(0.0, -0.5, 0.0)
		_spawn_splash(splash_pos)
		# Quiet landing splash; AudioManager's 35 ms dedupe keeps a whole
		# revealing cascade from machine-gunning.
		AudioManager.play_splash(splash_pos, -12.0)

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

## A pour cell that has actually been reached by water gets a streaming particle
## waterfall pouring straight down off the island edge. Managed like the source
## audio: add newly-active pour cells, free ones that dried up or vanished.
func _refresh_waterfalls() -> void:
	var desired: Dictionary = {}
	for cell in _pour_candidates:
		if desired.size() >= MAX_WATERFALLS:
			break
		if _active_flows.has(cell):
			desired[cell] = true

	for cell in _waterfalls.keys():
		if not desired.has(cell):
			var old: GPUParticles3D = _waterfalls[cell]
			if is_instance_valid(old):
				old.queue_free()
			_waterfalls.erase(cell)

	for cell in desired:
		if not _waterfalls.has(cell):
			var fall := _make_waterfall()
			# Emit from the outer edge of the cell, at its lip, pouring down.
			fall.position = GridManager.cell_to_world(cell) + Vector3(0.0, -0.35, 0.0)
			add_child(fall)
			fall.emitting = true
			_waterfalls[cell] = fall

## A long, thin downward stream of water droplets — a cheap endless waterfall
## that reads as water pouring off the diorama into the sky.
func _make_waterfall() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 26
	particles.lifetime = 2.2
	particles.explosiveness = 0.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Big visibility box so it isn't culled while the long stream falls.
	particles.visibility_aabb = AABB(Vector3(-0.6, -14.0, -0.6), Vector3(1.2, 15.0, 1.2))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.35, 0.05, 0.35)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 8.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 2.2
	mat.gravity = Vector3(0.0, -9.0, 0.0)
	mat.scale_min = 0.05
	mat.scale_max = 0.11
	particles.process_material = mat

	var drop := SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.16
	drop.radial_segments = 6
	drop.rings = 3
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.7, 0.9, 0.95, 0.9)
	drop_mat.roughness = 0.15
	drop_mat.emission_enabled = true
	drop_mat.emission = Color(0.55, 0.8, 0.85)
	drop_mat.emission_energy_multiplier = 0.15
	drop.material = drop_mat
	particles.draw_pass_1 = drop
	return particles
