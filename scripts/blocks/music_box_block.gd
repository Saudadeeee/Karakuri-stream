extends StaticBody3D

## Hộp nhạc (music box). Put a POWERED gear next to it and the crank turns,
## tinkling through a fixed little pentatonic melody — the gear train literally
## plays music, which is the heart of karakuri. Stops when the gears stop.
## Art: Blockbench box (carved body, lid, exposed pinned roller, crank axle);
## a small crank HANDLE stays procedural under _crank so it visibly spins.

const MODEL: PackedScene = preload("res://assets/3DModel/generated/music_box.glb")
const ACCENT := Color(0.878, 0.478, 0.372)

## A gentle 8-step pentatonic phrase (indices into PENTATONIC_RATIOS) — a real
## tune, not random, so it reads as a music box.
const MELODY: Array[int] = [0, 2, 4, 2, 3, 2, 1, 0]
const STEP_SECONDS: float = 0.5

var grid_cell: Vector3i
var _crank: Node3D
var _step: int = 0
var _timer: float = 0.0

func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	MeshFit.fit_bottom(model, 0.9, -0.5)
	MeshFit.matte(model)

	# Spinning crank handle just outside the box's authored crank axle.
	_crank = Node3D.new()
	_crank.position = Vector3(0.47, -0.06, 0)
	add_child(_crank)
	var knob := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.05, 0.16, 0.05)
	knob.mesh = b
	knob.position = Vector3(0.03, 0.07, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = ACCENT
	m.roughness = 1.0
	knob.material_override = m
	_crank.add_child(knob)

func _process(delta: float) -> void:
	if not GearManager.is_powered_neighbor(grid_cell):
		return
	_crank.rotate_x(2.4 * delta)
	_timer += delta
	if _timer >= STEP_SECONDS:
		_timer = 0.0
		AudioManager.play_music_box_note(global_position, MELODY[_step])
		_step = (_step + 1) % MELODY.size()
