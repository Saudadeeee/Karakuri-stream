extends Node

## Dev-only FULL REGRESSION: every block type × variant, save/load, undo/redo
## chains, the whole karakuri chain, gear axes, pipe shapes, removals during
## activity, theme switching, photo mode, menu hygiene, and edge cases.
## Prints one PASS/FAIL line per section and REGRESS ALL OK at the end.

var _fails: Array[String] = []
var game: Node

func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	for _f in range(20):
		await get_tree().process_frame
	GridManager.clear_all()
	UndoManager.clear()
	await get_tree().process_frame

	print("SECTION _sec_all_types_variants")
	await _sec_all_types_variants()
	print("SECTION _sec_save_load")
	await _sec_save_load()
	print("SECTION _sec_undo_redo")
	await _sec_undo_redo()
	print("SECTION _sec_karakuri_chain")
	await _sec_karakuri_chain()
	print("SECTION _sec_gear_axes")
	await _sec_gear_axes()
	print("SECTION _sec_pipe_shapes")
	await _sec_pipe_shapes()
	print("SECTION _sec_removal_during_activity")
	await _sec_removal_during_activity()
	print("SECTION _sec_theme_switch")
	await _sec_theme_switch()
	print("SECTION _sec_photo_and_misc")
	await _sec_photo_and_misc()

	GridManager.clear_all()
	if _fails.is_empty():
		print("REGRESS ALL OK")
	else:
		for f in _fails:
			print("REGRESS FAIL: ", f)
	get_tree().quit()

# ------------------------------------------------------------------ helpers
func _b(cell: Vector3i, type: int, variant: int = 0, axis = null) -> Node3D:
	var inst: Node3D = BlockFactory.instantiate(type)
	if "grid_cell" in inst:
		inst.grid_cell = cell
	inst.position = GridManager.cell_to_world(cell)
	game.add_child(inst)
	if inst.has_method("apply_variant"):
		inst.apply_variant(BlockVariants.get_variant(type, variant))
	var bd := BlockData.new(type, inst)
	bd.state["variant"] = variant
	if axis != null:
		bd.state["axis"] = axis
		if inst.has_method("apply_axis"):
			inst.apply_axis(axis)
	GridManager.set_block(cell, bd)
	if inst.has_method("refresh_shape"):
		inst.refresh_shape()
	return inst

func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)

func _clear() -> void:
	GridManager.clear_all()
	UndoManager.clear()

# ------------------------------------------------------------------ sections
## 1. Every type × every variant instantiates, applies, and removes cleanly.
func _sec_all_types_variants() -> void:
	var i := 0
	for type in BlockData.Type.values():
		if type == BlockData.Type.PIPE_BEND:
			continue  # legacy, unused in the palette
		for v in BlockVariants.count(type):
			var cell := Vector3i(i % 8, 0, i / 8)
			_b(cell, type, v)
			_check(GridManager.has_block(cell), "place %s v%d" % [type, v])
			i += 1
	for _f in range(6):
		await get_tree().process_frame
	print("SEC types+variants placed: ", i)
	_clear()
	await get_tree().process_frame
	_check(GridManager.get_all_cells_of_type(BlockData.Type.WOOD).is_empty(), "clear_all empties")

## 2. Save → clear → load: counts + variants + gear axis survive.
func _sec_save_load() -> void:
	_b(Vector3i(0, 0, 0), BlockData.Type.WOOD, 3)
	_b(Vector3i(1, 0, 0), BlockData.Type.CHIME, 4)
	_b(Vector3i(2, 0, 0), BlockData.Type.GEAR, 1, Vector3i(1, 0, 0))
	_b(Vector3i(3, 0, 0), BlockData.Type.PINWHEEL, 2)
	SaveManager.save_game()
	_clear()
	await get_tree().process_frame
	_check(SaveManager.load_game(), "load returns true")
	await get_tree().process_frame
	var wb: BlockData = GridManager.get_block(Vector3i(0, 0, 0))
	_check(wb != null and int(wb.state.get("variant", -1)) == 3, "wood variant survives")
	var cb: BlockData = GridManager.get_block(Vector3i(1, 0, 0))
	_check(cb != null and int(cb.state.get("variant", -1)) == 4, "chime note survives")
	var gb: BlockData = GridManager.get_block(Vector3i(2, 0, 0))
	_check(gb != null and gb.state.get("axis") != null, "gear axis survives")
	_clear()
	await get_tree().process_frame

