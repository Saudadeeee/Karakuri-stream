extends Node3D

## Sandbox scene root: on load, repaint the baked environment/sun/island to the
## MAP THEME the player picked on the menu (MapThemes.current). Gameplay is
## identical on every map — only the diorama's dress changes.
## Also hosts PHOTO MODE: H hides all UI + the ghost for clean screenshots,
## U nudges the sun around for golden-hour shots.

var _photo_mode: bool = false

func _ready() -> void:
	print("GAME ready ", Time.get_ticks_msec(), "ms")
	MapThemes.load_current()
	var env: Environment = $WorldEnvironment.environment
	MapThemes.apply_environment(env, $DirectionalLight3D)
	QualityManager.apply(self, env, $DirectionalLight3D, $FillLight)
	# Captured AFTER the theme has had its say, so "back to noon" means this
	# map's noon rather than whatever the scene file happened to store.
	_sun_rest = $DirectionalLight3D.transform
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
	# First run ever (no save yet): a small STARTER GARDEN machine already
	# running in one corner — spout → shishi-odoshi → drum, a pond turning a
	# gear — so the blank island never stares back at a new player. One-time:
	# any later session auto-loads the player's own build instead.
	if not SaveManager.has_save():
		_build_starter_garden.call_deferred()
	_maybe_show_controls.call_deferred()

## How many presses of `U` walk the sun all the way round. Twelve, so a press is
## a neat 30° and a player who has gone too far only has to keep going.
const SUN_STEPS: int = 12

var _sun_step: int = 0
var _sun_rest: Transform3D

func _unhandled_input(event: InputEvent) -> void:
	# `is_echo()` matters more than it looks. Holding a key makes the OS repeat
	# it — dozens of `pressed` events a second, all of which arrive here — and
	# none of these three actions wants that. Holding `U` span the sun far too
	# fast to land anywhere on purpose, which is how it was reported: press it a
	# few times and you cannot get the light back. `H` flickered the UI on and
	# off and settled wherever the release happened to fall, and `P` would have
	# handed the browser a download per repeat.
	if not (event is InputEventKey and event.pressed) or event.is_echo():
		return
	if event.keycode == KEY_H:
		_photo_mode = not _photo_mode
		$UI.visible = not _photo_mode
		$PlacementController.set("photo_mode", _photo_mode)
	elif event.keycode == KEY_U:
		_walk_sun()
	elif event.keycode == KEY_P:
		_take_screenshot()

## Walk the sun one step round. Set ABSOLUTELY from the orientation the scene
## started with rather than by rotating the light again each time: the step is
## then a number that wraps, so twelve presses is exactly a full circle and
## "keep pressing until it looks right" is guaranteed to work rather than
## approximately work. The toast says where you are, because a player who has
## made it dark needs to know the way out is forwards.
func _walk_sun() -> void:
	_sun_step = (_sun_step + 1) % SUN_STEPS
	$DirectionalLight3D.transform = _sun_rest.rotated(
		Vector3.UP, TAU * float(_sun_step) / float(SUN_STEPS))
	if _sun_step == 0:
		_toast("Sun back where it started")
	else:
		_toast("Sun %d/%d" % [_sun_step, SUN_STEPS])

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
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-240, -235)
	panel.custom_minimum_size = Vector2(480, 0)
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
		+ "Put a spout above things and let the water find them.\n" \
		+ "Build enough to hear and animals move in. Birds play your bells.\n" \
		+ "Ctrl+Z undo · H hide UI · U move the sun · P screenshot"
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
## The first thing anyone ever sees. It is not a tutorial and it is not a save —
## it is the game already running, so a new player arrives to water falling,
## something knocking on the beat, and a bird deciding whether to land.
##
## Built TIGHT and around the origin on purpose. The old one was scattered from
## x=-5 to x=-1 with the camera at zoom 15, which framed the whole island: a
## bare green disc with a few specks on one edge. Everything here now sits inside
## five cells of the middle so the opening shot is the machine, not the lawn.
func _build_starter_garden() -> void:
	# The pour, and what it lands on. Spout → shishi-odoshi → drum: cốc… tùm.
	_starter(Vector3i(0, 3, 0), BlockData.Type.SOURCE)
	_starter(Vector3i(0, 1, 0), BlockData.Type.SHISHI)
	_starter(Vector3i(0, 0, 0), BlockData.Type.DRUM)
	# Three notes in a row, so the first thing a player hears is a phrase rather
	# than a single sound, and the first thing they see is that blocks LINE UP.
	_starter(Vector3i(-2, 0, -1), BlockData.Type.CHIME, 0)
	_starter(Vector3i(-2, 0, 0), BlockData.Type.CHIME, 2)
	_starter(Vector3i(-2, 0, 1), BlockData.Type.CHIME, 4)
	# A pond, because water is the best-looking thing in the game and the old
	# opening shot had almost none of it.
	for z in [1, 2]:
		for x in [2, 3]:
			_starter(Vector3i(x, 0, z), BlockData.Type.WATER)
	# The pond turns a wheel, the wheel plays a box: the whole machine idea in
	# two blocks, running before anyone touches anything.
	#
	# Both sit ON THE GROUND beside the water, not above it. Putting the gear a
	# level up over a water cell is mechanically fine — it still touches the pond
	# — but it renders as a heap of sticks hovering on the surface, and the music
	# box next to it looked half-sunk in the bank. A gear only reads as a gear
	# when it is standing on something.
	_starter(Vector3i(1, 0, 1), BlockData.Type.GEAR)          # touches (2,0,1)
	_starter(Vector3i(1, 0, 2), BlockData.Type.MUSIC_BOX)     # beside the gear
	# A short deck along the near bank, so the pond has an edge rather than
	# stopping in mid-lawn.
	_starter(Vector3i(1, 0, 0), BlockData.Type.WOOD)
	_starter(Vector3i(2, 0, 0), BlockData.Type.WOOD)
	# Quiet things around the edge that reward looking.
	_starter(Vector3i(-1, 0, 2), BlockData.Type.STONE_LANTERN)
	_starter(Vector3i(1, 0, -2), BlockData.Type.JELLY, 1)
	_starter(Vector3i(-1, 0, -2), BlockData.Type.PINWHEEL, 1)

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
