extends Node

## The whole build, not just a setting like volume (see pause_menu.gd's
## ConfigFile use) — a separate file and format on purpose: this is gameplay
## data (JSON array of blocks), not engine/user preferences.
const SAVE_PATH: String = "user://save_data.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## False when the file could not be written — the caller must not tell the
## player their build is safe when it isn't.
func save_game() -> bool:
	var data: Array = []
	for cell in GridManager.get_all_cells():
		var block: BlockData = GridManager.get_block(cell)
		var entry: Dictionary = {"x": cell.x, "y": cell.y, "z": cell.z, "type": int(block.type)}
		if block.state.has("variant"):
			entry["variant"] = int(block.state["variant"])
		# Gears remember which face they were placed on so orientation survives
		# a save/load round-trip. Old saves without "axis" default to +Y (flat).
		if block.state.has("open"):
			entry["open"] = bool(block.state["open"])
		if block.state.has("axis"):
			var axis: Vector3i = block.state["axis"]
			entry["axis"] = [axis.x, axis.y, axis.z]
		# Bamboo pipes remember their two open ports so routing survives reload.
		if block.state.has("ports"):
			var ports: Array = block.state["ports"]
			entry["ports"] = [[ports[0].x, ports[0].y, ports[0].z],
				[ports[1].x, ports[1].y, ports[1].z]]
		data.append(entry)

	# Opening can fail for real: a full disk, a read-only profile, or a browser
	# that has blocked storage for the tab. Unchecked, the next line calls a
	# method on null and takes the game down at the exact moment the player
	# asked to protect their work.
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open %s for writing (%d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

## Returns false if there's nothing to load or the save file is unusable —
## caller decides what to tell the player.
##
## The whole payload is VALIDATED BEFORE the grid is touched. That ordering is
## the point: clearing first and discovering the file was truncated halfway
## through means the player loses the build they had in front of them AND does
## not get the saved one back. A save file can genuinely be half-written — a
## browser tab closed mid-flush is enough — so a corrupt file has to be a
## no-op, not a wipe.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open %s for reading (%d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	var text: String = file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(text)
	if data == null or not data is Array:
		return false

	var entries: Array = _valid_entries(data)
	if entries.is_empty():
		# Either genuinely empty or entirely unreadable. Either way, refuse to
		# throw away what the player currently has for it.
		return false

	GridManager.clear_all()
	var scene_root: Node = get_tree().current_scene
	for entry in entries:
		var cell := Vector3i(int(entry["x"]), int(entry["y"]), int(entry["z"]))
		var type: BlockData.Type = int(entry["type"]) as BlockData.Type
		var instance: Node3D = BlockFactory.instantiate(type)
		scene_root.add_child(instance)
		instance.position = GridManager.cell_to_world(cell)
		var block := BlockData.new(type, instance)
		var variant: int = int(entry.get("variant", 0))
		block.state["variant"] = variant
		if instance.has_method("apply_variant"):
			instance.apply_variant(BlockVariants.get_variant(type, variant))
		if entry.has("open"):
			block.state["open"] = bool(entry["open"])
			if instance.has_method("set_open"):
				instance.set_open(bool(entry["open"]), true)
		if type == BlockData.Type.GEAR and entry.has("axis"):
			var raw: Array = entry["axis"]
			var axis := Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
			block.state["axis"] = axis
			if instance.has_method("apply_axis"):
				instance.apply_axis(axis)
		elif type == BlockData.Type.PIPE or type == BlockData.Type.SOURCE \
				or type == BlockData.Type.HOUSE:
			# Auto-shaping blocks re-derive orientation from neighbours.
			instance.grid_cell = cell
		GridManager.set_block(cell, block)
		if type == BlockData.Type.PIPE or type == BlockData.Type.HOUSE:
			instance.refresh_shape()
		elif type == BlockData.Type.SOURCE:
			instance.face_adjacent_water()

	return true

## Keep only the entries we can actually rebuild, and say what was dropped
## instead of silently shrinking someone's build. Two things get rejected:
## entries missing a coordinate or type (a truncated write), and type ids this
## build has never heard of — a save written by a NEWER version, which is the
## realistic case once the game is public and someone downgrades or shares a
## file. Both used to be hard errors mid-rebuild, leaving a half-loaded grid.
func _valid_entries(data: Array) -> Array:
	var out: Array = []
	var dropped := 0
	for entry in data:
		if not (entry is Dictionary):
			dropped += 1
			continue
		if not (entry.has("x") and entry.has("y") and entry.has("z") and entry.has("type")):
			dropped += 1
			continue
		if not BlockFactory.SCENES_BY_TYPE.has(int(entry["type"])):
			dropped += 1
			continue
		out.append(entry)
	if dropped > 0:
		push_warning("Save file: skipped %d unreadable block entr%s" % [dropped, "y" if dropped == 1 else "ies"])
	return out
