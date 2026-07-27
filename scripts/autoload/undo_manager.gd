extends Node

## Undo/redo for block placement — the Townscaper feel of fearless fiddling.
## PlacementController records each place/remove; Ctrl+Z walks back, Ctrl+Y /
## Ctrl+Shift+Z walks forward. An action stores everything needed to recreate
## the block (type, variant, gear axis), so undoing a removal truly restores it.

const MAX_STACK: int = 200

var _undo: Array = []   # [{op, cell, type, variant, axis}]
var _redo: Array = []

func record_place(cell: Vector3i, block: BlockData) -> void:
	_push({"op": "place", "cell": cell, "type": block.type,
		"variant": int(block.state.get("variant", 0)), "axis": block.state.get("axis")})

func record_remove(cell: Vector3i, block: BlockData) -> void:
	_push({"op": "remove", "cell": cell, "type": block.type,
		"variant": int(block.state.get("variant", 0)), "axis": block.state.get("axis")})

func _push(action: Dictionary) -> void:
	_undo.append(action)
	if _undo.size() > MAX_STACK:
		_undo.pop_front()
	_redo.clear()   # new action invalidates the redo branch

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and event.ctrl_pressed):
		return
	if event.keycode == KEY_Z and not event.shift_pressed:
		undo()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed):
		redo()
		get_viewport().set_input_as_handled()

func undo() -> void:
	if _undo.is_empty():
		return
	var a: Dictionary = _undo.pop_back()
	_apply(a, true)
	_redo.append(a)

func redo() -> void:
	if _redo.is_empty():
		return
	var a: Dictionary = _redo.pop_back()
	_apply(a, false)
	_undo.append(a)

## Undoing a PLACE removes the block; undoing a REMOVE restores it (reversed=
## false replays the action as recorded).
func _apply(a: Dictionary, reversed: bool) -> void:
	var placing: bool = (a["op"] == "place") != reversed
	var cell: Vector3i = a["cell"]
	if placing:
		if GridManager.has_block(cell):
			return
		_restore_block(cell, a)
	else:
		GridManager.remove_block(cell)

## Same recreate path SaveManager uses on load, so restored blocks look and
## behave exactly like the original (variant, gear axis, pipe auto-shape).
func _restore_block(cell: Vector3i, a: Dictionary) -> void:
	var type: int = a["type"]
	var instance: Node3D = BlockFactory.instantiate(type)
	var scene_root: Node = get_tree().current_scene
	scene_root.add_child(instance)
	instance.position = GridManager.cell_to_world(cell)
	if "grid_cell" in instance:
		instance.grid_cell = cell
	var block := BlockData.new(type, instance)
	block.state["variant"] = a["variant"]
	if instance.has_method("apply_variant"):
		instance.apply_variant(BlockVariants.get_variant(type, a["variant"]))
	if a.get("axis") != null:
		block.state["axis"] = a["axis"]
		if instance.has_method("apply_axis"):
			instance.apply_axis(a["axis"])
	GridManager.set_block(cell, block)
	if instance.has_method("refresh_shape"):
		instance.refresh_shape()
	elif instance.has_method("face_adjacent_water"):
		instance.face_adjacent_water()

func clear() -> void:
	_undo.clear()
	_redo.clear()
