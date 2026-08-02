extends Node3D

## Sandbox scene root: on load, repaint the baked environment/sun/island to the
## MAP THEME the player picked on the menu (MapThemes.current). Gameplay is
## identical on every map — only the diorama's dress changes.
## Also hosts PHOTO MODE: H hides all UI + the ghost for clean screenshots,
## U nudges the sun around for golden-hour shots.

var _photo_mode: bool = false

func _ready() -> void:
	MapThemes.load_current()
	var env: Environment = $WorldEnvironment.environment
	MapThemes.apply_environment(env, $DirectionalLight3D)
	QualityManager.apply(self, env, $DirectionalLight3D, $FillLight)
	# The sculpted island (IslandBuilder autoload) replaces the old cylinders;
	# the flat collision box in this scene still handles raycasts.
	$Ground/IslandTop.visible = false
	$Ground/IslandBase.visible = false
	AmbientMusic.apply_theme_mix()
	CloudSea.apply_theme()
	IslandBuilder.rebuild()
	KarakuriClock.rebuild()
	# F3 readout — the only way to get real numbers off the web build.
	add_child(preload("res://scripts/ui/perf_overlay.gd").new())
	# Erase + Undo buttons, on touch devices only (see touch_controls.gd).
	const TOUCH_CONTROLS := preload("res://scripts/ui/touch_controls.gd")
	if TOUCH_CONTROLS.should_show():
		var touch: Control = TOUCH_CONTROLS.new()
		touch.setup($PlacementController)
		$UI.add_child(touch)
	# First run ever (no save yet): a small STARTER GARDEN machine already
	# running in one corner — spout → shishi-odoshi → drum, a pond turning a
	# gear — so the blank island never stares back at a new player. One-time:
	# any later session auto-loads the player's own build instead.
	if not SaveManager.has_save():
		_build_starter_garden.call_deferred()
		_frame_starter_garden.call_deferred()
	_maybe_show_controls.call_deferred()
	# Autosave only runs while a garden is on screen — see save_manager.gd.
	SaveManager.autosave_armed = true
	DiscoveryLog.discovered.connect(func(_id: String) -> void: _drain_discoveries())
	# A garden loaded from a save may already contain things this player has never
	# been told about; the log notices them on its first scan.
	_drain_discoveries.call_deferred()

## Leaving the scene at all (menu, quit, reload) ends the window in which an
## autosave means anything: the grid is about to be cleared.
func _exit_tree() -> void:
	SaveManager.autosave_armed = false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_H:
		_photo_mode = not _photo_mode
		$UI.visible = not _photo_mode
		$PlacementController.set("photo_mode", _photo_mode)
	elif event.keycode == KEY_U:
		# Walk the sun 30° per press — evening light wraps back to morning.
		$DirectionalLight3D.rotate_y(deg_to_rad(30.0))
	elif event.keycode == KEY_P:
		_take_screenshot()

# ------------------------------------------------------- first-run controls
## One-time controls card (non-gamers never guess middle-drag). Dismissed with
## "Got it" and remembered in settings.cfg.
func _maybe_show_controls() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	if bool(cfg.get_value("ui", "seen_controls", false)):
		return
	var panel := PanelContainer.new()
	panel.name = "ControlsCard"
	panel.custom_minimum_size = Vector2(480, 0)
	# Placed from the viewport and the card's OWN size, with no anchors involved.
	# It used to sit at a hardcoded -235 under a CENTER_BOTTOM anchor, and the card
	# is taller than that — its bottom border and half the "Got it" button hung
	# below the screen edge at every resolution, because this UI is laid out in
	# fixed 1280x720 logical units. ($UI is a CanvasLayer, which has no rect of its
	# own, so anchor-relative offsets here are a trap: they read as raw positions
	# the moment anything re-lays the card out.)
	var place := func() -> void:
		var vp: Vector2 = panel.get_viewport_rect().size
		panel.position = Vector2((vp.x - panel.size.x) * 0.5, vp.y - panel.size.y - 28.0)
	panel.resized.connect(place)
	get_viewport().size_changed.connect(place)
	$UI.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "How to play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var body := Label.new()
	body.text = "Left click — place a block        Right click — remove\n" \
		+ "Middle drag — orbit camera      Scroll — zoom\n" \
		+ "Click a hotbar icon again — change its style / tempo\n" \
		+ "Q — houses. Line them up and they become one building.\n" \
		+ "Build a village and animals move in. Birds play your bells.\n" \
		+ "Ctrl+Z undo · H hide UI · U move the sun · P screenshot · F11 fullscreen"
	if preload("res://scripts/ui/touch_controls.gd").should_show():
		body.text = "Tap — place a block        Erase button — delete mode
" 			+ "One finger — orbit camera      Two fingers — pinch zoom
" 			+ "Tap a hotbar icon again — change its style / tempo
" 			+ "Q — houses. Line them up and they become one building.
" 			+ "Build a village and animals move in. Birds play your bells.
" 			+ "Undo button — take back the last block"
	body.add_theme_font_size_override("font_size", 15)
	box.add_child(body)
	var ok := Button.new()
	ok.text = "Got it"
	ok.custom_minimum_size = Vector2(0, 42)
	box.add_child(ok)
	CuteButton.wire(ok)
	ok.pressed.connect(func():
		panel.queue_free()
		var c := ConfigFile.new()
		c.load("user://settings.cfg")
		c.set_value("ui", "seen_controls", true)
		c.save("user://settings.cfg"))
	# `resized` only fires when the size CHANGES, and a card built in one pass can
	# reach its final size before anything is connected — leaving it parked at the
	# anchor, entirely off the bottom of the screen. Place it once by hand after
	# the first layout, then let the signal handle any later reflow.
	await get_tree().process_frame
	place.call()

