extends Node

const ROTATION_SPEED: float = 1.6 # rad/sec while powered — gentle, reads as clean meshing
const TOOTH_COUNT: int = 8        # must match the gear model's tooth count
# Half a tooth pitch: offset odd-parity gears by this so a tooth of one gear
# lines up with the GAP of its neighbour — the teeth interlock (mesh) instead
# of tooth-tip meeting tooth-tip. Combined with counter-rotation this reads as
# real meshing gears.
const HALF_TOOTH: float = TAU / (2.0 * TOOTH_COUNT)

var _rotation_progress: Dictionary = {} # Vector3i -> float, radians since last full turn
var _sparkles: Dictionary = {} # Vector3i -> GPUParticles3D
var _creaks: Dictionary = {}   # Vector3i -> AudioStreamPlayer3D (wooden rattle loop)
var _phased: Dictionary = {}   # Vector3i -> true, gears whose mesh phase is set

func _ready() -> void:
	GridManager.block_removed.connect(_on_block_removed)
	GridManager.grid_cleared.connect(_on_grid_cleared)

## Sparkle particles are children of the Gear's own MeshInstance3D, so
## GridManager already frees the node — this just drops the now-stale dict
## entries (they'd otherwise point at freed instances forever).
func _on_block_removed(cell: Vector3i) -> void:
	_sparkles.erase(cell)
	_remove_creak(cell)
	_rotation_progress.erase(cell)
	_phased.erase(cell)

func _on_grid_cleared() -> void:
	_sparkles.clear()
	for c in _creaks.keys():
		_remove_creak(c)
	_rotation_progress.clear()
	_phased.clear()

func _is_wet(cell: Vector3i) -> bool:
	var block: BlockData = GridManager.get_block(cell)
	if block != null and block.type == BlockData.Type.WATER:
		return true
	return WaterFlowManager._active_flows.has(cell)

## A gear is a "driver" when water (placed or flowing) touches any of its 6
## faces. Drivers power the whole connected chain of gears they're meshed with.
func _is_driver(cell: Vector3i) -> bool:
	# Driven when a routed stream lands on the gear (the karakuri way)...
	if StreamManager._driven_gears.has(cell):
		return true
	# ...or, as a fallback, when it sits against a static water pond.
	for dir in GridManager.DIRECTIONS:
		if _is_wet(cell + dir):
			return true
	return false

## Gears meshing together form a drive train: touch one to water and the whole
## connected group turns. Meshing gears must spin OPPOSITE ways — and since the
## 6-neighbour grid graph is bipartite, the parity of (x+y+z) gives a
## consistent 2-colouring for free, so adjacent gears always counter-rotate
## without any per-gear direction search.
func _process(delta: float) -> void:
	var gears: Array[Vector3i] = GridManager.get_all_cells_of_type(BlockData.Type.GEAR)
	var gear_set: Dictionary = {}
	for g in gears:
		gear_set[g] = true

	# Flood each connected component once; a component is powered if ANY gear
	# in it is a driver.
	var powered: Dictionary = {} # cell -> bool
	var seen: Dictionary = {}
	for g in gears:
		if seen.has(g):
			continue
		var component: Array[Vector3i] = []
		var queue: Array[Vector3i] = [g]
		seen[g] = true
		var is_powered := false
		while queue.size() > 0:
			var c: Vector3i = queue.pop_back()
			component.append(c)
			if _is_driver(c):
				is_powered = true
			for dir in GridManager.DIRECTIONS:
				var nb: Vector3i = c + dir
				if gear_set.has(nb) and not seen.has(nb):
					seen[nb] = true
					queue.append(nb)
		for c in component:
			powered[c] = is_powered

	for cell in gears:
		var block: BlockData = GridManager.get_block(cell)
		if not is_instance_valid(block.node):
			continue
		var mesh_instance: Node3D = block.node.get_node_or_null("MeshInstance3D")
		if mesh_instance == null:
			continue

		var odd_parity: bool = ((cell.x + cell.y + cell.z) & 1) == 1
		# Set the interlocking phase once, so neighbours mesh from the start.
		if not _phased.has(cell):
			mesh_instance.rotation.y = HALF_TOOTH if odd_parity else 0.0
			_phased[cell] = true

		if powered.get(cell, false):
			var dir_sign: float = -1.0 if odd_parity else 1.0
			mesh_instance.rotate_y(dir_sign * ROTATION_SPEED * delta)
			_ensure_sparkle(cell, mesh_instance)
			_ensure_creak(cell, mesh_instance)

			var progress: float = _rotation_progress.get(cell, 0.0) + ROTATION_SPEED * delta
			if progress >= TAU:
				progress -= TAU
				_strike_adjacent_bells(cell)
			_rotation_progress[cell] = progress
		else:
			_rotation_progress[cell] = 0.0
			_remove_sparkle(cell)
			_remove_creak(cell)

func _strike_adjacent_bells(cell: Vector3i) -> void:
	for dir in GridManager.DIRECTIONS:
		var neighbor: BlockData = GridManager.get_block(cell + dir)
		if neighbor != null and neighbor.type == BlockData.Type.BELL and is_instance_valid(neighbor.node):
			AudioManager.play_chime(neighbor.node.global_position)
			FireflyManager.burst_at(neighbor.node.global_position)
			if neighbor.node.has_method("ring"):
				neighbor.node.ring()

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

## A looping wooden rattle plays from each spinning gear ("kẽo kẹt"), child of
## its mesh so it's positional and freed with the block.
func _ensure_creak(cell: Vector3i, parent: Node3D) -> void:
	if _creaks.has(cell):
		return
	var player: AudioStreamPlayer3D = AudioManager.make_gear_loop_player()
	parent.add_child(player)
	player.play()
	_creaks[cell] = player

func _remove_creak(cell: Vector3i) -> void:
	if not _creaks.has(cell):
		return
	var player: AudioStreamPlayer3D = _creaks[cell]
	if is_instance_valid(player):
		player.queue_free()
	_creaks.erase(cell)