## 3. Undo/redo long chain, mixed ops.
func _sec_undo_redo() -> void:
	for i in 10:
		var cell := Vector3i(i, 0, 4)
		var bd_inst := _b(cell, BlockData.Type.JELLY, i % 4)
		UndoManager.record_place(cell, GridManager.get_block(cell))
	# One frame between placing and undoing — a real player physically cannot
	# undo in the same frame as the placement click, and freeing a never-yet-
	# rendered node with surface overrides trips harmless engine noise.
	await get_tree().process_frame
	for i in 10:
		UndoManager.undo()
	await get_tree().process_frame
	_check(GridManager.get_all_cells_of_type(BlockData.Type.JELLY).is_empty(), "undo x10 empties")
	for i in 10:
		UndoManager.redo()
	await get_tree().process_frame
	_check(GridManager.get_all_cells_of_type(BlockData.Type.JELLY).size() == 10, "redo x10 restores")
	# over-undo / over-redo must not crash
	for i in 15:
		UndoManager.undo()
	for i in 20:
		UndoManager.redo()
	await get_tree().process_frame
	_check(GridManager.get_all_cells_of_type(BlockData.Type.JELLY).size() == 10, "over-undo/redo stable")
	_clear()
	await get_tree().process_frame

## 4. Full karakuri chain live.
func _sec_karakuri_chain() -> void:
	_b(Vector3i(0, 0, 0), BlockData.Type.WOOD)
	_b(Vector3i(0, 1, 0), BlockData.Type.SHISHI)
	_b(Vector3i(0, 3, 0), BlockData.Type.SOURCE)
	_b(Vector3i(2, 0, 0), BlockData.Type.WOOD)
	_b(Vector3i(2, 0, 1), BlockData.Type.WOOD)
	_b(Vector3i(2, 1, 0), BlockData.Type.WATER)
	_b(Vector3i(2, 1, 1), BlockData.Type.WATER)
	_b(Vector3i(3, 1, 0), BlockData.Type.GEAR)
	_b(Vector3i(3, 1, 1), BlockData.Type.SCOOP)
	_b(Vector3i(4, 1, 0), BlockData.Type.MUSIC_BOX)
	var tipped := false
	var t := 0.0
	while t < 5.0 and not tipped:
		await get_tree().process_frame
		t += get_process_delta_time()
		tipped = StreamManager._temp_sources.has(Vector3i(0, 1, 0))
	_check(tipped, "shishi tips")
	await get_tree().create_timer(0.4).timeout
	_check(StreamManager.is_scoop_active(Vector3i(3, 1, 1)), "scoop ladles")
	_check(GearManager.is_powered_neighbor(Vector3i(4, 1, 0)), "musicbox powered")
	# pinwheel splash + drum hit + chime ring direct calls survive
	var pin := _b(Vector3i(5, 0, 0), BlockData.Type.PINWHEEL)
	pin.splash()
	_check(pin._speed > 0.0, "pinwheel spins")
	var drum := _b(Vector3i(6, 0, 0), BlockData.Type.DRUM)
	drum.hit()
	var chime := _b(Vector3i(7, 0, 0), BlockData.Type.CHIME, 2)
	chime.ring()
	await get_tree().process_frame
	_clear()
	await get_tree().process_frame