# ------------------------------------------------------- discovery cards
## One card at a time, bottom centre, gone in a few seconds. It says what the
## town just did and why — the whole feature is "notice it out loud once".
## Deliberately not a popup: nothing pauses, nothing needs dismissing, and if the
## player is mid-drag they can ignore it entirely and find it again in the pause
## menu's journal.
var _card_busy: bool = false

func _drain_discoveries() -> void:
	if _card_busy:
		return
	var id := DiscoveryLog.take_pending()
	if id == "":
		return
	var e: Dictionary = DiscoveryLog.entry(id)
	if e.is_empty():
		return
	_card_busy = true

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.modulate.a = 0.0
	$UI.add_child(panel)
	# Same placement rule as the controls card, and for the same reason.
	var place := func() -> void:
		var vp: Vector2 = panel.get_viewport_rect().size
		panel.position = Vector2((vp.x - panel.size.x) * 0.5, vp.y - panel.size.y - 96.0)
	panel.resized.connect(place)
	get_viewport().size_changed.connect(place)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := Label.new()
	head.text = "The town made %s" % String(e["title"]).to_lower()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 18)
	box.add_child(head)
	var note := Label.new()
	note.text = String(e["note"])
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 13)
	note.modulate.a = 0.75
	box.add_child(note)

	await get_tree().process_frame
	place.call()

	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.35)
	tw.tween_interval(4.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(func() -> void:
		_card_busy = false
		_drain_discoveries())

# ------------------------------------------------------------- screenshot
## P: clean screenshot (UI + ghost hidden for the frame). Desktop saves to
## user://screenshots/, web hands the PNG to the browser as a download.
func _take_screenshot() -> void:
	var ui_was: bool = $UI.visible
	$UI.visible = false
	var ghost_was: bool = $PlacementController.photo_mode
	$PlacementController.photo_mode = true
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	$UI.visible = ui_was and not _photo_mode
	$PlacementController.photo_mode = ghost_was or _photo_mode
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), "karakuri-stream.png", "image/png")
	else:
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		var path := "user://screenshots/karakuri-%d.png" % Time.get_ticks_msec()
		img.save_png(path)
	_toast("Screenshot saved")

## Small fading confirmation under the top edge.
func _toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-80, 24)
	label.add_theme_font_size_override("font_size", 16)
	$UI.add_child(label)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)

## The demo machine: ~12 blocks in the -X/-Z corner showing the core loop
## (falling water plays percussion; still water powers gears) while leaving
## the island centre free to build on.
func _build_starter_garden() -> void:
	# Tower: spout pours onto a shishi-odoshi that tips onto a drum. Cốc… tùm!
	_starter(Vector3i(-4, 0, -3), BlockData.Type.DRUM)
	_starter(Vector3i(-4, 1, -3), BlockData.Type.SHISHI)
	_starter(Vector3i(-4, 3, -3), BlockData.Type.SOURCE)
	# A chime beside the drum catches splashes of the same rhythm visually.
	_starter(Vector3i(-3, 0, -3), BlockData.Type.CHIME, 2)
	# Pond driving a gear (with a mill beside it so both models show).
	_starter(Vector3i(-2, 0, 2), BlockData.Type.WOOD)
	_starter(Vector3i(-3, 0, 2), BlockData.Type.WOOD, 2)
	_starter(Vector3i(-3, 1, 2), BlockData.Type.WATER)
	_starter(Vector3i(-2, 1, 2), BlockData.Type.GEAR)
	_starter(Vector3i(-1, 1, 2), BlockData.Type.GEAR, 1)
	# A little life in the corner: lantern + jelly greeter.
	_starter(Vector3i(-5, 0, 0), BlockData.Type.STONE_LANTERN)
	_starter(Vector3i(-4, 0, 0), BlockData.Type.JELLY, 1)

## Turn the camera to the demo machine on the very first run. The starter garden
## sits in the -X/-Z corner so the middle of the island stays free to build on,
## but the camera opened facing +Z with the pivot at the origin — which put the
## one thing built to teach the game at the edge of the frame, half of it behind
## the how-to-play card. -70 degrees puts the whole chain across the view: spout
## and shishi on the left, jelly and lantern centre, pond and gear on the right.
func _frame_starter_garden() -> void:
	var rig: Node3D = $OrbitRig
	rig.rotation.y = deg_to_rad(-70.0)
	rig.set("_target_zoom", 11.0)
	var arm: SpringArm3D = rig.get_node_or_null("SpringArm3D")
	if arm != null:
		arm.spring_length = 11.0

func _starter(cell: Vector3i, type: int, variant: int = 0) -> void:
	if GridManager.has_block(cell):
		return
	var instance: Node3D = BlockFactory.instantiate(type)
	add_child(instance)
	instance.position = GridManager.cell_to_world(cell)
	if "grid_cell" in instance:
		instance.grid_cell = cell
	var block := BlockData.new(type, instance)
	block.state["variant"] = variant
	if instance.has_method("apply_variant"):
		instance.apply_variant(BlockVariants.get_variant(type, variant))
	GridManager.set_block(cell, block)
	if instance.has_method("refresh_shape"):
		instance.refresh_shape()
	elif instance.has_method("face_adjacent_water"):
		instance.face_adjacent_water()
