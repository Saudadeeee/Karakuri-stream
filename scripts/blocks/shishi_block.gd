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

const DUMP_SECONDS: float = 0.9  # how long the dumped water flows on

var grid_cell: Vector3i
var _arm: Node3D
var _arm_model: Node3D
var _fill_count: int = 0
var _dumping: bool = false
## Capacity variant: quick tips every fill (a busy little bird), classic every
## 2, patient every 5 — chainable CLOCK DIVIDERS (a 2-shishi feeding a
## 5-shishi tips once per 10 beats).
var _fills_to_tip: int = 2
var _pending_variant: Dictionary = {}
## Dye carry: the tube pours out whatever colour it was filled with.
var _fill_color: Color = Color(0.282, 0.792, 0.894)

func _ready() -> void:
	var base: Node3D = BASE.instantiate()
	add_child(base)
	MeshFit.fit_bottom(base, 0.9, -0.5)
	MeshFit.matte(base)

	# Pivot sits on the fork atop the post (matches the fitted base).
	_arm = Node3D.new()
	_arm.position = Vector3(-0.2, 0.32, 0)
	add_child(_arm)
	_arm_model = ARM.instantiate()
	_arm.add_child(_arm_model)
	MeshFit.fit_centered(_arm_model, 0.78)
	MeshFit.matte(_arm_model)
	_arm_model.position.x += 0.06  # mouth side slightly longer past the pivot
	_arm.rotation.z = 0.22         # resting: mouth up, catching the stream
	if not _pending_variant.is_empty():
		apply_variant(_pending_variant)

## Capacity variant — quick 1 / classic 2 / patient 5; arm length hints size.
func apply_variant(v: Dictionary) -> void:
	_fills_to_tip = int(v.get("fills", 2))
	if _arm_model == null:
		_pending_variant = v   # icons/ghost apply before _ready
		return
	var sx: float = 0.85 if _fills_to_tip <= 1 else (1.25 if _fills_to_tip >= 5 else 1.0)
	_arm_model.scale.x = _arm_model.scale.x / maxf(_arm.get_meta("armscale", 1.0), 0.001) * sx
	_arm.set_meta("armscale", sx)

## One tick of pouring water (called by StreamManager every impact interval).
## Remembers the stream's DYE so the dump pours the same colour onward.
func fill(color: Color = Color(0.282, 0.792, 0.894)) -> void:
	if _dumping:
		return
	_fill_color = color
	_fill_count += 1
	# Small dip as it takes on weight (clamped so a patient 5-fill arm never
	# droops past its tipping angle early).
	var tw := create_tween()
	tw.tween_property(_arm, "rotation:z", 0.22 - minf(0.06 * _fill_count, 0.24), 0.18)
	if _fill_count >= _fills_to_tip:
		_dump()

func _dump() -> void:
	_dumping = true
	_fill_count = 0
	StreamManager.add_temp_source(grid_cell, DUMP_SECONDS, _fill_color)
	AudioManager.play_shishi_knock(global_position)
	var tw := create_tween()
	tw.tween_property(_arm, "rotation:z", -0.55, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)      # tip! water pours
	tw.tween_interval(DUMP_SECONDS * 0.6)
	tw.tween_property(_arm, "rotation:z", 0.22, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)  # swing back "cốc"
	tw.tween_callback(func(): _dumping = false)
