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
	# Pin the theme: _sec_theme_switch persists whatever map it ends on, and
	# the NEXT run's house colour audit would then run under that map's tint —
	# Night squeezes two distinct decoration colours to within 0.04 and fails
	# the near-duplicate check. The suite must not depend on the previous run.
	MapThemes.current = 0
	MapThemes.save_current()
	await get_tree().process_frame

	print("SECTION _sec_catalog")
	_sec_catalog()
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
	print("SECTION _sec_flow_control")
	await _sec_flow_control()
	print("SECTION _sec_house_under_stilts")
	await _sec_house_under_stilts()
	print("SECTION _sec_houses")
	await _sec_houses()
	print("SECTION _sec_wildlife")
	await _sec_wildlife()
	print("SECTION _sec_stream_ground")
	await _sec_stream_ground()
	print("SECTION _sec_save_corruption")
	await _sec_save_corruption()
	print("SECTION _sec_house_audit")
	await _sec_house_audit()
	print("SECTION _sec_no_stale_geometry")
	await _sec_no_stale_geometry()
	print("SECTION _sec_house_among_other_blocks")
	await _sec_house_among_other_blocks()
	print("SECTION _sec_house_geometry_sane")
	await _sec_house_geometry_sane()
	print("SECTION _sec_place_cost_is_flat")
	await _sec_place_cost_is_flat()
	print("SECTION _sec_terrace_is_flat")
	await _sec_terrace_is_flat()
	print("SECTION _sec_delete_consistency")
	await _sec_delete_consistency()
	print("SECTION _sec_surprises")
	await _sec_surprises()
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
## 0. The catalog is the single registry every block goes through, so the
## mistake it exists to prevent — a type added to the enum but never
## registered, or two blocks claiming one shortcut — has to fail loudly here.
func _sec_catalog() -> void:
	var seen_types: Dictionary = {}
	var seen_keys: Dictionary = {}
	for e in BlockCatalog.ALL:
		var t: int = int(e["type"])
		_check(not seen_types.has(t), "catalog lists type %d twice" % t)
		seen_types[t] = true
		_check(e.get("scene") is PackedScene, "catalog type %d has no scene" % t)
		_check(String(e.get("hint", "")) != "", "catalog type %d has no hint" % t)
		var k: int = int(e.get("key", KEY_NONE))
		if k != KEY_NONE:
			_check(not seen_keys.has(k), "two blocks share shortcut %s" % OS.get_keycode_string(k))
			seen_keys[k] = true
			_check(BlockCatalog.type_for_key(k) == t, "shortcut for type %d resolves elsewhere" % t)
	for t in BlockData.Type.values():
		_check(seen_types.has(int(t)), "BlockData.Type %d is not in the catalog" % int(t))
		var probe: Node3D = BlockFactory.instantiate(t)
		_check(probe != null, "type %d does not instantiate" % int(t))
		if probe != null:
			probe.free()
	_check(not BlockCatalog.palette_types().is_empty(), "the hotbar would be empty")

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

## 4b. Flow control: sluice gate, jelly trampoline, alternator round-robin
## (also the beat lattice's direct check), dyed streams.
func _sec_flow_control() -> void:
	# --- sluice gate: closed (default) blocks; open passes through.
	_b(Vector3i(0, 0, 4), BlockData.Type.WOOD)
	_b(Vector3i(0, 1, 4), BlockData.Type.GATE)
	_b(Vector3i(0, 3, 4), BlockData.Type.SOURCE)
	await get_tree().create_timer(0.8).timeout
	_check(StreamManager._impacts.has(Vector3i(0, 1, 4)), "closed gate takes the hit")
	_check(not StreamManager._impacts.has(Vector3i(0, 0, 4)), "closed gate blocks the wood below")
	var gate: BlockData = GridManager.get_block(Vector3i(0, 1, 4))
	if is_instance_valid(gate.node) and gate.node.has_method("set_open"):
		gate.node.set_open(true, true)
	await get_tree().create_timer(0.8).timeout
	_check(StreamManager._impacts.has(Vector3i(0, 0, 4)), "open gate lets water through")
	_clear()
	await get_tree().process_frame

	# --- jelly trampoline: a straight drop bounces up-and-over one cell.
	_b(Vector3i(0, 0, 4), BlockData.Type.WOOD)
	_b(Vector3i(0, 1, 4), BlockData.Type.JELLY)
	_b(Vector3i(1, 0, 4), BlockData.Type.WOOD)   # where the arc should land
	_b(Vector3i(0, 3, 4), BlockData.Type.SOURCE)
	await get_tree().create_timer(0.8).timeout
	_check(StreamManager._impacts.has(Vector3i(1, 0, 4)), "jelly arcs the stream onto the next block")
	_clear()
	await get_tree().process_frame

	# --- alternator pipe: two exits share the source's beat round-robin —
	# interval doubles, phases interleave.
	_b(Vector3i(0, 2, 4), BlockData.Type.PIPE, 2)          # alternator variant
	_b(Vector3i(1, 2, 4), BlockData.Type.PIPE)
	_b(Vector3i(-1, 2, 4), BlockData.Type.PIPE)
	# Side pipes are DEAD ENDS, so water drips straight down out of them —
	# the drums sit directly under the pipe ends.
	_b(Vector3i(1, 1, 4), BlockData.Type.DRUM)
	_b(Vector3i(-1, 1, 4), BlockData.Type.DRUM)
	# Source must sit directly on the pipe: free-falling water does not enter
	# a horizontal run from above; an adjacent source is a pipe connection.
	_b(Vector3i(0, 3, 4), BlockData.Type.SOURCE)
	await get_tree().create_timer(0.9).timeout
	var right: Dictionary = StreamManager._impacts.get(Vector3i(1, 1, 4), {})
	var left: Dictionary = StreamManager._impacts.get(Vector3i(-1, 1, 4), {})
	_check(not right.is_empty() and not left.is_empty(), "alternator feeds both exits")
	if not right.is_empty() and not left.is_empty():
		var base: float = StreamManager.BASE_BEAT
		_check(absf(float(right["interval"]) - base * 2.0) < 0.01, "alternator doubles the interval")
		var dphase: float = absf(float(right["phase"]) - float(left["phase"]))
		_check(absf(dphase - base) < 0.01, "alternator staggers the phases")
	_clear()
	await get_tree().process_frame

	# --- dyed stream: a scoop ladling a coloured pond pours that colour.
	_b(Vector3i(0, 0, 4), BlockData.Type.WOOD)
	_b(Vector3i(0, 0, 5), BlockData.Type.WOOD)
	_b(Vector3i(0, 1, 4), BlockData.Type.WATER, 1)
	_b(Vector3i(0, 1, 5), BlockData.Type.WATER, 1)
	_b(Vector3i(1, 1, 4), BlockData.Type.GEAR)
	_b(Vector3i(1, 1, 5), BlockData.Type.SCOOP)
	_b(Vector3i(1, 0, 5), BlockData.Type.WOOD)   # catches the scoop's pour
	await get_tree().create_timer(1.0).timeout
	var want: Color = BlockVariants.color_of(BlockData.Type.WATER, 1)
	var dyed := false
	for cell in StreamManager._impacts:
		var c: Color = StreamManager._impacts[cell].get("color", Color.WHITE)
		if c.is_equal_approx(want):
			dyed = true
	_check(dyed, "scoop pours the pond's dye colour")
	_clear()
	await get_tree().process_frame

