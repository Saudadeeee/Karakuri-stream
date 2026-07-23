extends Node

## The whole build, not just a setting like volume (see pause_menu.gd's
## ConfigFile use) — a separate file and format on purpose: this is gameplay
## data (JSON array of blocks), not engine/user preferences.
const SAVE_PATH: String = "user://save_data.json"

signal saved
signal loaded

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data: Array = []
	for cell in GridManager.get_all_cells():
		var block: BlockData = GridManager.get_block(cell)
		data.append({"x": cell.x, "y": cell.y, "z": cell.z, "type": int(block.type)})

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	saved.emit()

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
		GridManager.set_block(cell, BlockData.new(type, instance))

	loaded.emit()
	return true
