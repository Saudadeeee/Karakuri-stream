extends Node

const ROTATION_SPEED: float = 3.0 # rad/sec while powered

var _rotation_progress: Dictionary = {} # Vector3i -> float, radians since last full turn
var _sparkles: Dictionary = {} # Vector3i -> GPUParticles3D

func _ready() -> void:
	GridManager.block_removed.connect(_on_block_removed)
	GridManager.grid_cleared.connect(_on_grid_cleared)

## Sparkle particles are children of the Gear's own MeshInstance3D, so
## GridManager already frees the node — this just drops the now-stale dict
## entries (they'd otherwise point at freed instances forever).
func _on_block_removed(cell: Vector3i) -> void:
	_sparkles.erase(cell)
	_rotation_progress.erase(cell)

func _on_grid_cleared() -> void:
	_sparkles.clear()
	_rotation_progress.clear()

func _is_wet(cell: Vector3i) -> bool:
	var block: BlockData = GridManager.get_block(cell)
	if block != null and block.type == BlockData.Type.WATER:
		return true
	return WaterFlowManager._active_flows.has(cell)

## A gear spins when water (placed or actively flowing) touches any of its
## 6 faces — mirrors the plan's "is_powered" idea without needing a full
## pipe/trough network, since Wood+Water+Gear is still the whole toolkit.
func _is_powered(cell: Vector3i) -> bool:
	for dir in GridManager.DIRECTIONS:
		if _is_wet(cell + dir):
			return true
	return false

func _process(delta: float) -> void:
	for cell in GridManager.get_all_cells_of_type(BlockData.Type.GEAR):
		var block: BlockData = GridManager.get_block(cell)
		if not is_instance_valid(block.node):
			continue
		var mesh_instance: Node3D = block.node.get_node_or_null("MeshInstance3D")
		if mesh_instance == null:
			continue

		if _is_powered(cell):
			mesh_instance.rotate_y(ROTATION_SPEED * delta)
			_ensure_sparkle(cell, mesh_instance)

			var progress: float = _rotation_progress.get(cell, 0.0) + ROTATION_SPEED * delta
			if progress >= TAU:
				progress -= TAU
				_strike_adjacent_bells(cell)
			_rotation_progress[cell] = progress
		else:
			_rotation_progress[cell] = 0.0
			_remove_sparkle(cell)

func _strike_adjacent_bells(cell: Vector3i) -> void:
	for dir in GridManager.DIRECTIONS:
		var neighbor: BlockData = GridManager.get_block(cell + dir)
		if neighbor != null and neighbor.type == BlockData.Type.BELL and is_instance_valid(neighbor.node):
			AudioManager.play_chime(neighbor.node.global_position)
			FireflyManager.burst_at(neighbor.node.global_position)

func _ensure_sparkle(cell: Vector3i, parent: Node3D) -> void:
	if _sparkles.has(cell):
		return
	var particles := GPUParticles3D.new()
	particles.amount = 10
	particles.lifetime = 1.0
	particles.explosiveness = 0.0

	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 50.0
	process_material.initial_velocity_min = 0.15
	process_material.initial_velocity_max = 0.4
	process_material.gravity = Vector3(0.0, 0.25, 0.0)
	process_material.scale_min = 0.02
	process_material.scale_max = 0.05
	particles.process_material = process_material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.albedo_color = Color(1.0, 0.95, 0.6, 0.9)
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.emission_enabled = true
	particle_material.emission = Color(1.0, 0.9, 0.5)
	quad.material = particle_material
	particles.draw_pass_1 = quad

	parent.add_child(particles)
	_sparkles[cell] = particles

func _remove_sparkle(cell: Vector3i) -> void:
	if not _sparkles.has(cell):
		return
	var particles: GPUParticles3D = _sparkles[cell]
	if is_instance_valid(particles):
		particles.queue_free()
	_sparkles.erase(cell)
