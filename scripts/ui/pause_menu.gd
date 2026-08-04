extends Control

const SETTINGS_PATH: String = "user://settings.cfg"
const STATUS_FADE_TIME: float = 1.6

@onready var volume_slider: HSlider = $Panel/VBoxContainer/VolumeRow/VolumeSlider
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var load_button: Button = $Panel/VBoxContainer/LoadButton
@onready var clear_button: Button = $Panel/VBoxContainer/ClearButton
@onready var menu_button: Button = $Panel/VBoxContainer/MenuButton
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel

const MAIN_MENU := "res://scenes/main_menu.tscn"
@onready var confirm_clear_dialog: ConfirmationDialog = $ConfirmClearDialog

func _ready() -> void:
	# The UI font is a BITMAP face and the canvas is scaled to the window, so
	# linear sampling turns every label into mush. Children inherit this.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# Seamless continue: "Về menu chính" auto-saves, so entering the game
	# restores the last build automatically (first run has no save → skipped).
	if SaveManager.has_save():
		SaveManager.load_game.call_deferred()

	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	# "Load build" was one save and one button. It is now the way into the three
	# gardens, which is also where loading lives.
	load_button.text = "Gardens"
	load_button.pressed.connect(_toggle_gardens)
	clear_button.pressed.connect(confirm_clear_dialog.popup_centered)
	menu_button.pressed.connect(_on_menu_pressed)
	confirm_clear_dialog.confirmed.connect(_on_clear_confirmed)
	volume_slider.value_changed.connect(_on_volume_changed)

	_build_journal()
	_build_gardens()
	_load_settings()
	CuteButton.apply_all(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		_resume()
	else:
		_pause()

func _pause() -> void:
	visible = true
	get_tree().paused = true
	_set_music_muffle(true)

func _resume() -> void:
	for panel in [_journal_panel, _gardens_panel]:
		if panel != null and is_instance_valid(panel) and panel.visible:
			panel.visible = false
			$Panel.visible = true
	visible = false
	get_tree().paused = false
	_set_music_muffle(false)

## Classic pause muffle: a low-pass on the Music bus pulls the ambience
## underwater while the menu is up (SFX are paused with the tree anyway).
func _set_music_muffle(on: bool) -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx >= 0 and AudioServer.get_bus_effect_count(idx) > 0:
		AudioServer.set_bus_effect_enabled(idx, 0, on)

func _on_resume_pressed() -> void:
	_resume()

func _on_save_pressed() -> void:
	# Saving can fail (no space, storage blocked in the browser). Telling the
	# player "Build saved" when nothing was written is how people lose work.
	if SaveManager.save_game():
		_show_status("Build saved")
	else:
		_show_status("Could not save — storage unavailable")

func _on_clear_confirmed() -> void:
	GridManager.clear_all()

## Back to the start menu. Auto-save, then CLEAR THE GRID before leaving:
## the block nodes die with this scene, but GridManager and the visual
## managers (VoxelSurface/PondDecor/Stream) are autoloads that survive the
## scene change — without clear_all() their merged surfaces, koi ponds and
## streams keep rendering on top of the menu and pollute the next session.
## clear_all() emits grid_cleared, which every manager already listens to.
## Unpause first (the tree stays paused across a scene change otherwise).
func _on_menu_pressed() -> void:
	SaveManager.save_game()
	# Disarm BEFORE clearing: clear_all() is a grid change like any other, and an
	# autosave landing after it would write an empty build over the one just saved.
	SaveManager.autosave_armed = false
	GridManager.clear_all()
	get_tree().paused = false
	_set_music_muffle(false)   # the low-pass must not follow us to the menu
	get_tree().change_scene_to_file(MAIN_MENU)

# ------------------------------------------------------------------ journal
## The list of things the town can do, and which of them this player has seen.
## Undiscovered rows show the shape of the secret and nothing else — a name would
## be a recipe, and the point is that these are found by building, not by reading.
var _journal_panel: PanelContainer

func _build_journal() -> void:
	var button := Button.new()
	button.text = "Journal"
	button.custom_minimum_size = Vector2(0, 44)
	var box: VBoxContainer = $Panel/VBoxContainer
	box.add_child(button)
	box.move_child(button, resume_button.get_index() + 1)
	button.pressed.connect(_toggle_journal)

	_journal_panel = PanelContainer.new()
	_journal_panel.visible = false
	_journal_panel.set_anchors_preset(Control.PRESET_CENTER)
	_journal_panel.custom_minimum_size = Vector2(430, 0)
	_journal_panel.position = Vector2(-215, -250)
	add_child(_journal_panel)

func _toggle_journal() -> void:
	_journal_panel.visible = not _journal_panel.visible
	# One card at a time: the journal is taller than the pause menu and stacking
	# the two just buries the buttons behind it.
	$Panel.visible = not _journal_panel.visible
	if not _journal_panel.visible:
		return
	# Rebuilt on open: things get discovered while the panel is closed.
	for c in _journal_panel.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_journal_panel.add_child(box)

	var head := Label.new()
	head.text = tr("Journal  %d / %d") % [DiscoveryLog.count_found(), DiscoveryLog.ENTRIES.size()]
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 20)
	box.add_child(head)

	for e in DiscoveryLog.ENTRIES:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 13)
		if DiscoveryLog.has(String(e["id"])):
			row.text = "%s — %s" % [tr(str(e["title"])), tr(str(e["note"]))]
		else:
			row.text = "? ? ?"
			row.modulate.a = 0.35
		box.add_child(row)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 38)
	close.pressed.connect(_toggle_journal)
	box.add_child(close)
	CuteButton.apply_all(_journal_panel)

