extends StaticBody3D

## Phong linh (wind-chime tube) — each VARIANT is one fixed pentatonic note
## (C D E G A), so a row of chimes under a routed stream literally plays a
## melody the player composed. Stream impact → ring() → note + swing.
## Art: Blockbench frame (post + arm + hook) static, TUBE model hung under the
## _swing pivot so the pendulum swing is the mechanic; the tube is TINTED to
## the note's colour (MeshFit.tint from the authored base teal).

const FRAME: PackedScene = preload("res://assets/3DModel/generated/chime_frame.glb")
const TUBE: PackedScene = preload("res://assets/3DModel/generated/chime_tube.glb")
const TUBE_BASE := Color("#9BD4CE")   # authored tube colour tint() matches on

var grid_cell: Vector3i
var _note: int = 0
var _tube_model: Node3D
var _swing: Node3D
var _pending_variant: Dictionary = {}

func _ready() -> void:
	var frame: Node3D = FRAME.instantiate()
	add_child(frame)
	MeshFit.fit_bottom(frame, 0.95, -0.5)
	MeshFit.matte(frame)

	# Hang the tube from the arm's hook (matches the fitted frame).
	_swing = Node3D.new()
	_swing.position = Vector3(0.24, 0.32, 0)
	add_child(_swing)
	_tube_model = TUBE.instantiate()
	_swing.add_child(_tube_model)
	_shape_tube()
	MeshFit.matte(_tube_model)
	if not _pending_variant.is_empty():
		apply_variant(_pending_variant)

## Tube length per note. A chime's note was told ONLY by its colour, which is
## unreadable to a colour-blind player — and this is not decoration, it is the
## melody. Real chimes are pitched by length, so the higher the note the shorter
## the tube: the row now reads as a descending staircase whether or not the
## colours land.
const TUBE_LENGTHS: Array[float] = [0.62, 0.575, 0.53, 0.48, 0.43]   # C D E G A

func _shape_tube() -> void:
	var length: float = TUBE_LENGTHS[_note % TUBE_LENGTHS.size()]
	# floor_y = -length puts the CORD END at the pivot whatever the length, so
	# every tube still hangs from the hook instead of floating under it.
	MeshFit.fit_bottom(_tube_model, length, -length)
	# The authored tube is tall and thin; fatten it sideways so the chime pipe
	# reads clearly at gameplay distance (a uniform fit keeps it too skinny).
	_tube_model.scale *= Vector3(1.7, 1.0, 1.7)

func apply_variant(v: Dictionary) -> void:
	_note = int(v.get("note", 0))
	if _tube_model == null:
		_pending_variant = v   # icons/ghost call before _ready — applied there
		return
	_shape_tube()
	MeshFit.tint(_tube_model, TUBE_BASE, Color(v.get("color", "#9BD4CE")))

## Stream impact tick → this chime's own note + a pendulum swing.
func ring(pitch_mul: float = 1.0) -> void:
	AudioManager.play_chime(global_position, _note, pitch_mul)
	var tw := create_tween()
	tw.tween_property(_swing, "rotation:z", 0.35, 0.1)
	tw.tween_property(_swing, "rotation:z", 0.0, 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
