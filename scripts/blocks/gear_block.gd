extends StaticBody3D

## Loads the wooden cogwheel art model as the spinning wheel. The model is
## instanced under the child named "MeshInstance3D" — the node GearManager spins
## and phase-offsets — so all the drive-train logic keeps working unchanged; only
## the visual is now the imported gear instead of parametric boxes. Sized so the
## teeth reach just past the cell boundary (radius ~0.57) and interlock with a
## neighbouring gear one cell away.

## Variant models: the toothed cogwheel or the paddled water-mill wheel. Both
## spin the same way (GearManager rotates the "MeshInstance3D" pivot).
const MODELS: Dictionary = {
	"gear": preload("res://assets/3DModel/generated/gear.glb"),
	"mill": preload("res://assets/3DModel/generated/mill.glb"),
}
## Wheel diameter after fitting. The teeth tips reach WHEEL_DIAMETER/2 from the
## centre, so at 1.1 two gears one cell apart overlap by ~0.1 — the tip of one
## tucks into the tooth gap of its (counter-rotating, half-tooth-offset)
## neighbour and they visibly MESH, without the hubs merging.
const WHEEL_DIAMETER: float = 1.1

var _model_name: String = ""

func _ready() -> void:
	# Deferred default: apply_variant (placement/save/icons) lands right after
	# add_child — waiting one tick means we never build "gear" only to tear it
	# down for "mill" a moment later.
	_ensure_default.call_deferred()

func _ensure_default() -> void:
	if _model_name == "":
		_build("gear")

func apply_variant(v: Dictionary) -> void:
	_build(v.get("model", "gear"))

func _build(model_name: String) -> void:
	# apply_variant always fires right after _ready on placement — skip the
	# wasteful tear-down/rebuild when the model wouldn't change (it also spams
	# renderer noise when the overridden-material model is freed).
	if model_name == _model_name:
		return
	_model_name = model_name
	var pivot: Node3D = $MeshInstance3D
	for c in pivot.get_children():
		c.queue_free()
	var scene: PackedScene = MODELS.get(model_name, MODELS["gear"])
	var model: Node3D = scene.instantiate()
	pivot.add_child(model)
	MeshFit.fit_centered(model, WHEEL_DIAMETER)
	MeshFit.matte(model)

## Orient the whole wheel so its disc axis (local +Y, the axis GearManager spins
## around) points along the face it was placed on. Click the TOP of a block
## (normal +Y) → wheel lies flat; click a SIDE (normal ±X/±Z) → wheel stands up
## in that wall plane like a water wheel. Called by PlacementController on place
## and SaveManager on load; the six cardinal normals map to fixed 90°/180° turns.
func apply_axis(axis: Vector3i) -> void:
	basis = _basis_for_axis(axis)

static func _basis_for_axis(axis: Vector3i) -> Basis:
	match axis:
		Vector3i(1, 0, 0):
			return Basis(Vector3(0, 0, 1), -PI / 2.0)
		Vector3i(-1, 0, 0):
			return Basis(Vector3(0, 0, 1), PI / 2.0)
		Vector3i(0, 0, 1):
			return Basis(Vector3(1, 0, 0), PI / 2.0)
		Vector3i(0, 0, -1):
			return Basis(Vector3(1, 0, 0), -PI / 2.0)
		Vector3i(0, -1, 0):
			return Basis(Vector3(1, 0, 0), PI)
		_: # (0, 1, 0) top face and any fallback: flat.
			return Basis.IDENTITY