# ------------------------------------------------------------------ gardens
## Three separate gardens. One slot meant every new idea cost the last one: the
## only way to try a different island was to clear the one you had.
##
## Switching gardens SAVES the one on screen first. Autosave already keeps it
## current, but "already saved" is not something a player should have to trust —
## and the cost of being wrong is an hour of building.
var _gardens_panel: PanelContainer
var _confirm_clear_slot: ConfirmationDialog
var _slot_to_clear: int = -1

func _build_gardens() -> void:
	_gardens_panel = PanelContainer.new()
	_gardens_panel.visible = false
	_gardens_panel.custom_minimum_size = Vector2(520, 0)
	add_child(_gardens_panel)

	_confirm_clear_slot = ConfirmationDialog.new()
	_confirm_clear_slot.dialog_text = "Delete this garden? This cannot be undone."
	_confirm_clear_slot.ok_button_text = "Delete"
	_confirm_clear_slot.cancel_button_text = "Keep"
	_confirm_clear_slot.confirmed.connect(_on_clear_slot_confirmed)
	add_child(_confirm_clear_slot)

func _toggle_gardens() -> void:
	_gardens_panel.visible = not _gardens_panel.visible
	$Panel.visible = not _gardens_panel.visible
	if _gardens_panel.visible:
		_refresh_gardens()

func _refresh_gardens() -> void:
	for c in _gardens_panel.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_gardens_panel.add_child(box)

	var head := Label.new()
	head.text = "Gardens"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 20)
	box.add_child(head)

	for i in SaveManager.SLOT_COUNT:
		box.add_child(_garden_row(i))

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 38)
	close.pressed.connect(_toggle_gardens)
	box.add_child(close)
	CuteButton.apply_all(_gardens_panel)
	await get_tree().process_frame
	UiPlace.centre(_gardens_panel)

