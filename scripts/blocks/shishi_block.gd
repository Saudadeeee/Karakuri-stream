extends StaticBody3D

## Shishi-odoshi (ống tre gõ đá) — THE karakuri garden icon. A pivoting bamboo
## tube fills while a stream pours onto this cell (StreamManager calls fill()
## on each impact tick); once full it TIPS, dumps its water onward (a temporary
## stream source at this cell, so the flow continues below), knocks "cốc!" on
## its stone, and swings back.
## Art: two Blockbench models — a static base (rock + post + fork) and the
## bamboo ARM alone, instanced under the _arm pivot so the tip animation is
## exactly the mechanic.

const BASE: PackedScene = preload("res://assets/3DModel/generated/shishi_base.glb")
const ARM: PackedScene = preload("res://assets/3DModel/generated/shishi_arm.glb")

const FILLS_TO_TIP: int = 2      # impact ticks (~0.55s each) before tipping
const DUMP_SECONDS: float = 0.9  # how long the dumped water flows on

var grid_cell: Vector3i
var _arm: Node3D
var _fill_count: int = 0
var _dumping: bool = false

func _ready() -> void:
	var base: Node3D = BASE.instantiate()
	add_child(base)
	MeshFit.fit_bottom(base, 0.9, -0.5)
	MeshFit.matte(base)

	# Pivot sits on the fork atop the post (matches the fitted base).
	_arm = Node3D.new()
	_arm.position = Vector3(-0.2, 0.32, 0)
	add_child(_arm)
	var arm_model: Node3D = ARM.instantiate()
	_arm.add_child(arm_model)
	MeshFit.fit_centered(arm_model, 0.78)
	MeshFit.matte(arm_model)
	arm_model.position.x += 0.06   # mouth side slightly longer past the pivot
	_arm.rotation.z = 0.22         # resting: mouth up, catching the stream

## One tick of pouring water (called by StreamManager every impact interval).
func fill() -> void:
	if _dumping:
		return
	_fill_count += 1
	# Small dip as it takes on weight.
	var tw := create_tween()
	tw.tween_property(_arm, "rotation:z", 0.22 - 0.06 * _fill_count, 0.18)
	if _fill_count >= FILLS_TO_TIP:
		_dump()

func _dump() -> void:
	_dumping = true
	_fill_count = 0
	StreamManager.add_temp_source(grid_cell, DUMP_SECONDS)
	AudioManager.play_shishi_knock(global_position)
	var tw := create_tween()
	tw.tween_property(_arm, "rotation:z", -0.55, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)      # tip! water pours
	tw.tween_interval(DUMP_SECONDS * 0.6)
	tw.tween_property(_arm, "rotation:z", 0.22, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)  # swing back "cốc"
	tw.tween_callback(func(): _dumping = false)