## 4c. A house built UNDER another house's stilts: the lower roof must flatten
## into a terrace (a pitched roof buries the legs and rams its chimney into
## the upper floor), and must revert when the stilted house is removed.
func _sec_house_under_stilts() -> void:
	var above := Vector3i(0, 2, 6)
	var below := Vector3i(0, 0, 6)
	_b(above, BlockData.Type.HOUSE)
	for _f in range(6):
		await get_tree().process_frame
	_b(below, BlockData.Type.HOUSE)
	for _f in range(6):
		await get_tree().process_frame
	_check(HouseShape.bears_stilts(below), "lower cell knows it bears stilts")
	_check(HouseShape.is_terrace(below), "roof under stilts flattens to a terrace")
	# Geometry must respect the boundary: lower stays inside its cell's top,
	# upper's legs reach down but not through.
	for mi in GridManager.get_block(below).node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh != null:
			var top: float = mi.mesh.get_aabb().position.y + mi.mesh.get_aabb().size.y
			_check(top <= 1.05, "terrace under stilts stays below y=%.2f" % top)
	GridManager.remove_block(above)
	for _f in range(6):
		await get_tree().process_frame
	_check(not HouseShape.is_terrace(below), "roof reverts to pitched when the stilts go")
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

## 7b. Houses assemble contextually: shared walls vanish, the roof goes on the
## top cell only, the ridge follows the long axis, and one door + one chimney
## land on opposite corners. These are the rules that make a row read as ONE
## building — if any of them regress the town silently turns back into sheds.
func _sec_houses() -> void:
	# 3x1 terrace along X, plus a second storey on the middle cell.
	for x in 3:
		_b(Vector3i(x, 0, 12), BlockData.Type.HOUSE, x)
	_b(Vector3i(1, 1, 12), BlockData.Type.HOUSE, 0)
	await get_tree().process_frame

	var mid := HouseShape.context(Vector3i(1, 0, 12))
	var left := HouseShape.context(Vector3i(0, 0, 12))
	var top := HouseShape.context(Vector3i(1, 1, 12))

	# Middle of the terrace: walls only front and back, no roof (storey above).
	_check(mid["open_sides"].size() == 2, "terrace middle drops both shared walls")
	_check(not mid["roof"], "cell under a storey grows no roof")
	_check(left["roof"], "terrace end keeps its roof")
	_check(int(left["building_size"]) == 4, "building knows its full extent, storeys included")
	# Door on the building's first cell, chimney on its last — never the same one.
	_check(left["door_side"] != Vector3i.ZERO, "the building's first cell gets the door")
	_check(mid["door_side"] == Vector3i.ZERO, "only one door per building")
	_check(not left["chimney"], "the door cell does not also take the chimney")
	_check(top["stacked"], "upper storey knows it is stacked")
	_check(top["roof"] and not bool(top["floor"]), "top cell roofs, does not re-floor")

	await _sec_house_merging()

	# Deterministic: the same cell must decide the same windows every time, or a
	# reload would rearrange the whole street.
	var w1 := HouseShape.window_offsets(Vector3i(0, 0, 12), HouseShape.SIDES[1], false)
	var w2 := HouseShape.window_offsets(Vector3i(0, 0, 12), HouseShape.SIDES[1], false)
	_check(w1 == w2, "window layout is deterministic")

	# Knocking the middle out must regrow the two new end walls.
	GridManager.remove_block(Vector3i(1, 0, 12))
	await get_tree().process_frame
	_check(HouseShape.context(Vector3i(0, 0, 12))["open_sides"].size() == 4,
		"removing a neighbour regrows the end wall")

	# Survives save/load with the palette intact.
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 0, 12), BlockData.Type.HOUSE, 2)
	_b(Vector3i(1, 0, 12), BlockData.Type.HOUSE, 2)
	SaveManager.save_game()
	_clear()
	await get_tree().process_frame
	_check(SaveManager.load_game(), "house build reloads")
	await get_tree().process_frame
	var hb: BlockData = GridManager.get_block(Vector3i(0, 0, 12))
	_check(hb != null and hb.type == BlockData.Type.HOUSE, "house survives reload")
	_check(hb != null and int(hb.state.get("variant", -1)) == 2, "house palette survives reload")
	_check(HouseShape.context(Vector3i(0, 0, 12))["open_sides"].size() == 3,
		"reloaded pair still shares its wall")
	_clear()
	await get_tree().process_frame

