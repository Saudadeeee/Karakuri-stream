extends Node

const HORIZONTAL_DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _ponds: Dictionary = {} # Vector3i -> Node3D (pond decor root)
var _fish_data: Array = [] # [{node, radius, speed, phase}]
var _pad_data: Array = [] # [{node, base_pos, bob_speed, bob_phase, bob_amount}]

func _ready() -> void:
	GridManager.block_placed.connect(_on_grid_changed)
	GridManager.block_removed.connect(_on_grid_changed)
	GridManager.grid_cleared.connect(_on_grid_cleared)

## A change at `cell` can only flip the surrounded-status of a Water cell
## that has `cell` as one of its 4 horizontal neighbors (or `cell` itself,
## if it just became/stopped being Water) — never of water elsewhere in the
## grid, so there's no need to rescan every Water block on every change.
func _on_grid_changed(cell: Vector3i) -> void:
	_check_water_cell(cell)
	for dir in HORIZONTAL_DIRS:
		_check_water_cell(cell + dir)

## Pond roots are children of THIS node, not of any water block —
## GridManager.clear_all() can't free them for us.
func _on_grid_cleared() -> void:
	for root in _ponds.values():
		if is_instance_valid(root):
			root.queue_free()
	_ponds.clear()
	_fish_data.clear()
	_pad_data.clear()

func _check_water_cell(cell: Vector3i) -> void:
	var block: BlockData = GridManager.get_block(cell)
	if block == null or block.type != BlockData.Type.WATER:
		if _ponds.has(cell):
			_remove_pond(cell)
		return

	var surrounded := true
	for dir in HORIZONTAL_DIRS:
		if not GridManager.has_block(cell + dir):
			surrounded = false
			break

	if surrounded and not _ponds.has(cell):
		_spawn_pond(cell)
	elif not surrounded and _ponds.has(cell):
		_remove_pond(cell)

func _spawn_pond(cell: Vector3i) -> void:
	var root := Node3D.new()
	root.position = GridManager.cell_to_world(cell)
	add_child(root)
	_ponds[cell] = root

	for i in 2:
		_add_lily_pad(root)
	for i in randi_range(1, 2):
		_add_koi(root)

func _add_lily_pad(root: Node3D) -> void:
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = randf_range(0.16, 0.24)
	disc.bottom_radius = disc.top_radius
	disc.height = 0.03
	pad.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.5, 0.22)
	pad.material_override = material
	var base_pos := Vector3(randf_range(-0.25, 0.25), 0.52, randf_range(-0.25, 0.25))
	pad.position = base_pos
	pad.rotation.y = randf_range(0.0, TAU)
	root.add_child(pad)

	# A notch wedge cut from one side reads as the classic lily-pad slit.
	var notch := MeshInstance3D.new()
	var wedge := PrismMesh.new()
	wedge.size = Vector3(disc.top_radius * 0.9, 0.04, disc.top_radius * 1.1)
	notch.mesh = wedge
	var notch_mat := StandardMaterial3D.new()
	notch_mat.albedo_color = Color(0.28, 0.42, 0.24)
	notch.material_override = notch_mat
	notch.position = Vector3(0.0, 0.0, disc.top_radius * 0.5)
	pad.add_child(notch)

	# Some pads carry a small pink water-lily flower — the wabi-sabi bloom.
	if randf() < 0.5:
		var flower := MeshInstance3D.new()
		var petals := SphereMesh.new()
		petals.radius = disc.top_radius * 0.4
		petals.height = disc.top_radius * 0.5
		petals.radial_segments = 8
		petals.rings = 4
		flower.mesh = petals
		var flower_mat := StandardMaterial3D.new()
		flower_mat.albedo_color = Color(0.95, 0.72, 0.82)
		flower.material_override = flower_mat
		flower.position = Vector3(0.0, 0.05, 0.0)
		pad.add_child(flower)

	_pad_data.append({
		"node": pad,
		"base_pos": base_pos,
		"bob_speed": randf_range(0.7, 1.3),
		"bob_phase": randf_range(0.0, TAU),
		"bob_amount": randf_range(0.015, 0.03),
	})

func _add_koi(root: Node3D) -> void:
	var fish := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.06
	body.height = 0.22
	fish.mesh = body
	fish.rotation.x = PI * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.45, 0.15) if randf() > 0.3 else Color(0.95, 0.95, 0.9)
	fish.material_override = material
	root.add_child(fish)

	# Flat triangular tail fin at the back of the body (body's local -Y is
	# "behind" because the capsule was rotated to lie flat).
	var tail := MeshInstance3D.new()
	var fin := PrismMesh.new()
	fin.size = Vector3(0.14, 0.01, 0.12)
	tail.mesh = fin
	tail.material_override = material
	tail.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	tail.position = Vector3(0.0, -0.16, 0.0)
	fish.add_child(tail)

	_fish_data.append({
		"node": fish,
		"radius": randf_range(0.12, 0.28),
		"speed": randf_range(0.6, 1.4),
		"phase": randf_range(0.0, TAU),
	})

func _remove_pond(cell: Vector3i) -> void:
	var root: Node3D = _ponds[cell]
	_fish_data = _fish_data.filter(func(f): return not is_instance_valid(f["node"]) or f["node"].get_parent() != root)
	_pad_data = _pad_data.filter(func(p): return not is_instance_valid(p["node"]) or p["node"].get_parent() != root)
	if is_instance_valid(root):
		root.queue_free()
	_ponds.erase(cell)

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for fish in _fish_data:
		if not is_instance_valid(fish["node"]):
			continue
		var angle: float = t * fish["speed"] + fish["phase"]
		fish["node"].position = Vector3(cos(angle) * fish["radius"], 0.42, sin(angle) * fish["radius"])
		fish["node"].rotation.y = -angle + PI * 0.5

	for pad in _pad_data:
		if not is_instance_valid(pad["node"]):
			continue
		var bob: float = sin(t * pad["bob_speed"] + pad["bob_phase"]) * pad["bob_amount"]
		var base_pos: Vector3 = pad["base_pos"]
		pad["node"].position = base_pos + Vector3(0.0, bob, 0.0)
		pad["node"].rotation.z = sin(t * pad["bob_speed"] * 0.6 + pad["bob_phase"]) * 0.06
