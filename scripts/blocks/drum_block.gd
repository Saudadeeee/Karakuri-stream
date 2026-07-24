extends StaticBody3D

## Wooden taiko drum. A stream falling on it — or a powered gear next to it —
## beats it: a deep "tùm" plus a squash. The percussion voice of the toy.
## Art: Blockbench taiko (barrel body, cream skin, studs, stand) — the whole
## model squashes on hit, exactly the mechanic.

const MODEL: PackedScene = preload("res://assets/3DModel/generated/drum.glb")

var grid_cell: Vector3i
var _visual: Node3D

func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var model: Node3D = MODEL.instantiate()
	_visual.add_child(model)
	MeshFit.fit_bottom(model, 0.88, -0.5)
	MeshFit.matte(model)

## Beat the drum (from a stream impact tick or an adjacent gear's full turn).
func hit() -> void:
	AudioManager.play_drum(global_position)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3(1.12, 0.86, 1.12), 0.06)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