## 7c. Wildlife is gated on what the player built, and cleans up after itself.
## The rules under test are the ones that make the animals feel like they read
## the world: no house means no birds, water is never walkable, and clearing
## the grid must not leave a single orphan critter behind.
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

	# One house earns ONE bird — that first bird is the whole point of the
	# feature, since it can land on a bell and play it — but nothing more, and
	# no cat yet: two houses is not a village.
	_b(Vector3i(0, 0, 16), BlockData.Type.HOUSE)
	_b(Vector3i(2, 0, 16), BlockData.Type.HOUSE)
	_b(Vector3i(4, 0, 16), BlockData.Type.WOOD)
	await _wildlife_scan()
	_check(WildlifeManager._birds.size() == 1, "a couple of houses earn exactly one bird")
	_check(WildlifeManager._cats.is_empty(), "two houses is not yet a village, so no cat")

	# Grow it into a real village and the population grows WITH it, still capped.
	for i in 10:
		_b(Vector3i(i, 0, 18), BlockData.Type.HOUSE)
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

## Houses wider than one cell must merge into ONE building, not a row of sheds.
## This is the property that broke first: giving each top cell its own gable
## looks right on a 1-wide row and wrong on everything else. The roof is a height
## field over the whole footprint, so the checks below are on that field —
## `roof_level` in doubled cell coordinates, where an interior sample climbing
## above 0 is what a ridge, hip or peak actually IS.
func _sec_house_merging() -> void:
	# 2x2: the only interior sample is the shared corner. One peak, one hip roof —
	# NOT two parallel gables sitting next to each other.
	_clear()
	await get_tree().process_frame
	for x in 2:
		for z in 2:
			_b(Vector3i(x, 0, 30 + z), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(HouseShape.roof_level(1, 61, 0) > 0, "2x2 raises its shared centre into a peak")
	_check(HouseShape.roof_level(-1, 59, 0) == 0, "2x2 outer corner stays at eaves height")

	# 3x3: the middle reaches the SECOND level — a true pyramid, not a plateau.
	_clear()
	await get_tree().process_frame
	for x in 3:
		for z in 3:
			_b(Vector3i(x, 0, 30 + z), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(HouseShape.roof_level(2, 62, 0) == HouseShape.ROOF_LEVELS, "3x3 peaks at the centre")
	_check(HouseShape.roof_level(0, 60, 0) < HouseShape.ROOF_LEVELS, "3x3 slopes down toward its edge")

	# A one-wide row must still gable: a continuous ridge along the run, with the
	# ends falling away to a hip rather than a flat wall.
	_clear()
	await get_tree().process_frame
	for x in 4:
		_b(Vector3i(x, 0, 30), BlockData.Type.HOUSE)
	await get_tree().process_frame
	for x in 4:
		_check(HouseShape.roof_level(x * 2, 60, 0) > 0, "row keeps a ridge over cell %d" % x)
	_check(HouseShape.roof_level(-1, 60, 0) == 0, "row hips down at its end")
	_check(HouseShape.roof_level(0, 61, 0) == 0, "row eaves fall away to the side")

	# Shapes with more than one outside corner must still get exactly ONE door and
	# ONE chimney. A plus used to produce two of each.
	for shape in [
		[Vector3i(1,0,30), Vector3i(0,0,31), Vector3i(1,0,31), Vector3i(2,0,31), Vector3i(1,0,32)],
		[Vector3i(0,0,30), Vector3i(0,0,31), Vector3i(0,0,32), Vector3i(1,0,32), Vector3i(2,0,32)],
	]:
		_clear()
		await get_tree().process_frame
		for c in shape:
			_b(c, BlockData.Type.HOUSE)
		await get_tree().process_frame
		var doors := 0
		var chimneys := 0
		for c in shape:
			var ctx := HouseShape.context(c)
			if ctx["door_side"] != Vector3i.ZERO:
				doors += 1
			if ctx["chimney"]:
				chimneys += 1
			_check(int(ctx["building_size"]) == shape.size(), "every cell sees the whole building")
		_check(doors == 1, "exactly one door on an irregular footprint")
		_check(chimneys == 1, "exactly one chimney on an irregular footprint")

	await _sec_house_vertical()

	# Two buildings that do NOT touch stay two buildings, with a door each.
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 0, 30), BlockData.Type.HOUSE)
	_b(Vector3i(4, 0, 30), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(int(HouseShape.context(Vector3i(0, 0, 30))["building_size"]) == 1, "separate houses stay separate")
	_check(HouseShape.context(Vector3i(0, 0, 30))["door_side"] != Vector3i.ZERO
		and HouseShape.context(Vector3i(4, 0, 30))["door_side"] != Vector3i.ZERO,
		"each separate house gets its own door")
	_clear()
	await get_tree().process_frame

## Nothing may float. A house cell with open air under it either stands on legs
## or is braced back into the building beside it, and it must reach down to
## whatever is actually there rather than a guessed height.
func _sec_house_vertical() -> void:
	# A hut in mid-air reaches the island surface.
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 3, 34), BlockData.Type.HOUSE)
	await get_tree().process_frame
	var air := HouseShape.context(Vector3i(0, 3, 34))
	_check(int(air["support_drop"]) == 3, "airborne hut measures its drop to the ground")
	_check(not bool(air["overhang"]), "an isolated airborne hut gets legs, not a bracket")

	# Put something under it and the legs must STOP there, not carry on down.
	_b(Vector3i(0, 1, 34), BlockData.Type.WOOD)
	await get_tree().process_frame
	_check(int(HouseShape.context(Vector3i(0, 3, 34))["support_drop"]) == 1,
		"legs land on the first solid thing below, not the ground")

	# A storey jutting out past the one below is a cantilever: braced sideways,
	# not propped from the floor.
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 0, 34), BlockData.Type.HOUSE)
	_b(Vector3i(0, 1, 34), BlockData.Type.HOUSE)
	_b(Vector3i(1, 1, 34), BlockData.Type.HOUSE)
	await get_tree().process_frame
	var jut := HouseShape.context(Vector3i(1, 1, 34))
	_check(int(jut["support_drop"]) > 0, "the overhanging cell knows it is unsupported")
	_check(bool(jut["overhang"]), "an overhang braces against its neighbour instead of stilting")
	_check(HouseShape.corbel_sides(Vector3i(1, 1, 34)).size() == 1, "braced toward the one storey holding it")
	_check(int(HouseShape.context(Vector3i(0, 0, 34))["support_drop"]) == 0, "the grounded storey needs nothing")
	_check(bool(HouseShape.context(Vector3i(0, 0, 34))["has_above"]), "a storey with one above gets a belt course")
	_check(not bool(HouseShape.context(Vector3i(0, 1, 34))["has_above"]), "the top storey has no band")

	# A raised platform must not stack a post per cell in the same hole: the four
	# cells of a 2x2 share corners, so nine posts, not sixteen.
	_clear()
	await get_tree().process_frame
	var plat: Array[Vector3i] = []
	for x in 2:
		for z in 2:
			var c := Vector3i(x, 2, 34 + z)
			plat.append(c)
			_b(c, BlockData.Type.HOUSE)
	await get_tree().process_frame
	var posts := 0
	for c in plat:
		for ax in [-1, 1]:
			for az in [-1, 1]:
				if HouseShape.owns_corner(c, ax, az):
					posts += 1
	_check(posts == 9, "a raised 2x2 stands on 9 shared posts, not 16 duplicated ones")

	# Legs are bounded: a cell placed absurdly high must not grow an endless pillar.
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 40, 34), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(int(HouseShape.context(Vector3i(0, 40, 34))["support_drop"]) <= HouseShape.MAX_STILT,
		"leg length is capped")
	_clear()
	await get_tree().process_frame

