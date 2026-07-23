extends StaticBody3D

## A cute placeable jelly cube (built in Blockbench). Purely a decorative toy —
## it wobbles gently like soft jelly. Its little face is baked into the model;
## the variant recolours just the body (eyes/blush stay).

const MODEL: PackedScene = preload("res://assets/3DModel/generated/jelly.glb")
const BASE_CYAN := Color(0.282, 0.792, 0.894)   # jelly body colour to retint

var _wobbler: Node3D   # wrapper we squash/stretch (model keeps its fit scale inside)
var _model: Node3D

func _ready() -> void:
	_ensure_model()
	_wobble()

## Build the model on demand — so apply_variant works even before the block is
## in the tree (e.g. building the material-bar icon).
func _ensure_model() -> void:
	if _model != null:
		return
	_wobbler = Node3D.new()
	add_child(_wobbler)
	_model = MODEL.instantiate()
	_wobbler.add_child(_model)
	MeshFit.fit_bottom(_model, 0.92, -0.5)
	MeshFit.matte(_model)

## Recolour just the jelly body to the variant colour (eyes/blush stay).
func apply_variant(v: Dictionary) -> void:
	_ensure_model()
	if v.has("color"):
		MeshFit.tint(_model, BASE_CYAN, Color(v["color"]))

## Endless soft squash-and-stretch so the jelly always looks alive. Wobbling the
## wrapper (not the model) leaves the model's fit scale intact.
func _wobble() -> void:
	var t := create_tween().set_loops()
	t.tween_property(_wobbler, "scale", Vector3(1.06, 0.92, 1.06), 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(_wobbler, "scale", Vector3(0.95, 1.08, 0.95), 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(_wobbler, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_SINE)
