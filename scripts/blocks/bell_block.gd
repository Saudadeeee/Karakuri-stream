extends StaticBody3D

## The zen chime — a bell hanging in a wooden stand. It is DELIBERATELY passive:
## it never rings on its own. It only chimes when combined with the machine —
## a water stream striking it (StreamManager) or a spinning gear beside it
## (GearManager) — and gives a little swing each time so you can see it react.

const MODEL: PackedScene = preload("res://assets/3DModel/generated/bell.glb")
const HEIGHT: float = 1.0
const FLOOR_Y: float = -0.5    # cell bottom in local block space (sits flush on ground)

var _model: Node3D

func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	MeshFit.fit_bottom(_model, HEIGHT, FLOOR_Y)
	MeshFit.matte(_model)

## Called by GearManager / StreamManager when the bell is actually struck — a
## quick swing so the chime reads as a reaction, not a random ding.
func ring() -> void:
	if not is_instance_valid(_model):
		return
	var t := create_tween()
	t.tween_property(_model, "rotation:z", 0.16, 0.06).set_trans(Tween.TRANS_SINE)
	t.tween_property(_model, "rotation:z", -0.12, 0.12).set_trans(Tween.TRANS_SINE)
	t.tween_property(_model, "rotation:z", 0.0, 0.18).set_trans(Tween.TRANS_ELASTIC)