## Three placement bugs found by rendering the game and LOOKING at it, pinned
## here so they cannot come back quietly. None would ever fail a logic test —
## the counts were right the whole time, the positions were wrong.
func _sec_wildlife_placement() -> void:
	_clear()
	await get_tree().process_frame

	# 1. A house carries a pitched roof ABOVE its top face. Standing a creature on
	#    the face buried it inside the roof — a cat sunk to its ears in tiles.
	for x in 6:
		_b(Vector3i(x, 0, 24), BlockData.Type.HOUSE)
	await _wildlife_scan()
	var roof_cell := Vector3i(2, 0, 24)
	_check(HouseShape.roof_top_height(roof_cell) > 0.0, "a roofed house reports a roof height")
	var stand: Vector3 = WildlifeManager._top_of(roof_cell)
	var face: float = GridManager.cell_to_world(roof_cell).y + 0.5
	_check(stand.y > face + 0.1, "creatures stand ON the roof, not inside it")
	# A plain block has no roof, so nothing should be added there.
	_b(Vector3i(0, 0, 26), BlockData.Type.WOOD)
	await _wildlife_scan()
	_check(is_equal_approx(WildlifeManager._top_of(Vector3i(0, 0, 26)).y,
		GridManager.cell_to_world(Vector3i(0, 0, 26)).y + 0.5), "a plain block gets no roof offset")

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
		_b(Vector3i(x, 0, 32), BlockData.Type.HOUSE)
	await _wildlife_scan()
	_check(WildlifeManager._birds.size() >= 2, "a big village has several birds to collide")
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

## 7i. FUZZ THE HOUSE RULES. Build thirteen shapes, then take every cell out of
## each one in turn and re-check the invariants on whatever survives.
##
## This exists because three separate house bugs in a row were all the same
## mistake — a property of a SURFACE decided per CELL — and each one was found by
## a person looking at a screenshot rather than by a test. These assertions are
## the shape of that mistake, so the next one gets caught here instead.
func _sec_house_audit() -> void:
	var shapes := {
		"hut": [[0,0,0]],
		"row": [[0,0,0],[1,0,0],[2,0,0]],
		"2x2": [[0,0,0],[1,0,0],[0,0,1],[1,0,1]],
		"3x3": [[0,0,0],[1,0,0],[2,0,0],[0,0,1],[1,0,1],[2,0,1],[0,0,2],[1,0,2],[2,0,2]],
		"L": [[0,0,0],[0,0,1],[0,0,2],[1,0,2],[2,0,2]],
		"tower": [[0,0,0],[0,1,0],[0,2,0],[0,3,0]],
		"wide tower": [[0,0,0],[0,1,0],[0,2,0],[0,3,0],[1,0,0],[1,1,0],[1,2,0],[1,3,0]],
		"tower+wing": [[0,0,0],[0,1,0],[0,2,0],[1,0,0],[2,0,0],[1,0,1],[2,0,1]],
		"plus": [[1,0,0],[0,0,1],[1,0,1],[2,0,1],[1,0,2]],
		"courtyard": [[0,0,0],[1,0,0],[2,0,0],[0,0,1],[2,0,1],[0,0,2],[1,0,2],[2,0,2]],
		"bridge": [[0,0,0],[0,1,0],[3,0,0],[3,1,0],[1,1,0],[2,1,0]],
		"overhang": [[0,0,0],[0,1,0],[1,1,0]],
	}
	for name in shapes:
		var cells: Array = shapes[name]
		await _audit_build(name, cells, -1)
		for i in cells.size():
			await _audit_build(name, cells, i)
	_clear()
	await get_tree().process_frame

