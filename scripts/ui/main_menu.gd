extends Node3D

## Start menu. A live 3D garden backdrop (same sky/island as the game, decorated
## by the scenery autoloads and drifting petals, with the chill music already
## playing) sits behind a themed UI card: title sign, Play / Settings / Quit, and
## a slide-in settings panel with per-bus volume sliders. "Play" loads the sandbox.

const MAIN_SCENE := "res://scenes/main.tscn"
const SETTINGS_PATH := "user://settings.cfg"

const CREAM := Color("f4efe2")
const TEXT := Color("4a3f35")
const SALMON := Color("e07a5f")

var _cam_rig: Node3D
var _settings_panel: Panel
var _env: Environment
var _sun: DirectionalLight3D
var _map_cards: Array[Button] = []

func _ready() -> void:
	MapThemes.load_current()
	_build_backdrop()
	_build_title_3d()
	_build_ui()
	_load_audio()
	_apply_theme()
	# Every button in this menu is built in code above, so one sweep at the end
	# is simpler and harder to forget than wiring each one at its call site.
	CuteButton.apply_all(self)

func _process(delta: float) -> void:
	if is_instance_valid(_cam_rig):
		_cam_rig.rotate_y(delta * 0.045)   # slow drift so the diorama breathes
	if is_instance_valid(_title_root):
		# Bob gently and turn WITH the drifting camera so the wordmark always
		# faces the player while still living inside the 3D scene.
		var t: float = Time.get_ticks_msec() / 1000.0
		_title_root.position.y = 5.6 + sin(t * 0.8) * 0.12
		_title_root.rotation.y = _cam_rig.rotation.y
		if is_instance_valid(_cog_l):
			_cog_l.rotate_z(delta * 0.6)
			_cog_r.rotate_z(-delta * 0.6)   # meshing = opposite spin
		if is_instance_valid(_pendulum):
			_pendulum.rotation.z = sin(t * PI) * 0.18

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
	QualityManager.apply(self, env, sun)

	# Island visual comes from the IslandBuilder autoload (sculpted mesh).
	IslandBuilder.rebuild()

	_cam_rig = Node3D.new()
	add_child(_cam_rig)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 5.2, 15.0)
	cam.look_at_from_position(cam.position, Vector3(0.0, 1.2, 0.0), Vector3.UP)
	cam.fov = 58.0
	_cam_rig.add_child(cam)
	cam.make_current()

# -------------------------------------------------------------- 3D title
## The game's name as REAL 3D lettering floating over the island — extruded
## wooden TextMesh with a cream back-copy as a soft drop shadow, gently
## bobbing. Part of the diorama, not a flat sign pasted on top.
var _title_root: Node3D
var _cog_l: MeshInstance3D
var _cog_r: MeshInstance3D
var _pendulum: Node3D

func _build_title_3d() -> void:
	_title_root = Node3D.new()
	_title_root.position = Vector3(0, 5.6, 0)
	add_child(_title_root)

	var lines := [
		{"text": "KARAKURI", "size": 1.35, "y": 0.75},
		{"text": "STREAM", "size": 1.35, "y": -0.55},
	]
	# Sticker treatment: a FAT cream halo behind a warm wood face. The polarity
	# matters and used to be the other way round — a cream face on the pale pink
	# spring sky had almost no contrast and the title read as an outline.
	#
	# It has to survive all four skies, which rules out picking one colour: a dark
	# face vanishes on the indigo night map, a light one vanishes on pink and
	# snow. Doing both is what makes it theme-proof — the halo separates the
	# letters from a dark sky, the face separates them from a pale one.
	for l in lines:
		_add_haloed(l["text"], l["size"], l["y"], Color("7d5533"), 0.16, 0.035)
	# Subtitle got the same treatment — plain salmon on a pink sky was invisible.
	_add_haloed("- A WATER GARDEN TOY -", 0.42, -1.62, Color("c2694a"), 0.05, 0.016)

	# The wordmark hangs on a running MOVEMENT: two meshing wooden cogs flank it
	# and a weight-pendulum keeps time — the karakuri soul at first glance.
	var cw := Color("6b4a30")
	_cog_l = _cog_face(0.95, 12, cw)
	_cog_l.position = Vector3(-3.7, 0.1, -0.18)
	_title_root.add_child(_cog_l)
	_cog_r = _cog_face(0.95, 12, cw)
	_cog_r.position = Vector3(3.7, 0.1, -0.18)
	_cog_r.rotation.z = PI / 12.0   # half-tooth offset → reads as meshing
	_title_root.add_child(_cog_r)
	# Pendulum under the subtitle: a thin dowel + weight bob, pivots at top.
	_pendulum = Node3D.new()
	_pendulum.position = Vector3(0, -2.05, 0)
	_title_root.add_child(_pendulum)
	var rod := MeshInstance3D.new()
	var rm := BoxMesh.new(); rm.size = Vector3(0.05, 0.7, 0.05)
	rod.mesh = rm; rod.position = Vector3(0, -0.35, 0)
	rod.material_override = _flat3(cw)
	_pendulum.add_child(rod)
	var bob := MeshInstance3D.new()
	var bm := SphereMesh.new(); bm.radius = 0.13; bm.height = 0.2
	bob.mesh = bm; bob.position = Vector3(0, -0.72, 0)
	bob.material_override = _flat3(Color("e07a5f"))
	_pendulum.add_child(bob)