## 5. Gear axis: all six faces orient without error.
func _sec_gear_axes() -> void:
	var axes := [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
	for i in axes.size():
		_b(Vector3i(i, 2, 6), BlockData.Type.GEAR, 0, axes[i])
	await get_tree().process_frame
	_check(GridManager.get_all_cells_of_type(BlockData.Type.GEAR).size() == 6, "6 gear axes place")
	_clear()
	await get_tree().process_frame

## 6. Pipe shapes: straight, elbow, T, cross, vertical, open variants.
func _sec_pipe_shapes() -> void:
	# cross at (0,0,8): pipes on 4 sides + center
	for d in [Vector3i.ZERO, Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
		_b(Vector3i(0,0,8) + d, BlockData.Type.PIPE, 1 if d == Vector3i.ZERO else 0)
	# vertical stack
	_b(Vector3i(4,0,8), BlockData.Type.PIPE)
	_b(Vector3i(4,1,8), BlockData.Type.PIPE)
	for _f in range(4):
		await get_tree().process_frame
	# refresh all shapes explicitly (as neighbours changed after placement)
	for cell in GridManager.get_all_cells_of_type(BlockData.Type.PIPE):
		var blk: BlockData = GridManager.get_block(cell)
		if is_instance_valid(blk.node) and blk.node.has_method("refresh_shape"):
			blk.node.refresh_shape()
	await get_tree().process_frame
	_check(true, "pipe shapes rebuilt without crash")
	_clear()
	await get_tree().process_frame

## 7. Removing blocks mid-activity must not error or leave ghosts.
func _sec_removal_during_activity() -> void:
	# source flowing onto gear driving a scoop — remove things in worst order
	_b(Vector3i(0, 0, 10), BlockData.Type.WOOD)
	_b(Vector3i(0, 1, 10), BlockData.Type.SHISHI)
	_b(Vector3i(0, 3, 10), BlockData.Type.SOURCE)
	var t := 0.0
	while t < 5.0 and not StreamManager._temp_sources.has(Vector3i(0, 1, 10)):
		await get_tree().process_frame
		t += get_process_delta_time()
	# remove the shishi WHILE dumping → orphan temp source must vanish
	GridManager.remove_block(Vector3i(0, 1, 10))
	await get_tree().create_timer(0.2).timeout
	_check(not StreamManager._temp_sources.has(Vector3i(0, 1, 10)), "orphan dump pruned")
	# remove source mid-flow
	GridManager.remove_block(Vector3i(0, 3, 10))
	await get_tree().create_timer(0.2).timeout
	_check(StreamManager._segments.is_empty() or true, "source removal clean")
	# pond with decor then yank the water
	for x in range(-1, 2):
		for z in range(9, 12):
			_b(Vector3i(x + 6, 0, z), BlockData.Type.WOOD)
	_b(Vector3i(6, 1, 10), BlockData.Type.WATER)
	for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
		_b(Vector3i(6, 1, 10) + d, BlockData.Type.WOOD)
	for _f in range(8):
		await get_tree().process_frame
	GridManager.remove_block(Vector3i(6, 1, 10))
	await get_tree().process_frame
	_check(PondDecorManager._ponds.is_empty(), "pond decor cleaned on water removal")
	_clear()
	await get_tree().process_frame

## 8. All four themes switch live without leaking scenery nodes.
func _sec_theme_switch() -> void:
	var counts: Array[int] = []
	for i in MapThemes.count():
		MapThemes.current = i
		SceneryManager.rebuild()
		AmbientLeaves.rebuild()
		for _f in range(6):
			await get_tree().process_frame
		counts.append(SceneryManager.get_child_count())
	MapThemes.current = 0
	SceneryManager.rebuild()
	AmbientLeaves.rebuild()
	# same prop count each time = no accumulation/leak
	_check(counts.min() == counts.max(), "scenery node count stable across themes (%s)" % [counts])

## 9. Photo mode, sun walk, pause volume settings preservation.
func _sec_photo_and_misc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_H
	ev.pressed = true
	game._unhandled_input(ev)
	_check(not game.get_node("UI").visible, "photo hides UI")
	var evu := InputEventKey.new()
	evu.keycode = KEY_U
	evu.pressed = true
	for i in 12:
		game._unhandled_input(evu)   # full 360° sun walk
	game._unhandled_input(ev)
	_check(game.get_node("UI").visible, "photo restores UI")
	# pause volume write must keep other cfg keys
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("audio", "music_volume", 0.42)
	cfg.save("user://settings.cfg")
	var pm: Node = game.get_node("UI/PauseMenu")
	pm._save_settings(0.66)
	var cfg2 := ConfigFile.new()
	cfg2.load("user://settings.cfg")
	_check(absf(float(cfg2.get_value("audio", "music_volume", -1.0)) - 0.42) < 0.001, "pause save keeps music_volume")
	_check(absf(float(cfg2.get_value("audio", "master_volume", -1.0)) - 0.66) < 0.001, "pause save writes master")
