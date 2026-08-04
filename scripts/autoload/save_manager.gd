extends Node

## The whole build, not just a setting like volume (see pause_menu.gd's
## ConfigFile use) — a separate file and format on purpose: this is gameplay
## data (JSON array of blocks), not engine/user preferences.
##
## Also owns AUTOSAVE. A player's garden is an hour of work that exists nowhere
## else, and the only save used to be a button in the pause menu — closing the
## window threw the session away. Now the grid is watched, and the build is
## written on a timer, on focus loss, and on the close request itself.
## THREE GARDENS, not one. A single slot meant every new idea cost the last one:
## the only way to try a different island was to clear the one you had. Slots are
## plain separate files — no shared index to get out of step with what is on disk.
const SLOT_COUNT: int = 3
const SETTINGS_PATH: String = "user://settings.cfg"
## The pre-slot save. Migrated into slot 1 the first time this build runs, so an
## existing player does not open the game to an empty island.
const LEGACY_PATH: String = "user://save_data.json"
const LEGACY_BACKUP: String = "user://save_data.bak.json"

## Format 2 wraps the block list in a header (when it was saved, which map) so a
## slot can describe itself in the menu without rebuilding the whole garden to
## find out. Format 1 was a bare array and still loads — see _read_entries.
const FORMAT_VERSION: int = 2

const AUTOSAVE_INTERVAL: float = 45.0

## Which garden is being played. Persisted, because "carry on where I left off"
## has to survive closing the game.
var current_slot: int = 0

## Only true while a game scene is on screen. The menu clears the grid, and an
## autosave firing there would write an empty build over a real one.
var autosave_armed: bool = false
var _dirty: bool = false
var _timer: Timer

## Slot files. One file per slot plus its one-generation backup, and a temp file
## the write lands in first — see save_game.
func slot_path(slot: int = -1) -> String:
	return "user://garden_%d.json" % _slot(slot)

func backup_path(slot: int = -1) -> String:
	return "user://garden_%d.bak.json" % _slot(slot)

func tmp_path(slot: int = -1) -> String:
	return "user://garden_%d.json.tmp" % _slot(slot)

func _slot(slot: int) -> int:
	return current_slot if slot < 0 else clampi(slot, 0, SLOT_COUNT - 1)

func set_current_slot(slot: int) -> void:
	current_slot = clampi(slot, 0, SLOT_COUNT - 1)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep audio/display/discovered
	cfg.set_value("save", "slot", current_slot)
	cfg.save(SETTINGS_PATH)

## What the menu needs to describe a slot without loading it: whether it exists,
## how big the garden is, when it was written and which map it was built on.
func slot_info(slot: int) -> Dictionary:
	var out := {"exists": false, "blocks": 0, "saved_at": 0, "theme": -1}
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		path = backup_path(slot)
		if not FileAccess.file_exists(path):
			return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Array:
		# Format 1: no header, so the file's own timestamp is the best answer.
		out["exists"] = true
		out["blocks"] = (data as Array).size()
		out["saved_at"] = FileAccess.get_modified_time(path)
	elif data is Dictionary and (data as Dictionary).has("blocks"):
		out["exists"] = true
		out["blocks"] = int((data as Dictionary).get("count", ((data as Dictionary)["blocks"] as Array).size()))
		out["saved_at"] = int((data as Dictionary).get("saved_at", FileAccess.get_modified_time(path)))
		out["theme"] = int((data as Dictionary).get("theme", -1))
	return out

## Delete a slot outright. Used by "Clear this garden" — the grid is a separate
## question, so the caller decides whether the screen is emptied too.
func clear_slot(slot: int) -> void:
	for p in [slot_path(slot), backup_path(slot), tmp_path(slot)]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		current_slot = clampi(int(cfg.get_value("save", "slot", 0)), 0, SLOT_COUNT - 1)
	_migrate_legacy()
	GridManager.block_placed.connect(func(_c: Vector3i) -> void: _dirty = true)
	GridManager.block_removed.connect(func(_c: Vector3i) -> void: _dirty = true)

	_timer = Timer.new()
	_timer.wait_time = AUTOSAVE_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(autosave)
	add_child(_timer)

	# Take over the close button so the build can be written before the window
	# goes away. Web has no quit request (a tab cannot be closed by the game),
	# so the browser path relies on the focus-out save below instead.
	if not OS.has_feature("web"):
		get_tree().set_auto_accept_quit(false)