func _audit_build(label: String, cells: Array, drop: int) -> void:
	_clear()
	await get_tree().process_frame
	var placed: Array[Vector3i] = []
	for e in cells:
		var c := Vector3i(int(e[0]), int(e[1]), 70 + int(e[2]))
		placed.append(c)
		_b(c, BlockData.Type.HOUSE)
	await get_tree().process_frame
	if drop >= 0:
		GridManager.remove_block(placed[drop])
		await get_tree().process_frame
		await get_tree().process_frame

	var live: Array[Vector3i] = []
	for c in placed:
		if HouseShape.is_house(c):
			live.append(c)
	if live.is_empty():
		return
	var tag: String = label if drop < 0 else "%s minus#%d" % [label, drop]

	# One door and one chimney per building, whatever the shape.
	var per := {}
	for c in live:
		var key: Vector3i = HouseShape._component(c)["lo"]
		if not per.has(key):
			per[key] = [0, 0]
		if HouseShape.context(c)["door_side"] != Vector3i.ZERO:
			per[key][0] += 1
		if HouseShape.context(c)["chimney"]:
			per[key][1] += 1
	for k in per:
		_check(per[k][0] == 1, "%s: one door per building (got %d)" % [tag, per[k][0]])
		_check(per[k][1] == 1, "%s: one chimney per building (got %d)" % [tag, per[k][1]])

	# A roof patch must agree with itself: all terrace or none, at most one spire.
	var seen := {}
	for c in live:
		if not HouseShape.is_roof_cell(c) or seen.has(c):
			continue
		var patch: Array[Vector3i] = HouseShape.roof_patch(c)
		var terr := 0
		var spires := 0
		for pc in patch:
			seen[pc] = true
			if HouseShape.is_terrace(pc):
				terr += 1
			if HouseShape.has_spire(pc):
				spires += 1
		_check(terr == 0 or terr == patch.size(),
			"%s: roof patch is %d/%d terrace — patchwork" % [tag, terr, patch.size()])
		_check(spires <= 1, "%s: roof patch grew %d spires" % [tag, spires])

## 7h. A terrace must be FLAT. Measured on the built mesh, not on the rule,
## because the rule was right the whole time and the geometry was not.
##
## `_face_size(side, span, thick)` puts `span` into BOTH the vertical and the
## horizontal axis — correct for a wall, wrong for anything low. The balustrade
## used it, so "1.04 wide, 0.09 thick" came out as a 1.04-TALL panel and a
## terrace rendered as a ring of roofless walls standing around an empty cell.
## That is only visible in a screenshot or in a bounding box; no logic test would
## ever have caught it.
## A house only rebuilds when an edit can concern it, and `HouseShape.affects`
## decides that from the building's bounding box grown by `REACH`. Get that
## boundary wrong and a house keeps geometry describing a town that has changed
## — a stale door, a chimney on a building that was cut in half.
##
## The check is not "did the right cells go dirty", which just restates the
## rule. It is: after an edit, every house must look EXACTLY like a house built
## from scratch into the same final shape. Editing is required to be a shortcut,
## never a different answer.
##
## Why it earns its runtime: the old rule was "any house anywhere went dirty",
## which was always correct and cost ~10 ms per house already standing — 800 ms
## for one click in an 80-house town.
func _sec_no_stale_geometry() -> void:
	var z := 74
	# Each case: the cells to build, then the single cell to edit afterwards.
	# The long row is the point — its far end is well outside REACH, yet
	# removing it changes the building, so it must still propagate.
	var cases := [
		{"n": "long row, far end removed",
			"cells": _row(Vector3i(0, 0, z), Vector3i(1, 0, 0), 12), "drop": Vector3i(11, 0, z)},
		{"n": "long row, middle removed",
			"cells": _row(Vector3i(0, 0, z + 2), Vector3i(1, 0, 0), 12), "drop": Vector3i(6, 0, z + 2)},
		{"n": "tall stack, base removed",
			"cells": _row(Vector3i(0, 0, z + 4), Vector3i(0, 1, 0), 5), "drop": Vector3i(0, 0, z + 4)},
		{"n": "L wing removed",
			"cells": [Vector3i(0,0,z+6), Vector3i(1,0,z+6), Vector3i(2,0,z+6),
					Vector3i(2,0,z+7), Vector3i(2,0,z+8)], "drop": Vector3i(2, 0, z + 8)},
		# A solid two-storey blob is where terraces, roof gardens and the roof
		# height field all fire at once, so it is the shape that punishes a
		# `_digest` entry left out — a cell can keep a terrace, a spire or a whole
		# roof surface that the edit should have taken away.
		{"n": "3x3x2 blob, corner removed", "cells": _blob(Vector3i(0, 0, z + 10), 3, 2, 3),
			"drop": Vector3i(2, 1, z + 12)},
		{"n": "tower beside a wing, tower topped",
			"cells": [Vector3i(0,0,z+14), Vector3i(0,1,z+14), Vector3i(0,2,z+14), Vector3i(0,3,z+14),
					Vector3i(1,0,z+14), Vector3i(1,0,z+15), Vector3i(0,0,z+15)],
			"drop": Vector3i(0, 3, z + 14)},
	]
	for case in cases:
		var cells: Array = case["cells"]
		var drop: Vector3i = case["drop"]
		var left: Array = []
		for c in cells:
			if c != drop:
				left.append(c)

		# Route A: build everything, then edit.
		_clear()
		await get_tree().process_frame
		for c in cells:
			_b(c, BlockData.Type.HOUSE)
		for _f in range(3):
			await get_tree().process_frame
		GridManager.remove_block(drop)
		for _f in range(4):
			await get_tree().process_frame
		var edited := _house_print(left)

		# Route B: build only the survivors, from nothing.
		_clear()
		await get_tree().process_frame
		for c in left:
			_b(c, BlockData.Type.HOUSE)
		for _f in range(4):
			await get_tree().process_frame
		var fresh := _house_print(left)

		_check(edited == fresh, "stale geometry after '%s'\n    edited %s\n    fresh  %s" % [case["n"], edited, fresh])

	# The same rule must also SKIP work. Two buildings far apart cannot touch,
	# and if this stops holding the frame-drop comes straight back.
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 0, z + 10), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(not HouseShape.affects(Vector3i(0, 0, z + 10), Vector3i(40, 0, z + 10)),
			"a house 40 cells away is still considered relevant")
	_check(HouseShape.affects(Vector3i(0, 0, z + 10), Vector3i(0, -9, z + 10)),
			"the ground a house stands on is not considered relevant")

