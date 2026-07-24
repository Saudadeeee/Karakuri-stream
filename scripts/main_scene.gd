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
	var t: Dictionary = MapThemes.theme()
	_paint($Ground/IslandTop, t["island_top"])
	_paint($Ground/IslandBase, t["island_base"])
	AmbientMusic.apply_theme_mix()
	# First run ever (no save yet): a small STARTER GARDEN machine already
	# running in one corner — spout → shishi-odoshi → drum, a pond turning a
	# gear — so the blank island never stares back at a new player. One-time:
	# any later session auto-loads the player's own build instead.
	if not SaveManager.has_save():
		_build_starter_garden.call_deferred()

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

func _paint(mi: MeshInstance3D, color: Color) -> void:
	# The island materials are baked sub-resources shared with the .tscn —
	# override instead of mutating them.
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	mi.set_surface_override_material(0, m)