## An existing player has one garden in the old single-slot file. Move it into
## slot 1 rather than leaving it stranded — renamed, not copied, so this can
## never run twice and resurrect a garden the player has since cleared.
func _migrate_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_PATH) or FileAccess.file_exists(slot_path(0)):
		return
	DirAccess.rename_absolute(LEGACY_PATH, slot_path(0))
	if FileAccess.file_exists(LEGACY_BACKUP):
		DirAccess.rename_absolute(LEGACY_BACKUP, backup_path(0))
	push_warning("Moved the old single save into garden 1")

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			autosave()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button out of the app.
			autosave()
			get_tree().quit()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Alt-tab away, or Android backgrounding the app — the moment before
			# a process is most likely to be killed without warning.
			autosave()

## Silent, best-effort save of the current build into the ACTIVE slot. Refuses to write an empty grid
## because every way of ending up with one (menu transition, clear) would
## otherwise erase a real save behind the player's back.
func autosave() -> void:
	if not autosave_armed or not _dirty:
		return
	if GridManager.get_all_cells().is_empty():
		return
	if save_game():
		_dirty = false

func has_save(slot: int = -1) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(backup_path(slot))

## False when the file could not be written — the caller must not tell the
## player their build is safe when it isn't.
func save_game(slot: int = -1) -> bool:
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
	var tmp: String = tmp_path(slot)
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open %s for writing (%d)" % [tmp, FileAccess.get_open_error()])
		return false
	# Header + blocks, so a slot can describe itself in the menu without being
	# rebuilt. Time.get_unix_time_from_system() and not the file timestamp: a file
	# copied between machines keeps the moment the garden was actually saved.
	file.store_string(JSON.stringify({
		"v": FORMAT_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"theme": MapThemes.current,
		"count": data.size(),
		"blocks": data,
	}))
	file.close()   # flushes — nothing below may run until the bytes are on disk

	# Demote the current save to the backup before the new one takes its place,
	# so there is always one known-good generation behind the newest write.
	var final_path: String = slot_path(slot)
	if FileAccess.file_exists(final_path):
		DirAccess.copy_absolute(final_path, backup_path(slot))

	var err: Error = DirAccess.rename_absolute(tmp, final_path)
	if err != OK:
		push_warning("Could not replace %s (%d) — the previous save is intact" % [final_path, err])
		return false
	_dirty = false
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
func load_game(slot: int = -1) -> bool:
	# Newest first, then the one generation behind it. A save that survives a
	# crash mid-write is still a save; without this the player would be told
	# their build is unreadable while a perfectly good copy sits next to it.
	var entries: Array = _read_entries(slot_path(slot))
	if entries.is_empty():
		entries = _read_entries(backup_path(slot))
		if not entries.is_empty():
			push_warning("Loaded the backup save — %s was unreadable" % slot_path(slot))
	if entries.is_empty():
		# Nothing to restore. Refuse to throw away what the player currently has.
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

	# Loading is not a change the player made — arming the dirty flag here would
	# make the next autosave rewrite a file identical to the one just read.
	_dirty = false
	return true

## Read one save file and return the entries worth rebuilding. Empty means
## "unusable" for every reason: missing, unopenable, not JSON, not an array, or
## nothing inside it this build understands.
func _read_entries(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open %s for reading (%d)" % [path, FileAccess.get_open_error()])
		return []
	var text: String = file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(text)
	# Format 2 is a header around the list; format 1 was the bare list, and saves
	# in that shape still exist on disk for anyone who played an earlier build.
	if data is Dictionary and (data as Dictionary).has("blocks"):
		data = (data as Dictionary)["blocks"]
	if data == null or not data is Array:
		return []
	return _valid_entries(data)

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
		if BlockCatalog.entry(int(entry["type"])).is_empty():
			dropped += 1
			continue
		out.append(entry)
	if dropped > 0:
		push_warning("Save file: skipped %d unreadable block entr%s" % [dropped, "y" if dropped == 1 else "ies"])
	return out