## A flat cog facing +Z (toward the camera), spinning about +Z.
func _cog_face(diameter: float, teeth: int, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = GearMesh.build(teeth, diameter * 0.5, diameter * 0.4, diameter * 0.18, 0.12,
		col, col.lightened(0.08))
	mi.material_override = GearMesh.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _flat3(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

const HALO := Color("fff6e8")

## Text with a cream outline around it, and the reason it is built this way.
##
## The obvious outline — a second copy scaled up behind — does NOT work for text:
## scaling stretches the LETTER SPACING as well as the glyphs, so the two copies
## drift apart and you see doubled letterforms rather than an outline. Instead,
## four copies at the SAME size are nudged up/down/left/right behind the face, so
## every glyph lines up exactly.
##
## All five instances SHARE one TextMesh. Triangulating glyphs is the expensive
## part; five MeshInstance3D pointing at one mesh costs five draw calls and one
## triangulation, where five TextMesh resources would pay for the outlines five
## times over.
func _add_haloed(text: String, size: float, y: float, col: Color, depth: float, spread: float) -> void:
	var face := _letter_mesh(text, size, y, 0.0, col, depth)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var edge := MeshInstance3D.new()
		edge.mesh = face.mesh
		edge.position = Vector3(o.x * spread, y + o.y * spread, -0.12)
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.albedo_color = HALO
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		edge.material_override = m
		_title_root.add_child(edge)
	_title_root.add_child(face)

func _letter_mesh(text: String, size: float, y: float, z: float, col: Color, depth: float) -> MeshInstance3D:
	var tm := TextMesh.new()
	tm.text = text
	tm.font = ThemeDB.fallback_font
	tm.font_size = 64
	tm.pixel_size = size / 64.0
	tm.depth = depth
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.position = Vector3(0, y, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # no ghost text on the lawn
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # bold flat read
	mi.material_override = m
	return mi

# ----------------------------------------------------------------------- UI
## Layout: everything ANCHORED (no magic pixel offsets) — the 3D wordmark owns
## the top of the screen; the interactive strip sits along the bottom:
## map cards → a big salmon PLAY with small Settings/Quit wings → hint line.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(col)

	col.add_child(_map_picker())

	# PLAY front and centre, Settings/Quit as quiet wings.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var settings_b := _menu_button("Settings", _on_settings)
	settings_b.custom_minimum_size = Vector2(130, 48)
	row.add_child(settings_b)
	var play := _menu_button("P L A Y", _on_play)
	play.custom_minimum_size = Vector2(240, 62)
	play.add_theme_font_size_override("font_size", 26)
	var psb := StyleBoxFlat.new()
	psb.bg_color = SALMON
	psb.set_corner_radius_all(18)
	psb.set_border_width_all(3)
	psb.border_color = Color("c96a52")
	psb.shadow_color = Color(0.2, 0.1, 0.06, 0.3)
	psb.shadow_size = 8
	psb.shadow_offset = Vector2(0, 4)
	play.add_theme_stylebox_override("normal", psb)
	var psb_h: StyleBoxFlat = psb.duplicate()
	psb_h.bg_color = SALMON.lightened(0.08)
	play.add_theme_stylebox_override("hover", psb_h)
	var psb_p: StyleBoxFlat = psb.duplicate()
	psb_p.bg_color = SALMON.darkened(0.1)
	play.add_theme_stylebox_override("pressed", psb_p)
	play.add_theme_color_override("font_color", Color("fff6ee"))
	play.add_theme_color_override("font_hover_color", Color.WHITE)
	row.add_child(play)
	# No Quit in the browser: get_tree().quit() cannot close a tab, so the button
	# would just look broken. The web build simply doesn't offer one.
	if not OS.has_feature("web"):
		var quit_b := _menu_button("Quit", _on_quit)
		quit_b.custom_minimum_size = Vector2(130, 48)
		row.add_child(quit_b)

	var hint := Label.new()
	hint.text = "drop blocks · hear the stream · relax"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(TEXT.r, TEXT.g, TEXT.b, 0.65)
	hint.add_theme_font_size_override("font_size", 14)
	col.add_child(hint)

	_build_settings_panel(root)

## A row of MAP CARDS — one per theme, tinted with that theme's sky so the
## choice itself previews the map. The selected card gets a salmon border and
## the live 3D backdrop behind the menu switches instantly.
func _map_picker() -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var cap := Label.new()
	cap.text = "Map"
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
	CloudSea.apply_theme()
	IslandBuilder.rebuild()
	KarakuriClock.rebuild()

## Repaint the live backdrop + restyle the cards for the current theme.
func _apply_theme() -> void:
	var t: Dictionary = MapThemes.theme()
	MapThemes.apply_environment(_env, _sun)
	# (island colours now live in IslandBuilder.rebuild)
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
	head.text = "Audio settings"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 24)
	box.add_child(head)

	box.add_child(_slider_row("Master", "Master"))
	box.add_child(_slider_row("Music", "Music"))
	box.add_child(_slider_row("Effects", "SFX"))

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)

	var close := Button.new()
	close.text = "Close"
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
