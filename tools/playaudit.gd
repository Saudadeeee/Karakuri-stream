extends Node

## Does the machine actually work, block by block?
##
## The regression suite runs ONE karakuri chain end to end. This drops a spout
## over every block type in turn and asks whether that block noticed — which is
## the whole game, and the thing a player would report as "this one does
## nothing".
var bad: Array[String] = []
var game: Node

func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	for _f in range(15):
		await get_tree().process_frame

	await _water_hits_everything()
	await _gear_power_chain()
	await _gate_stops_flow()
	await _variants_cycle()

	if bad.is_empty():
		print("PLAY CLEAN")
	else:
		for b in bad:
			print("PLAY ISSUE: ", b)
	print("PLAY DONE")
	get_tree().quit()

## A spout directly above each block: does the stream reach it, and does the
## block register an impact?
func _water_hits_everything() -> void:
	var targets := [BlockData.Type.BELL, BlockData.Type.DRUM, BlockData.Type.CHIME,
			BlockData.Type.JELLY, BlockData.Type.SHISHI, BlockData.Type.PINWHEEL,
			BlockData.Type.WOOD, BlockData.Type.GEAR, BlockData.Type.MUSIC_BOX,
			BlockData.Type.STONE_LANTERN, BlockData.Type.SCOOP, BlockData.Type.GATE]
	for t in targets:
		_clear()
		await get_tree().process_frame
		var cell := Vector3i(0, 0, 0)
		_place(cell, t)
		_place(Vector3i(0, 3, 0), BlockData.Type.SOURCE)
		for _f in range(30):
			await get_tree().process_frame
		var name: String = BlockData.Type.keys()[t]
		var reached := false
		for seg in StreamManager._segments:
			reached = true
			break
		if not reached:
			bad.append("%s: the spout above it produced no stream at all" % name)
			continue
		# Did the stream stop AT the block rather than pouring through it?
		var landed := false
		for imp in StreamManager._impacts:
			if imp is Dictionary and imp.get("cell") == cell:
				landed = true
		if not landed and StreamManager._impacts.size() == 0:
			bad.append("%s: water fell past it without registering an impact" % name)

## Gears spin from water and pass power along; a music box beside a driven gear
## must count as powered.
func _gear_power_chain() -> void:
	_clear()
	await get_tree().process_frame
	_place(Vector3i(0, 0, 0), BlockData.Type.WATER)
	_place(Vector3i(1, 0, 0), BlockData.Type.GEAR)
	_place(Vector3i(2, 0, 0), BlockData.Type.GEAR)
	_place(Vector3i(3, 0, 0), BlockData.Type.MUSIC_BOX)
	for _f in range(30):
		await get_tree().process_frame
	if not GearManager.is_powered_neighbor(Vector3i(3, 0, 0)):
		bad.append("gears: a music box two gears from the water is not powered")
	_clear()
	await get_tree().process_frame
	_place(Vector3i(1, 0, 0), BlockData.Type.GEAR)
	_place(Vector3i(2, 0, 0), BlockData.Type.MUSIC_BOX)
	for _f in range(20):
		await get_tree().process_frame
	if GearManager.is_powered_neighbor(Vector3i(2, 0, 0)):
		bad.append("gears: a music box is powered by a gear touching NO water")

## A closed sluice gate must stop the stream; opening it must let it through.
func _gate_stops_flow() -> void:
	_clear()
	await get_tree().process_frame
	_place(Vector3i(0, 3, 0), BlockData.Type.SOURCE)
	var gate: Node3D = _place(Vector3i(0, 1, 0), BlockData.Type.GATE)
	_place(Vector3i(0, 0, 0), BlockData.Type.DRUM)
	for _f in range(30):
		await get_tree().process_frame
	var closed_segs: int = StreamManager._segments.size()
	if gate.has_method("toggle"):
		gate.toggle()
	for _f in range(30):
		await get_tree().process_frame
	var open_segs: int = StreamManager._segments.size()
	if closed_segs == open_segs:
		bad.append("gate: toggling it changed nothing (%d segments either way)" % closed_segs)

## Cycling a material's variant must wrap round to the first one, for every type.
func _variants_cycle() -> void:
	var pc: Node = game.get_node("PlacementController")
	for t in BlockData.Type.values():
		var n: int = BlockVariants.count(t)
		if n <= 0:
			bad.append("%s: reports %d variants" % [BlockData.Type.keys()[t], n])
			continue
		pc.select_material(t)                     # switches to it, variant 0
		var first: int = pc._current_variant
		for i in n:
			pc.select_material(t)                 # same type again = cycle
		if pc._current_variant != first:
			bad.append("%s: %d presses did not return to variant %d (got %d)"
					% [BlockData.Type.keys()[t], n, first, pc._current_variant])

# ---------------------------------------------------------------- helpers
func _clear() -> void:
	GridManager.clear_all()

func _place(c: Vector3i, t: int) -> Node3D:
	var n: Node3D = BlockFactory.instantiate(t)
	game.add_child(n)
	n.position = GridManager.cell_to_world(c)
	if "grid_cell" in n:
		n.grid_cell = c
	GridManager.set_block(c, BlockData.new(t, n))
	if n.has_method("refresh_shape"):
		n.refresh_shape()
	elif n.has_method("face_adjacent_water"):
		n.face_adjacent_water()
	return n
