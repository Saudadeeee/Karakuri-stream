extends Node3D

## Start menu. A live 3D garden backdrop (same sky/island as the game, decorated
## by the scenery autoloads and drifting petals, with the chill music already
## playing) sits behind a themed UI card: title sign, Play / Settings / Quit, and
## a slide-in settings panel with per-bus volume sliders. "Play" loads the sandbox.

const MAIN_SCENE := "res://scenes/main.tscn"
const SETTINGS_PATH := "user://settings.cfg"

const CREAM := Color("f4efe2")
const WOOD_SIGN := Color("7a5a3a")
const WOOD_SIGN_EDGE := Color("caa878")
const TEXT := Color("4a3f35")
const SALMON := Color("e07a5f")
const GREEN := Color("8cb369")

var _cam_rig: Node3D
var _settings_panel: Panel
var _env: Environment
var _sun: DirectionalLight3D
var _island_top: MeshInstance3D
var _island_base: MeshInstance3D
var _map_cards: Array[Button] = []

func _ready() -> void:
	MapThemes.load_current()
	_build_backdrop()
	_build_ui()
	_load_audio()
	_apply_theme()

func _process(delta: float) -> void:
	if is_instance_valid(_cam_rig):
		_cam_rig.rotate_y(delta * 0.045)   # slow drift so the diorama breathes

# ----------------------------------------------------------------- 3D backdrop
func _build_backdrop() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.72, 0.71)
	sky_mat.sky_horizon_color = Color(0.92, 0.78, 0.79)
	sky_mat.sky_curve = 0.18
	sky_mat.ground_bottom_color = Color(0.86, 0.74, 0.76)
	sky_mat.ground_horizon_color = Color(0.92, 0.78, 0.79)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.82, 0.85)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC   # match the game's grade
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_env = env

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-30.0), 0.0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	add_child(sun)
	_sun = sun

	_add_island()

	_cam_rig = Node3D.new()
	add_child(_cam_rig)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 5.2, 15.0)
	cam.look_at_from_position(cam.position, Vector3(0.0, 1.2, 0.0), Vector3.UP)
	cam.fov = 58.0
	_cam_rig.add_child(cam)
	cam.make_current()

func _add_island() -> void:
	var ground := Node3D.new()
	add_child(ground)
	var top := MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 9.0; top_mesh.bottom_radius = 9.0; top_mesh.height = 0.2; top_mesh.radial_segments = 48
	top.mesh = top_mesh
	top.material_override = _matte(Color(0.55, 0.58, 0.44))
	top.position = Vector3(0, -0.1, 0)
	ground.add_child(top)
	_island_top = top
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 9.0; base_mesh.bottom_radius = 1.5; base_mesh.height = 7.0; base_mesh.radial_segments = 48
	base.mesh = base_mesh
	base.material_override = _matte(Color(0.4, 0.3, 0.22))
	base.position = Vector3(0, -3.7, 0)
	ground.add_child(base)
	_island_base = base

