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
	MeshFit.fit_bottom(_tube_model, 0.55, -0.55)   # top (cord) at the pivot
	# The authored tube is tall and thin; fatten it sideways so the chime pipe
	# reads clearly at gameplay distance (uniform fit keeps it too skinny).
	_tube_model.scale *= Vector3(1.7, 1.0, 1.7)
	MeshFit.matte(_tube_model)
	if not _pending_variant.is_empty():
		apply_variant(_pending_variant)

func apply_variant(v: Dictionary) -> void:
	_note = int(v.get("note", 0))
	if _tube_model == null:
		_pending_variant = v   # icons/ghost call before _ready — applied there
		return
	MeshFit.tint(_tube_model, TUBE_BASE, Color(v.get("color", "#9BD4CE")))

## Stream impact tick → this chime's own note + a pendulum swing.
func ring() -> void:
	AudioManager.play_chime(global_position, _note)
	var tw := create_tween()
	tw.tween_property(_swing, "rotation:z", 0.35, 0.1)
	tw.tween_property(_swing, "rotation:z", 0.0, 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
