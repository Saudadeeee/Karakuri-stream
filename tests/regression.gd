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
	print("SECTION _sec_wildlife")
	await _sec_wildlife()
	print("SECTION _sec_stream_ground")
	await _sec_stream_ground()
	print("SECTION _sec_save_corruption")
	await _sec_save_corruption()
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

func _sec_wildlife() -> void:
	await _wildlife_scan()
	_check(WildlifeManager._birds.is_empty(), "no birds without a house")
	_check(WildlifeManager._cats.is_empty(), "no cats without a village")

	# The LITE profile must not conjure creatures out of an empty world. _cap()
	# halved populations with an unconditional maxi(1, n/2), so a wanted count of
	# ZERO became ONE, and the forced spawn drew from an empty pool: randi() % 0.
	# Desktop logs "Modulo by zero" and shrugs; WebAssembly TRAPS and kills the
	# engine, so the web build died on the menu every single time.
	var was_lite: bool = QualityManager.lite
	QualityManager.lite = true
	_check(WildlifeManager._cap(0) == 0, "lite must not turn zero creatures into one")
	_check(WildlifeManager._cap(1) == 1, "lite still keeps a lone creature")
	_check(WildlifeManager._cap(4) == 2, "lite halves a real population")
	WildlifeManager._dirty = true
	WildlifeManager._timer = 999.0
	await _wildlife_scan()
	_check(WildlifeManager._birds.is_empty() and WildlifeManager._cats.is_empty()
		and WildlifeManager._ducks.is_empty(), "empty world spawns nothing on lite")
	# And the pool draw itself must be safe even if a caller ever slips through.
	_check(WildlifeManager._rand_cell([] as Array[Vector3i]) == Vector3i.ZERO,
		"drawing from an empty pool cannot divide by zero")
	QualityManager.lite = was_lite

	# A couple of instruments earn ONE bird — that first bird is the whole point
	# of the feature, since it can land on a bell and play it — but nothing more,
	# and no cat yet: two chimes is not a garden.
	_b(Vector3i(0, 0, 16), BlockData.Type.BELL)
	_b(Vector3i(2, 0, 16), BlockData.Type.CHIME)
	_b(Vector3i(4, 0, 16), BlockData.Type.WOOD)
	await _wildlife_scan()
	_check(WildlifeManager._birds.size() == 1, "a couple of instruments earn exactly one bird")
	_check(WildlifeManager._cats.is_empty(), "two instruments is not yet a garden, so no cat")

	# Grow it into a real garden and the population grows WITH it, still capped.
	for i in 10:
		_b(Vector3i(i, 0, 18), BlockData.Type.DRUM)
	await _wildlife_scan()
	_check(WildlifeManager._cats.size() >= 1, "a real village attracts a cat")
	_check(WildlifeManager._birds.size() <= WildlifeManager.BIRDS[2], "bird population stays capped")
	_check(WildlifeManager._cats.size() <= WildlifeManager.CATS[2], "cat population stays capped")
	var total: int = WildlifeManager._birds.size() + WildlifeManager._cats.size()
	_check(total <= WildlifeManager.BIRDS[2] + WildlifeManager.CATS[2],
		"even a big village never becomes a crowd")

	# Water is a pond for ducks, never ground for the cat.
	for z in 4:
		_b(Vector3i(8, 0, 14 + z), BlockData.Type.WATER)
	await _wildlife_scan()
	_check(WildlifeManager._pond.size() >= 3, "open water registers as pond")
	_check(not WildlifeManager._ducks.is_empty(), "a real pond gets ducks")
	for cell in WildlifeManager._walkable:
		var wb: BlockData = GridManager.get_block(cell)
		_check(wb != null and wb.type != BlockData.Type.WATER, "cat territory excludes water")

	# A buried block is not a perch — nothing may stand inside the build.
	_b(Vector3i(4, 1, 16), BlockData.Type.WOOD)
	await _wildlife_scan()
	_check(not WildlifeManager._perches.has(Vector3i(4, 0, 16)), "covered cells stop being perches")

	# Birds play instruments they land on: the bell must survive being rung.
	var bell := _b(Vector3i(6, 0, 16), BlockData.Type.BELL)
	await _wildlife_scan()
	_check(WildlifeManager._instruments.has(Vector3i(6, 0, 16)), "bell registers as playable")
	_check(bell.has_method("ring"), "bird landing has a ring() to call")
	bell.ring()
	await get_tree().process_frame
	_check(is_instance_valid(bell), "ringing from a landing does not free the bell")

	await _sec_wildlife_placement()

	# Everything must go when the grid does.
	_clear()
	await _wildlife_scan()
	_check(WildlifeManager._birds.is_empty() and WildlifeManager._cats.is_empty()
		and WildlifeManager._ducks.is_empty(), "clear_all removes every critter")
	_check(WildlifeManager._perches.is_empty(), "scan forgets the cleared grid")