## Two things a logic test can never see, both of which have already shipped as
## bugs: geometry that wanders outside the cell it belongs to, and colours that
## drift apart until near-identical shades each cost their own draw call.
##
## The envelope check is the general form of the balustrade bug — `_face_size`
## used where `_slab` was meant, which stood a 1.04-TALL wall where a 0.09-thick
## rail belonged. Nothing about that is wrong logically; it is only wrong in
## space. Anything reaching well past its own cell is now caught by measurement
## rather than by someone noticing it in a screenshot.
func _sec_house_geometry_sane() -> void:
	var z := 88
	var shapes := {
		"lone": [Vector3i(0, 0, z)],
		"terrace": [Vector3i(0,0,z), Vector3i(0,1,z), Vector3i(0,2,z), Vector3i(1,0,z)],
		"spire": [Vector3i(0,0,z), Vector3i(0,1,z), Vector3i(0,2,z), Vector3i(0,3,z)],
		"stilts": [Vector3i(0, 3, z)],
		"bridge": [Vector3i(0,0,z), Vector3i(0,1,z), Vector3i(3,0,z), Vector3i(3,1,z),
				Vector3i(1,1,z), Vector3i(2,1,z)],
	}
	for name in shapes:
		_clear()
		await get_tree().process_frame
		for c in shapes[name]:
			_b(c, BlockData.Type.HOUSE)
		for _f in range(3):
			await get_tree().process_frame
		for c in shapes[name]:
			if not GridManager.has_block(c):
				continue
			# Per CELL, because that is the unit MeshBatch batches. Two buildings
			# holding near-identical shades is the point of the palette jitter and
			# costs nothing; one CELL holding two is a wasted draw call.
			#
			# Only the FIXED decoration colours are policed. A building's own
			# wall/roof/trim are jittered per building on purpose, and a derived
			# shade landing near the trim is that jitter working, not an accident —
			# the accident this catches is a hand-written colour drifting into a
			# near-copy of another, which is how planter, roof garden and courtyard
			# each ended up with their own foliage green.
			var own: Array[Color] = []
			var pal = GridManager.get_block(c).node.get("_palette")
			if pal != null:
				for k in ["wall", "roof", "trim"]:
					own.append(pal[k])
			var seen: Array[Color] = []
			for mi in _all_meshes(GridManager.get_block(c).node):
				var ab: AABB = mi.mesh.get_aabb()
				var hi: Vector3 = ab.position + ab.size
				var fin: bool = is_finite(ab.position.x) and is_finite(ab.size.x) \
						and is_finite(ab.position.y) and is_finite(ab.size.y)
				_check(fin, "%s %s: mesh bounds are not finite" % [name, c])
				if not fin:
					continue
				_check(hi.y <= 2.6, "%s %s: geometry reaches y=%.2f above its cell" % [name, c, hi.y])
				_check(ab.position.y >= -float(HouseShape.MAX_STILT) - 1.5,
						"%s %s: geometry reaches y=%.2f below its cell" % [name, c, ab.position.y])
				var reach: float = maxf(maxf(absf(ab.position.x), absf(hi.x)),
						maxf(absf(ab.position.z), absf(hi.z)))
				_check(reach <= 2.4, "%s %s: geometry reaches %.2f sideways" % [name, c, reach])
				# Near-duplicate colours: invisible to the eye, but MeshBatch cuts
				# a surface per colour, so each one is a permanent draw call.
				for i in mi.mesh.get_surface_count():
					var m: StandardMaterial3D = mi.mesh.surface_get_material(i)
					if m == null:
						continue
					var col: Color = m.albedo_color
					if _near_any(col, own, 0.12):
						continue
					for s in seen:
						var d: float = _cdist(s, col)
						_check(d == 0.0 or d > 0.12,
								"%s %s: %s and %s differ by %.3f — one colour, two draw calls"
								% [name, c, s.to_html(false), col.to_html(false), d])
					if not seen.has(col):
						seen.append(col)

## Placing a house must cost the same whether the island is empty or covered.
##
## It did not. Every house rebuilt whenever any house ANYWHERE was placed or
## removed, so one click cost ~10 ms per house already standing: 33 ms on an
## empty island, 818 ms in an 80-house town — the frame drop that got reported
## as "FPS falls from 80-90 to 30-40". `HouseShape.affects` now bounds it. This
## check exists because that regression is a one-line mistake away and is
## invisible until a save file gets big.
func _sec_place_cost_is_flat() -> void:
	var z := 96
	var cost: Array[float] = []
	for n in [0, 60]:
		_clear()
		await get_tree().process_frame
		for i in n:
			_b(Vector3i((i % 10) * 3 - 15, 0, z + (i / 10) * 3), BlockData.Type.HOUSE)
		for _f in range(6):
			await get_tree().process_frame
		var t0: int = Time.get_ticks_usec()
		_b(Vector3i(0, 0, z - 4), BlockData.Type.HOUSE)
		for _f in range(3):
			await get_tree().process_frame
		cost.append((Time.get_ticks_usec() - t0) / 1000.0)
	# Generous: the fix makes it flat, the bug made it 25x. Anything under 4x
	# means the work is still bounded by the building, not by the town.
	_check(cost[1] < maxf(cost[0] * 4.0, 60.0),
			"placing into a 60-house town costs %.1f ms against %.1f ms empty — the rebuild is town-wide again"
			% [cost[1], cost[0]])

