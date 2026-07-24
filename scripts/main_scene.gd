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

func _paint(mi: MeshInstance3D, color: Color) -> void:
	# The island materials are baked sub-resources shared with the .tscn —
	# override instead of mutating them.
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	mi.set_surface_override_material(0, m)