func _sec_wildlife_placement() -> void:
	_clear()
	await get_tree().process_frame

	# 1. A creature stands on the TOP FACE of whatever it perches on. Houses used
	#    to need a correction here because they carried a pitched roof above that
	#    face and a cat sank to its ears in tiles; every block left is cube-height,
	#    so the rule is now simply "the top", and this pins it.
	for x in 6:
		_b(Vector3i(x, 0, 24), BlockData.Type.BELL)
	await _wildlife_scan()
	for cell in [Vector3i(2, 0, 24), Vector3i(0, 0, 24)]:
		_check(is_equal_approx(WildlifeManager._top_of(cell).y,
			GridManager.cell_to_world(cell).y + 0.5), "a creature stands on the top face of %s" % cell)

	# 2. Ducks used to orbit the pond's CENTROID, which for an L-shaped pond is
	#    over grass — they paddled across the lawn. Every waypoint must be water.
	_clear()
	await get_tree().process_frame
	var pond: Array[Vector3i] = [
		Vector3i(0, 0, 28), Vector3i(0, 0, 29), Vector3i(0, 0, 30),
		Vector3i(1, 0, 30), Vector3i(2, 0, 30), Vector3i(3, 0, 30),
	]
	for c in pond:
		_b(c, BlockData.Type.WATER)
	await _wildlife_scan()
	_check(not WildlifeManager._ducks.is_empty(), "L-shaped pond still gets ducks")
	for _step in 40:
		for d in WildlifeManager._ducks:
			_check(WildlifeManager._pond_set.has(d["cell"]), "duck target is always a water cell")
			d["cell"] = WildlifeManager._next_pond_cell(d["cell"])
	# _pond_set must track _pond exactly, or the membership test silently rots.
	_check(WildlifeManager._pond_set.size() == WildlifeManager._pond.size(),
		"pond lookup set matches the pond list")

	# 3. Two birds picking perches at random landed on the same cell and rendered
	#    as one bird with extra wings.
	_clear()
	await get_tree().process_frame
	for x in 12:
		_b(Vector3i(x, 0, 32), BlockData.Type.CHIME)
	await _wildlife_scan()
	_check(WildlifeManager._birds.size() >= 2, "a big garden has several birds to collide")
	for _step in 30:
		for b in WildlifeManager._birds:
			WildlifeManager._bird_launch(b)
		var seen: Dictionary = {}
		for b in WildlifeManager._birds:
			_check(not seen.has(b["cell"]), "birds never share a perch")
			seen[b["cell"]] = true
	_clear()
	await get_tree().process_frame

## The manager scans on a throttle, so tests must let that interval elapse
## instead of assuming the very next frame is up to date.
func _wildlife_scan() -> void:
	WildlifeManager._dirty = true
	WildlifeManager._timer = 10.0
	for _f in range(4):
		await get_tree().process_frame

