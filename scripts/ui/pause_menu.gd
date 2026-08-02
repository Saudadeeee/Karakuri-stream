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
@onready var confirm_load_dialog: ConfirmationDialog = $ConfirmLoadDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# Seamless continue: "Về menu chính" auto-saves, so entering the game
	# restores the last build automatically (first run has no save → skipped).
	if SaveManager.has_save():
		SaveManager.load_game.call_deferred()

	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(confirm_load_dialog.popup_centered)
	clear_button.pressed.connect(confirm_clear_dialog.popup_centered)
	menu_button.pressed.connect(_on_menu_pressed)
	confirm_clear_dialog.confirmed.connect(_on_clear_confirmed)
	confirm_load_dialog.confirmed.connect(_on_load_confirmed)
	volume_slider.value_changed.connect(_on_volume_changed)

	_build_journal()
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
	if _journal_panel != null and _journal_panel.visible:
		_journal_panel.visible = false
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

func _on_load_confirmed() -> void:
	if SaveManager.load_game():
		_show_status("Build loaded")
	elif SaveManager.has_save():
		# The file exists but nothing in it could be rebuilt. The build on
		# screen is deliberately left untouched.
		_show_status("Saved build is unreadable — kept what you have")
	else:
		_show_status("No saved build yet")

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
	head.text = "Journal  %d / %d" % [DiscoveryLog.count_found(), DiscoveryLog.ENTRIES.size()]
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 20)
	box.add_child(head)

	for e in DiscoveryLog.ENTRIES:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 13)
		if DiscoveryLog.has(String(e["id"])):
			row.text = "%s — %s" % [e["title"], e["note"]]
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
