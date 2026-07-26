extends Node

## The whole build, not just a setting like volume (see pause_menu.gd's
## ConfigFile use) — a separate file and format on purpose: this is gameplay
## data (JSON array of blocks), not engine/user preferences.
const SAVE_PATH: String = "user://save_data.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
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

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

## Returns false if there's nothing to load or the save file is corrupt —
## caller decides what to tell the player.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(text)
	if data == null or not data is Array:
		return false

	GridManager.clear_all()
	var scene_root: Node = get_tree().current_scene
	for entry in data:
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
		elif type == BlockData.Type.PIPE or type == BlockData.Type.SOURCE:
			# Auto-shaping blocks re-derive orientation from neighbours.
			instance.grid_cell = cell
		GridManager.set_block(cell, block)
		if type == BlockData.Type.PIPE:
			instance.refresh_shape()
		elif type == BlockData.Type.SOURCE:
			instance.face_adjacent_water()

	return true
