extends Node

## The whole build, not just a setting like volume (see pause_menu.gd's
## ConfigFile use) — a separate file and format on purpose: this is gameplay
## data (JSON array of blocks), not engine/user preferences.
##
## Also owns AUTOSAVE. A player's garden is an hour of work that exists nowhere
## else, and the only save used to be a button in the pause menu — closing the
## window threw the session away. Now the grid is watched, and the build is
## written on a timer, on focus loss, and on the close request itself.
const SAVE_PATH: String = "user://save_data.json"
## Written first, renamed over SAVE_PATH once the bytes are down. Writing
## straight onto the real file means a crash mid-write leaves a truncated JSON,
## and load() (correctly) refuses to load it — so the crash costs the garden.
const TMP_PATH: String = "user://save_data.json.tmp"
## The previous good save, kept for exactly one generation. If the newest file
## turns out to be unreadable this is what the player gets back.
const BACKUP_PATH: String = "user://save_data.bak.json"

const AUTOSAVE_INTERVAL: float = 45.0

## Only true while a game scene is on screen. The menu clears the grid, and an
## autosave firing there would write an empty build over a real one.
var autosave_armed: bool = false
var _dirty: bool = false
var _timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

## Silent, best-effort save of the current build. Refuses to write an empty grid
## because every way of ending up with one (menu transition, clear) would
## otherwise erase a real save behind the player's back.
func autosave() -> void:
	if not autosave_armed or not _dirty:
		return
	if GridManager.get_all_cells().is_empty():
		return
	if save_game():
		_dirty = false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)

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
	var file: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open %s for writing (%d)" % [TMP_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data))
	file.close()   # flushes — nothing below may run until the bytes are on disk

	# Demote the current save to the backup before the new one takes its place,
	# so there is always one known-good generation behind the newest write.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)

	var err: Error = DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if err != OK:
		push_warning("Could not replace %s (%d) — the previous save is intact" % [SAVE_PATH, err])
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
func load_game() -> bool:
	# Newest first, then the one generation behind it. A save that survives a
	# crash mid-write is still a save; without this the player would be told
	# their build is unreadable while a perfectly good copy sits next to it.
	var entries: Array = _read_entries(SAVE_PATH)
	if entries.is_empty():
		entries = _read_entries(BACKUP_PATH)
		if not entries.is_empty():
			push_warning("Loaded the backup save — %s was unreadable" % SAVE_PATH)
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