func _garden_row(slot: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var info: Dictionary = SaveManager.slot_info(slot)
	var active: bool = slot == SaveManager.current_slot

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.text = "%s %s  %s" % ["*" if active else " ", tr("Garden %d") % (slot + 1), _slot_summary(info)]
	if not active:
		label.modulate.a = 0.75
	row.add_child(label)

	var save_b := Button.new()
	save_b.text = "Save"
	save_b.custom_minimum_size = Vector2(66, 34)
	save_b.pressed.connect(_on_save_to_slot.bind(slot))
	row.add_child(save_b)

	if bool(info["exists"]):
		var open_b := Button.new()
		open_b.text = "Open"
		open_b.custom_minimum_size = Vector2(66, 34)
		open_b.disabled = active
		open_b.pressed.connect(_on_open_slot.bind(slot))
		row.add_child(open_b)

		var del_b := Button.new()
		del_b.text = "Delete"
		del_b.custom_minimum_size = Vector2(72, 34)
		del_b.pressed.connect(func() -> void:
			_slot_to_clear = slot
			_confirm_clear_slot.popup_centered())
		row.add_child(del_b)
	return row

func _slot_summary(info: Dictionary) -> String:
	if not bool(info["exists"]):
		return tr("- empty")
	var parts: PackedStringArray = [tr("%d blocks") % int(info["blocks"])]
	var theme: int = int(info["theme"])
	if theme >= 0:
		parts.append(tr(MapThemes.name_of(theme)))
	parts.append(_ago(int(info["saved_at"])))
	return "- " + " | ".join(parts)

## "just now" is more use than a timestamp when the question is which of three
## gardens you were last in.
func _ago(unix: int) -> String:
	if unix <= 0:
		return tr("saved")
	var secs: int = int(Time.get_unix_time_from_system()) - unix
	if secs < 90:
		return tr("just now")
	if secs < 3600:
		return tr("%d min ago") % (secs / 60)
	if secs < 86400:
		return tr("%d h ago") % (secs / 3600)
	return tr("%d days ago") % (secs / 86400)

func _on_save_to_slot(slot: int) -> void:
	# Saving into a garden makes it the one being played — otherwise the next
	# autosave would write the same build into the slot you just left.
	if SaveManager.save_game(slot):
		SaveManager.set_current_slot(slot)
		_show_status(tr("Saved to garden %d") % (slot + 1))
	else:
		_show_status("Could not save - storage unavailable")
	_refresh_gardens()

func _on_open_slot(slot: int) -> void:
	# The garden on screen goes back into ITS slot first. Autosave has almost
	# certainly done this already; almost is not good enough here.
	if not GridManager.get_all_cells().is_empty():
		SaveManager.save_game()
	SaveManager.set_current_slot(slot)
	if SaveManager.load_game(slot):
		_show_status(tr("Opened garden %d") % (slot + 1))
	else:
		GridManager.clear_all()
		_show_status(tr("Garden %d could not be read") % (slot + 1))
	_refresh_gardens()

func _on_clear_slot_confirmed() -> void:
	if _slot_to_clear < 0:
		return
	SaveManager.clear_slot(_slot_to_clear)
	if _slot_to_clear == SaveManager.current_slot:
		GridManager.clear_all()
	_show_status(tr("Garden %d deleted") % (_slot_to_clear + 1))
	_slot_to_clear = -1
	_refresh_gardens()

func _show_status(text: String) -> void:
	status_label.text = text
	status_label.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(STATUS_FADE_TIME)
	tween.tween_property(status_label, "modulate:a", 0.0, 0.4)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	_save_settings(value)

func _load_settings() -> void:
	var config := ConfigFile.new()
	var volume: float = 0.8
	if config.load(SETTINGS_PATH) == OK:
		volume = config.get_value("audio", "master_volume", 0.8)
	volume_slider.value = volume
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume))

func _save_settings(volume: float) -> void:
	var config := ConfigFile.new()
	# Load first so the other keys the main-menu settings panel wrote
	# (music_volume / sfx_volume) survive — a fresh ConfigFile would wipe them.
	config.load(SETTINGS_PATH)
	config.set_value("audio", "master_volume", volume)
	config.save(SETTINGS_PATH)