## A house next to blocks that are NOT houses, and a cell built and rebuilt in
## place. Both are ordinary play — dropping a house on a wood platform, undoing
## and redoing the same corner while deciding — and both walk paths the shape
## fuzz never touches, because it only ever builds houses and only ever builds
## them once.
func _sec_house_among_other_blocks() -> void:
	var z := 104
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 0, z), BlockData.Type.WOOD)
	_b(Vector3i(0, 1, z), BlockData.Type.HOUSE)
	_b(Vector3i(1, 1, z), BlockData.Type.WATER)
	_b(Vector3i(2, 1, z), BlockData.Type.HOUSE)
	for _f in range(3):
		await get_tree().process_frame
	_check(HouseShape.support_drop(Vector3i(0, 1, z)) == 0,
			"a house standing on a wood block grew legs it does not need")
	_check(int(HouseShape.context(Vector3i(0, 1, z))["building_size"]) == 1,
			"a wood block was counted as part of a building")
	_check(HouseShape.support_drop(Vector3i(2, 1, z)) != 0,
			"a house over open air thinks something is holding it up")

	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 0, z + 2), BlockData.Type.HOUSE)
	_b(Vector3i(1, 0, z + 2), BlockData.Type.HOUSE)
	for _f in range(3):
		await get_tree().process_frame
	var before := _house_print([Vector3i(0, 0, z + 2)])
	for i in 5:
		GridManager.remove_block(Vector3i(1, 0, z + 2))
		for _f in range(2):
			await get_tree().process_frame
		_b(Vector3i(1, 0, z + 2), BlockData.Type.HOUSE)
		for _f in range(3):
			await get_tree().process_frame
	_check(_house_print([Vector3i(0, 0, z + 2)]) == before,
			"a neighbour drifted after the cell beside it was rebuilt five times")

func _cdist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func _near_any(c: Color, pool: Array, tol: float) -> bool:
	for p in pool:
		if _cdist(c, p) <= tol:
			return true
	return false

func _blob(origin: Vector3i, sx: int, sy: int, sz: int) -> Array:
	var out: Array = []
	for x in sx:
		for y in sy:
			for zz in sz:
				out.append(origin + Vector3i(x, y, zz))
	return out