func _matte(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic = 0.0
	return m

# ----------------------------------------------------------------------- UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Centre column
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.position = Vector2(-150, -170)
	col.custom_minimum_size = Vector2(300, 0)
	root.add_child(col)

	col.add_child(_title_sign())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	col.add_child(spacer)

	col.add_child(_map_picker())
	col.add_child(_menu_button("Chơi", _on_play))
	col.add_child(_menu_button("Cài đặt", _on_settings))
	col.add_child(_menu_button("Thoát", _on_quit))

	# Footer hint
	var hint := Label.new()
	hint.text = "Thả khối · nghe suối chảy · thư giãn"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(TEXT.r, TEXT.g, TEXT.b, 0.7)
	hint.add_theme_font_size_override("font_size", 15)
	var foot := Control.new()
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.position = Vector2(0, -46)
	foot.add_child(hint)
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.position = Vector2(-140, 0)
	hint.custom_minimum_size = Vector2(280, 0)
	root.add_child(foot)

	_build_settings_panel(root)

## A carved wooden sign holding the title.
func _title_sign() -> Panel:
	var sign := Panel.new()
	sign.custom_minimum_size = Vector2(300, 118)
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD_SIGN
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(5)
	sb.border_color = WOOD_SIGN_EDGE
	sb.shadow_color = Color(0.2, 0.16, 0.12, 0.28)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sign.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	sign.add_child(box)

	var title := Label.new()
	title.text = "KARAKURI STREAM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("fdf3e3"))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "- Vườn Thủy Cơ -"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color("f5c4a8"))
	box.add_child(sub)
	return sign

## A row of MAP CARDS — one per theme, tinted with that theme's sky so the
## choice itself previews the map. The selected card gets a salmon border and
## the live 3D backdrop behind the menu switches instantly.
func _map_picker() -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var cap := Label.new()
	cap.text = "Bản đồ"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 15)
	cap.modulate = Color(TEXT.r, TEXT.g, TEXT.b, 0.85)
	wrap.add_child(cap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	wrap.add_child(row)
	for i in MapThemes.count():
		var card := Button.new()
		card.custom_minimum_size = Vector2(66, 58)
		card.text = MapThemes.name_of(i).split(" ")[-1]  # Xuân/Thu/Tuyết/Đóm
		card.add_theme_font_size_override("font_size", 14)
		card.pressed.connect(_on_map_card.bind(i))
		row.add_child(card)
		_map_cards.append(card)
	return wrap

func _on_map_card(i: int) -> void:
	MapThemes.current = i
	MapThemes.save_current()
	_apply_theme()
	SceneryManager.rebuild()
	AmbientLeaves.rebuild()
	AmbientMusic.apply_theme_mix()

## Repaint the live backdrop + restyle the cards for the current theme.
func _apply_theme() -> void:
	var t: Dictionary = MapThemes.theme()
	MapThemes.apply_environment(_env, _sun)
	if is_instance_valid(_island_top):
		(_island_top.material_override as StandardMaterial3D).albedo_color = t["island_top"]
		(_island_base.material_override as StandardMaterial3D).albedo_color = t["island_base"]
	for i in _map_cards.size():
		var ti: Dictionary = MapThemes.THEMES[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = ti["sky_horizon"]
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(3 if i == MapThemes.current else 1)
		sb.border_color = SALMON if i == MapThemes.current else Color(0.5, 0.42, 0.34, 0.6)
		_map_cards[i].add_theme_stylebox_override("normal", sb)
		_map_cards[i].add_theme_stylebox_override("hover", sb)
		_map_cards[i].add_theme_stylebox_override("pressed", sb)
		var dark_sky: bool = ti["sky_horizon"].get_luminance() < 0.45
		_map_cards[i].add_theme_color_override("font_color", Color("f4efe2") if dark_sky else TEXT)
		_map_cards[i].add_theme_color_override("font_hover_color", Color("f4efe2") if dark_sky else TEXT)

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 54)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(cb)
	return b

# ------------------------------------------------------------ settings panel
func _build_settings_panel(root: Control) -> void:
	_settings_panel = Panel.new()
	_settings_panel.custom_minimum_size = Vector2(360, 300)
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-180, -150)
	_settings_panel.visible = false
	root.add_child(_settings_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	box.offset_left = 24; box.offset_top = 22
	box.offset_right = -24; box.offset_bottom = -22
	_settings_panel.add_child(box)

	var head := Label.new()
	head.text = "Cài đặt âm thanh"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 24)
	box.add_child(head)

	box.add_child(_slider_row("Tổng", "Master"))
	box.add_child(_slider_row("Nhạc nền", "Music"))
	box.add_child(_slider_row("Hiệu ứng", "SFX"))

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)

	var close := Button.new()
	close.text = "Đóng"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(func(): _settings_panel.visible = false)
	box.add_child(close)

func _slider_row(label_text: String, bus_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(96, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0; s.max_value = 1.0; s.step = 0.01
	s.custom_minimum_size = Vector2(180, 0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value = _bus_linear(bus_name)
	s.value_changed.connect(_on_bus_volume.bind(bus_name))
	row.add_child(s)
	return row

# --------------------------------------------------------------- actions
func _on_play() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible

func _on_quit() -> void:
	get_tree().quit()

# --------------------------------------------------------------- audio glue
func _bus_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 0.8
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _on_bus_volume(value: float, bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	_save_audio()

func _load_audio() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in ["Master", "Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			var v: float = cfg.get_value("audio", bus.to_lower() + "_volume", 0.8)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))

func _save_audio() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for bus in ["Master", "Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			cfg.set_value("audio", bus.to_lower() + "_volume", db_to_linear(AudioServer.get_bus_volume_db(idx)))
	cfg.save(SETTINGS_PATH)
