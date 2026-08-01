extends Node

## Verge-and-foliot ESCAPEMENT — the game's beat made visible. A foliot bar
## rocks side-to-side with the shared clock while an escape-wheel SNAPS one
## tooth per swing (the crisp step is what reads as clockwork, not a spin). It
## sits on a plinth at the island rim (off the build grid) and a twin stands by
## the menu wordmark — both driven by StreamManager._clock, which advances every
## frame even when idle, so it's always gently ticking.

const TEETH := 12

var _root: Node3D
var _foliot: Node3D          # the rocking weighted bar (verge)
var _wheel: MeshInstance3D   # the escape wheel that steps
var _wheel_step: int = 0
var _wheel_target: float = 0.0
var _wheel_cur: float = 0.0
var _last_half: int = 0

func _ready() -> void:
	# Deferred so the main scene (island) exists; the menu builds its own twin.
	rebuild.call_deferred()

func rebuild() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = _make_movement()
	add_child(_root)
	# Perch on the island rim, off the buildable grid (radius ≤ 12 is buildable;
	# the rim ledge at ~8 with a small plinth is decorative, y just below top).
	var a := deg_to_rad(20.0)
	_root.position = Vector3(cos(a) * 8.2, 0.0, sin(a) * 8.2)
	_root.rotation.y = a + PI

## Build a self-contained escapement movement (reused by the menu twin).
func _make_movement() -> Node3D:
	var wood := MapThemes.mechanism()["wood"] as Color
	var root := Node3D.new()
	# Plinth + upright post.
	root.add_child(_box(Vector3(0.5, 0.12, 0.4), Vector3(0, 0.06, 0), wood.darkened(0.15)))
	root.add_child(_box(Vector3(0.08, 0.9, 0.08), Vector3(0, 0.5, -0.1), wood))
	# Escape wheel (faces +Z), stepping one tooth per beat.
	_wheel = MeshInstance3D.new()
	_wheel.mesh = GearMesh.build(TEETH, 0.32, 0.24, 0.1, 0.06, wood, wood.lightened(0.08))
	_wheel.material_override = GearMesh.material()
	_wheel.position = Vector3(0, 0.5, 0.0)
	root.add_child(_wheel)
	# Foliot: a horizontal bar pivoting about the vertical post, weights on ends.
	_foliot = Node3D.new()
	_foliot.position = Vector3(0, 0.86, -0.05)
	root.add_child(_foliot)
	_foliot.add_child(_box(Vector3(1.3, 0.06, 0.06), Vector3.ZERO, wood))
	for sx in [-1.0, 1.0]:
		_foliot.add_child(_cyl(0.09, 0.12, Color("e07a5f"), Vector3(0.6 * sx, 0, 0)))
	return root

func _process(delta: float) -> void:
	if not is_instance_valid(_root):
		return
	var phase: float = StreamManager.beat_phase()
	# Foliot rocks once per beat (full sine over the beat).
	if is_instance_valid(_foliot):
		_foliot.rotation.y = sin(phase * TAU) * 0.5
	# Escape wheel STEPS a tooth on each half-beat crossing (verge "escapes").
	var half: int = int(StreamManager._clock / (StreamManager.BASE_BEAT * 0.5))
	if half != _last_half:
		_last_half = half
		_wheel_step += 1
		_wheel_target = float(_wheel_step) * (TAU / float(TEETH))
	# Ease toward the stepped target — crisp catch, not a smooth spin.
	_wheel_cur = lerpf(_wheel_cur, _wheel_target, minf(delta * 16.0, 1.0))
	if is_instance_valid(_wheel):
		_wheel.rotation.z = _wheel_cur

# ---------------------------------------------------------------- primitives
func _box(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new(); b.size = size
	mi.mesh = b; mi.position = pos; mi.material_override = MeshFit.flat(col)
	return mi

func _cyl(r: float, h: float, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 10
	mi.mesh = c; mi.rotation.z = PI / 2.0; mi.position = pos; mi.material_override = MeshFit.flat(col)
	return mi