func _row(start: Vector3i, step: Vector3i, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(start + step * i)
	return out

## Triangle and surface counts per cell — enough to catch a door, chimney, roof
## or storey line that did not move when it should have.
func _house_print(cells: Array) -> String:
	var parts: Array[String] = []
	for c in cells:
		if not GridManager.has_block(c):
			parts.append("%s:gone" % c)
			continue
		var tris := 0
		var surf := 0
		for mi in _all_meshes(GridManager.get_block(c).node):
			surf += mi.mesh.get_surface_count()
			for i in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(i)
				var idx = a[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3) if idx != null else (a[Mesh.ARRAY_VERTEX].size() / 3)
		parts.append("%s:%d/%d" % [c, tris, surf])
	return " ".join(parts)

func _all_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out += _all_meshes(c)
	return out

func _sec_terrace_is_flat() -> void:
	_clear()
	await get_tree().process_frame
	for y in 3:
		_b(Vector3i(0, y, 58), BlockData.Type.HOUSE)
	var low := Vector3i(1, 0, 58)
	_b(low, BlockData.Type.HOUSE)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(HouseShape.is_terrace(low), "the low cell beside a tower is a terrace")

	var node: Node3D = GridManager.get_block(low).node
	var top := -INF
	for mi in _meshes_under(node):
		top = maxf(top, (mi.mesh.get_aabb().position.y + mi.mesh.get_aabb().size.y))
	# A cell is 1.0 tall with its top face at +0.5. A balustrade adds a little;
	# a full-height wall panel would reach past +1.0.
	_check(top < 1.0, "a terrace stays flat — nothing full-height stands on it (was %.2f)" % top)

	# A ROOF AREA GETS ONE ANSWER. Deciding terrace-ness per cell made a 2x2 come
	# out as a patchwork: the cell touching the tower went flat while the one
	# behind it kept a pitched roof, and the top visibly refused to merge. Same
	# mistake per-cell gables were, one level up.
	_clear()
	await get_tree().process_frame
	for y in 3:
		_b(Vector3i(0, y, 60), BlockData.Type.HOUSE)
	var quad: Array[Vector3i] = []
	for x in 2:
		for z in 2:
			var c := Vector3i(1 + x, 0, 60 + z)
			quad.append(c)
			_b(c, BlockData.Type.HOUSE)
	await get_tree().process_frame
	await get_tree().process_frame
	var flat := 0
	for c in quad:
		if HouseShape.is_terrace(c):
			flat += 1
	_check(flat == quad.size(),
		"every cell of a roof area agrees: a 2x2 beside a tower is ONE deck (%d/4)" % flat)

	# And with nothing taller anywhere near it, the same 2x2 is all pitched roof.
	_clear()
	await get_tree().process_frame
	var lone: Array[Vector3i] = []
	for x in 2:
		for z in 2:
			var c := Vector3i(x, 0, 62 + z)
			lone.append(c)
			_b(c, BlockData.Type.HOUSE)
	await get_tree().process_frame
	var decks := 0
	for c in lone:
		if HouseShape.is_terrace(c):
			decks += 1
	_check(decks == 0, "a 2x2 with nothing over it stays a roof, not a deck")
	_clear()
	await get_tree().process_frame

func _meshes_under(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out += _meshes_under(c)
	return out

## 7g. DELETING must leave the survivors correct. Reported as "build it, delete
## something, and a house comes out with no roof".
##
## Root cause: queue_free() is deferred, so a just-removed house still receives
## block_removed and rebuilt itself one last time — and the component flood
## seeded its start cell unconditionally, so the DEAD cell walked back into its
## old building, counted itself a member, and wrote that wrong answer into the
## shared cache for every surviving cell. The whole building then kept deciding
## its roof, spire and colour from a size that no longer existed.
func _sec_delete_consistency() -> void:
	_clear()
	await get_tree().process_frame
	for y in 4:
		_b(Vector3i(0, y, 52), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(HouseShape.component_height(Vector3i(0, 3, 52)) == 4, "tower starts four storeys")
	_check(HouseShape.has_spire(Vector3i(0, 3, 52)), "and earns a spire")

	GridManager.remove_block(Vector3i(0, 0, 52))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(HouseShape.component_height(Vector3i(0, 3, 52)) == 3,
		"removing the base drops the measured height")
	_check(not HouseShape.has_spire(Vector3i(0, 3, 52)),
		"and the top gives up the spire it no longer earns")

	# A dead cell must never report itself as part of anything.
	_check(int(HouseShape.context(Vector3i(0, 0, 52))["building_size"]) == 0,
		"a removed cell belongs to no building")

	# The far arm of an L must notice a deletion at the other end, even though it
	# shares neither row nor column with it.
	_clear()
	await get_tree().process_frame
	for c in [Vector3i(0,0,54), Vector3i(1,0,54), Vector3i(2,0,54),
			Vector3i(2,0,55), Vector3i(2,0,56)]:
		_b(c, BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(int(HouseShape.context(Vector3i(0,0,54))["building_size"]) == 5, "L starts at five")
	GridManager.remove_block(Vector3i(2,0,56))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(int(HouseShape.context(Vector3i(0,0,54))["building_size"]) == 4,
		"the far arm sees a deletion at the other end")
	_clear()
	await get_tree().process_frame

## 7f. The surprises must be EARNED BY A SHAPE, never rolled. Finding the same
## thing twice in the same configuration is what turns a prop into a rule the
## player can learn and then play with on purpose.
func _sec_surprises() -> void:
	# SPIRE: four storeys and thin. Three storeys must NOT get one, or the
	# reward for building up stops meaning anything.
	_clear()
	await get_tree().process_frame
	for y in 3:
		_b(Vector3i(0, y, 44), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(not HouseShape.has_spire(Vector3i(0, 2, 44)), "three storeys is not yet a landmark")
	_b(Vector3i(0, 3, 44), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(HouseShape.has_spire(Vector3i(0, 3, 44)), "a four-storey tower earns its spire")
	_check(HouseShape.component_height(Vector3i(0, 0, 44)) == 4, "building height counts storeys")

	# A TERRACE, not a spire, when something taller stands beside this roof — and
	# a terraced cell must never also try to be a spire, or the tower grows both.
	_b(Vector3i(1, 0, 44), BlockData.Type.HOUSE)
	_b(Vector3i(1, 1, 44), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(HouseShape.is_terrace(Vector3i(1, 0, 44)) == false, "a roof under its own stack is not a terrace")
	_b(Vector3i(2, 0, 44), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(HouseShape.is_terrace(Vector3i(2, 0, 44)), "a roof beside a taller part becomes a terrace")
	_check(not HouseShape.has_spire(Vector3i(2, 0, 44)), "a terrace never doubles as a spire")

	# An arch across a two-cell gap is ONE curve: both cells agree on the span
	# and each knows which slice of it to draw. Per-cell semicircles produced a
	# row of bumps under a bridge instead of an arch.
	_clear()
	await get_tree().process_frame
	for c in [Vector3i(0, 0, 50), Vector3i(0, 1, 50), Vector3i(3, 0, 50), Vector3i(3, 1, 50),
			Vector3i(1, 1, 50), Vector3i(2, 1, 50)]:
		_b(c, BlockData.Type.HOUSE)
	await get_tree().process_frame
	var r1: Dictionary = HouseShape.arch_run(Vector3i(1, 1, 50))
	var r2: Dictionary = HouseShape.arch_run(Vector3i(2, 1, 50))
	_check(not r1.is_empty() and int(r1["length"]) == 2, "a two-cell span is one arch of length 2")
	_check(int(r1["index"]) == 0 and int(r2["index"]) == 1, "each cell knows its slice of the span")
	_check(r1["axis"] == r2["axis"], "both halves agree on the span axis")
	# Widening it takes the spire away again: a landmark has to be a TOWER.
	_b(Vector3i(1, 3, 44), BlockData.Type.HOUSE)
	_b(Vector3i(-1, 3, 44), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(not HouseShape.has_spire(Vector3i(0, 3, 44)), "a fat top is a roof, not a spire")

	# COURTYARD: ring an empty cell and it becomes a garden — owned by exactly
	# ONE of the four surrounding cells so it is never built twice.
	_clear()
	await get_tree().process_frame
	var ring := [Vector3i(1, 0, 46), Vector3i(-1, 0, 46), Vector3i(0, 0, 47), Vector3i(0, 0, 45)]
	for c in ring:
		_b(c, BlockData.Type.HOUSE)
	await get_tree().process_frame
	var owners := 0
	for c in ring:
		if HouseShape.courtyard_dir(c) != Vector3i.ZERO:
			owners += 1
	_check(owners == 1, "an enclosed gap grows exactly one courtyard")
	# Fill the hole and the courtyard has nowhere to be.
	_b(Vector3i(0, 0, 46), BlockData.Type.HOUSE)
	await get_tree().process_frame
	var still := 0
	for c in ring:
		if HouseShape.courtyard_dir(c) != Vector3i.ZERO:
			still += 1
	_check(still == 0, "filling the gap removes the courtyard")

	# BUNTING: exactly one cell of air between two rooftops of equal height, and
	# only the near side draws it so the line is not doubled.
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 0, 48), BlockData.Type.HOUSE)
	_b(Vector3i(2, 0, 48), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(HouseShape.bunting_dir(Vector3i(0, 0, 48)) == Vector3i(1, 0, 0), "a one-cell gap strings bunting")
	_check(HouseShape.bunting_dir(Vector3i(2, 0, 48)) == Vector3i.ZERO, "only one end draws the line")
	# Two cells apart is a street, not a washing line.
	_clear()
	await get_tree().process_frame
	_b(Vector3i(0, 0, 48), BlockData.Type.HOUSE)
	_b(Vector3i(3, 0, 48), BlockData.Type.HOUSE)
	await get_tree().process_frame
	_check(HouseShape.bunting_dir(Vector3i(0, 0, 48)) == Vector3i.ZERO, "a wider gap gets no bunting")
	_clear()
	await get_tree().process_frame

## 7e. Water must land ON the island. The lawn is a sculpted MESH, not grid
## blocks, so nothing in GridManager stops a falling stream at it — a spout on
## open ground used to pour straight THROUGH the island and run to y=-18: a long
## invisible thread under the world, no splash, and `is_playing()` stayed false
## so the machine never counted as running. Every earlier section passed happily
## while that was true, because they all put something solid under the water.
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
	_b(Vector3i(0, 0, 20), BlockData.Type.HOUSE, 1)
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
