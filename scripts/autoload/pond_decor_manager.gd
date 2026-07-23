extends Node

const LILY_PAD: PackedScene = preload("res://assets/3DModel/generated/lily_pad.glb")
const KOI: PackedScene = preload("res://assets/3DModel/generated/koi.glb")

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

	# Sparse, scattered decor: each pond CELL has only a CHANCE of one lily pad
	# (never a guaranteed two-per-cell clump), so a big pond gets pads spread
	# nicely across it instead of a pile. Koi are rarer still.
	if randf() < 0.45:
		_add_lily_pad(root)
	if randf() < 0.55:
		_add_koi(root)

## The lily pad is now the styled art model (notch + wabi-sabi flower already
## modelled in). A Node3D wrapper carries the bob animation; the model sits
## inside it, fitted to a small pad size and flattened to the matte look.
func _add_lily_pad(root: Node3D) -> void:
	var pad := Node3D.new()
	var model: Node3D = LILY_PAD.instantiate()
	pad.add_child(model)
	MeshFit.fit_centered(model, randf_range(0.42, 0.58))
	MeshFit.matte(model)
	# Sit ON the (now opaque, slightly inflated) water top, not sunk into it.
	var base_pos := Vector3(randf_range(-0.25, 0.25), 0.62, randf_range(-0.25, 0.25))
	pad.position = base_pos
	pad.rotation.y = randf_range(0.0, TAU)
	root.add_child(pad)

	_pad_data.append({
		"node": pad,
		"base_pos": base_pos,
		"bob_speed": randf_range(0.7, 1.3),
		"bob_phase": randf_range(0.0, TAU),
		"bob_amount": randf_range(0.035, 0.06),
	})

## Koi is now the modelled fish (Blockbench: torpedo body, Kohaku red patches,
## caudal/dorsal/pectoral fins, dark eyes). A Node3D wrapper carries the swim
## transform; the model sits inside, fitted so its LENGTH (local +X = head) ≈
## one koi and flattened to the matte look. `_process` aims +X along the swim
## tangent so it always faces where it's going.
func _add_koi(root: Node3D) -> void:
	var fish := Node3D.new()
	var model: Node3D = KOI.instantiate()
	fish.add_child(model)
	MeshFit.fit_centered(model, randf_range(0.52, 0.7))
	MeshFit.matte(model)
	root.add_child(fish)

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
		# Swim right at the (now opaque) surface — backs breaking the water — plus
		# a gentle bob, so the koi are actually visible.
		var swim_y: float = 0.5 + sin(t * 1.6 + fish["phase"]) * 0.03
		fish["node"].position = Vector3(cos(angle) * fish["radius"], swim_y, sin(angle) * fish["radius"])
		# Aim the model's head (+X) along the velocity tangent (-sin, 0, cos).
		fish["node"].rotation.y = atan2(-cos(angle), -sin(angle))
		# Gentle tail-sway roll so it reads as a live swimming fish.
		fish["node"].rotation.z = sin(t * 3.0 + fish["phase"]) * 0.12

	for pad in _pad_data:
		if not is_instance_valid(pad["node"]):
			continue
		var bob: float = sin(t * pad["bob_speed"] + pad["bob_phase"]) * pad["bob_amount"]
		var base_pos: Vector3 = pad["base_pos"]
		pad["node"].position = base_pos + Vector3(0.0, bob, 0.0)
		pad["node"].rotation.z = sin(t * pad["bob_speed"] * 0.6 + pad["bob_phase"]) * 0.06