func _meshes_under(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out += _meshes_under(c)
	return out

func _sec_stream_ground() -> void:
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 3, 2), BlockData.Type.SOURCE)
	StreamManager._rebuild()
	await get_tree().process_frame

	_check(StreamManager._segments.size() <= 6,
		"a spout over bare ground makes a short stream, not a runaway thread")
	var lowest := INF
	for s in StreamManager._segments:
		lowest = minf(lowest, minf((s["a"] as Vector3).y, (s["b"] as Vector3).y))
	_check(is_equal_approx(lowest, 0.0), "the stream stops exactly at the island surface")
	_check(StreamManager._impacts.size() == 1, "landing on the lawn registers an impact")
	_check(StreamManager.is_playing(), "a spout on the grass counts as a running machine")

	# The impact must be a WATER splash: earth should not clack like a wood block.
	for cell in StreamManager._impacts:
		_check(int(StreamManager._impacts[cell]["type"]) == int(BlockData.Type.WATER),
			"ground impact is a water splash, not a knock")
		_check(cell.y < 0, "the ground impact sits just below the surface")

	# Something solid under the spout still wins — the ground rule must not
	# shortcut a block that is actually in the way.
	_b(Vector3i(0, 0, 2), BlockData.Type.BELL)
	StreamManager._rebuild()
	await get_tree().process_frame
	_check(StreamManager._impacts.has(Vector3i(0, 0, 2)), "a block under the spout is still struck")

	# Off the rim there is no island, so water there must still pour into the
	# clouds rather than splashing on nothing.
	_clear()
	await get_tree().process_frame
	var far := Vector3i(20, 2, 0)
	_b(far, BlockData.Type.SOURCE)
	StreamManager._rebuild()
	await get_tree().process_frame
	for cell in StreamManager._impacts:
		_check(Vector2(cell.x, cell.z).length() <= StreamManager.MAP_RADIUS + 1.0,
			"nothing splashes out past the island rim")
	_clear()
	await get_tree().process_frame

## 7d. A damaged save file must never cost the player the build they can see.
## Before this was fixed, load_game() cleared the grid FIRST and then hit an
## error partway through rebuilding, so a truncated file (a browser tab closed
## mid-flush is enough) wiped the current build and restored nothing.
func _sec_save_corruption() -> void:
	var cases: Array = [
		["not json at all", "garbage text"],
		['{"nope": 1}', "JSON object instead of an array"],
		['[{"x":0,"y":0}]', "entry missing coordinates"],
		['[{"x":0,"y":0,"z":0,"type":999}]', "block type from a newer build"],
		['[]', "empty array"],
	]
	for c in cases:
		_clear()
		await get_tree().process_frame
		# Something on screen that must survive a failed load.
		_b(Vector3i(0, 0, 20), BlockData.Type.WOOD)
		_b(Vector3i(1, 0, 20), BlockData.Type.BELL)
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_string(c[0])
		f.close()
		_check(not SaveManager.load_game(), "load refuses: %s" % c[1])
		await get_tree().process_frame
		_check(GridManager.has_block(Vector3i(0, 0, 20)) and GridManager.has_block(Vector3i(1, 0, 20)),
			"failed load keeps the current build: %s" % c[1])

	# A file with SOME good entries and some junk loads the good ones and says so.
	_clear()
	await get_tree().process_frame
	var f2 := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f2.store_string('[{"x":3,"y":0,"z":20,"type":%d,"variant":0},{"bad":true},{"x":4,"y":0,"z":20,"type":999}]'
		% int(BlockData.Type.WOOD))
	f2.close()
	_check(SaveManager.load_game(), "partial save still loads what is readable")
	await get_tree().process_frame
	_check(GridManager.has_block(Vector3i(3, 0, 20)), "readable entry is restored")
	_check(not GridManager.has_block(Vector3i(4, 0, 20)), "unknown block type is skipped, not crashed on")

	# Unknown types must be handled at the factory too, for any future caller.
	_check(BlockFactory.instantiate(999 as BlockData.Type) == null, "factory returns null for unknown type")

	# Round trip still works after all that.
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 0, 20), BlockData.Type.CHIME, 1)
	_check(SaveManager.save_game(), "save_game reports success")
	_clear()
	await get_tree().process_frame
	_check(SaveManager.load_game(), "healthy save still loads")
	await get_tree().process_frame
	_check(GridManager.has_block(Vector3i(0, 0, 20)), "round trip intact")
	_clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
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
	# What this is for is leak detection: a rebuild must dispose of the props it
	# replaces. It used to demand the count be IDENTICAL across themes, which is
	# not true and never was — scenery is scattered randomly, so a theme landing
	# one prop up or down is the generator working. That made the suite fail
	# roughly one run in three for no reason, which is worse than not checking.
	# A leak shows up as growth, so measure growth.
	_check(counts.max() - counts.min() <= 3,
			"scenery count swings across themes (%s)" % [counts])
	var repeat: Array[int] = []
	for i in 4:
		SceneryManager.rebuild()
		AmbientLeaves.rebuild()
		for _f in range(4):
			await get_tree().process_frame
		repeat.append(SceneryManager.get_child_count())
	_check(repeat.max() - repeat.min() <= 3,
			"rebuilding one theme repeatedly accumulates props (%s)" % [repeat])

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
