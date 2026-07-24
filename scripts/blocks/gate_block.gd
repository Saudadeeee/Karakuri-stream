extends StaticBody3D

## Sluice gate (van tre) — the toy's first DIRECTLY-controllable block. CLICK
## the gate in the world (left click) to slide its paddle open or shut:
## open  → falling water passes straight through;
## closed → the stream stops dead on the paddle (a wood knock).
## Toggling live re-routes the whole machine downstream — mute a chime row,
## un-mute it on the beat, conduct your own contraption.

const FRAME := Color(0.831, 0.639, 0.451)
const PADDLE := Color(0.549, 0.702, 0.412)
const ACCENT := Color(0.878, 0.478, 0.372)

var grid_cell: Vector3i
var _paddle: Node3D
var _open: bool = false

func _ready() -> void:
	var v := Node3D.new()
	add_child(v)
	# Two posts + top rail: the frame the paddle slides in.
	v.add_child(_box(Vector3(0.12, 1.0, 0.12), Vector3(-0.42, 0.0, 0.0), FRAME))
	v.add_child(_box(Vector3(0.12, 1.0, 0.12), Vector3(0.42, 0.0, 0.0), FRAME))
	v.add_child(_box(Vector3(0.98, 0.12, 0.14), Vector3(0.0, 0.5, 0.0), FRAME))
	# Handle knob on the rail — the "click me" affordance.
	v.add_child(_box(Vector3(0.1, 0.18, 0.1), Vector3(0.0, 0.64, 0.0), ACCENT))
	# The sliding paddle (a woven bamboo panel).
	_paddle = Node3D.new()
	v.add_child(_paddle)
	_paddle.add_child(_box(Vector3(0.74, 0.8, 0.08), Vector3.ZERO, PADDLE))
	for y in [-0.22, 0.0, 0.22]:
		_paddle.add_child(_box(Vector3(0.74, 0.05, 0.1), Vector3(0.0, y, 0.0), FRAME))

## Toggle (from a world click). `silent` is used by save-load restore.
func toggle() -> void:
	set_open(not _open)

func set_open(open: bool, silent: bool = false) -> void:
	_open = open
	var block: BlockData = GridManager.get_block(grid_cell)
	if block != null:
		block.state["open"] = _open
	if not silent:
		AudioManager.play_wood_pitch(global_position, 1.6 if _open else 0.9, -2.0)
	# Slide the paddle up out of the frame (open) or back down (shut).
	var tw := create_tween()
	tw.tween_property(_paddle, "position:y", 0.62 if _open else 0.0, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The stream must re-route immediately.
	StreamManager._on_changed()

func is_open() -> bool:
	return _open

func _box(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	mi.material_override = m
	return mi
