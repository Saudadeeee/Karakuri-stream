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
var _settings_panel: PanelContainer
var _env: Environment
var _sun: DirectionalLight3D
var _map_cards: Array[Button] = []
## Re-read-your-own-state callbacks for the settings rows. F11 and the window
## manager can change fullscreen without going through the panel, so the panel
## refreshes from the real state every time it opens rather than trusting a
## cached bool.
var _settings_widgets: Array[Callable] = []
var _credits_panel: PanelContainer

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
	# F3 readout — the only way to get real numbers off the web build.
	add_child(preload("res://scripts/ui/perf_overlay.gd").new())

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
	# Four offsets make a true outline; one makes a drop shadow. The web LITE
	# profile takes the drop shadow, because each copy re-submits the whole glyph
	# mesh every frame and the title is the first thing a browser has to draw.
	var offsets: Array = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	if QualityManager.lite:
		offsets = [Vector2(-0.7, -0.7)]
	for o in offsets:
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

## TextMesh tessellates glyph curves in proportion to `font_size`, and
## `pixel_size` then scales the result to world units — so the two together set
## the DETAIL independently of how big the letters actually look.
##
## This was 64, which on a chunky flat-shaded wordmark bought nothing visible and
## made the title the heaviest object in the game: 245,000 vertices across its
## copies, six times the entire scenery ring, on the very first screen the player
## sees. At 26 the curves are still smooth at this size.
const TITLE_DETAIL := 26.0

func _letter_mesh(text: String, size: float, y: float, z: float, col: Color, depth: float) -> MeshInstance3D:
	var tm := TextMesh.new()
	tm.text = text
	tm.font = ThemeDB.fallback_font
	tm.font_size = int(TITLE_DETAIL)
	tm.pixel_size = size / TITLE_DETAIL
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
	# The UI font is a BITMAP face and the canvas is scaled to the window (a 720p
	# canvas on a 1080p screen is x1.5), so linear sampling turns every label into
	# mush. Children inherit this.
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

	# Credits. CC0 asks for nothing and the font's OFL only asks that the licence
	# travel with the file, so this is not a legal obligation — it is the one
	# place the people whose recordings this game is built out of get named where
	# a player can actually see it.
	var credits_b := _menu_button("Credits", _on_credits)
	credits_b.custom_minimum_size = Vector2(130, 40)
	credits_b.add_theme_font_size_override("font_size", 15)
	col.add_child(credits_b)

	# Version, small and out of the way. A build with no version on it is
	# untraceable the moment two copies exist in the wild.
	var ver := Label.new()
	ver.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.modulate = Color(TEXT.r, TEXT.g, TEXT.b, 0.4)
	ver.add_theme_font_size_override("font_size", 12)
	col.add_child(ver)

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
	# A PanelContainer that GROWS TO ITS CONTENT, not a Panel with a hardcoded
	# height. Vietnamese lines are taller than the English ones they replaced —
	# diacritics come from the fallback face — and the fixed 512 px card pushed
	# Fullscreen, the F11 hint and the Close button off its own bottom edge.
	_settings_panel = PanelContainer.new()
	_settings_panel.custom_minimum_size = Vector2(380, 0)
	_settings_panel.visible = false
	root.add_child(_settings_panel)
	var centre := func() -> void:
		var vp: Vector2 = _settings_panel.get_viewport_rect().size
		_settings_panel.position = (vp - _settings_panel.size) * 0.5
	_settings_panel.resized.connect(centre)
	get_viewport().size_changed.connect(centre)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_settings_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var head := Label.new()
	head.text = "Settings"
	head.set_meta("i18n_head", true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 24)
	box.add_child(head)

	box.add_child(_section_label("Sound"))
	box.add_child(_slider_row("Master", "Master"))
	box.add_child(_slider_row("Music", "Music"))
	box.add_child(_slider_row("Effects", "SFX"))
	box.add_child(_toggle_row("Mute away",
		func() -> bool: return AudioManager.duck_when_unfocused(),
		func(on: bool) -> void: AudioManager.set_duck_when_unfocused(on)))

	# Language sits with Sound rather than in a menu of its own: two languages do
	# not need a screen, and a player who cannot read the UI needs to find this
	# without reading much.
	box.add_child(_language_row())

	box.add_child(_section_label("Screen"))
	# A browser tab cannot resize itself and has no vsync switch of its own, so
	# the web build gets the one control that does work there.
	if not OS.has_feature("web"):
		box.add_child(_size_row())
		box.add_child(_toggle_row("V-Sync",
			func() -> bool: return DisplaySettings.is_vsync(),
			func(on: bool) -> void: DisplaySettings.set_vsync(on)))
	box.add_child(_toggle_row("Fullscreen",
		func() -> bool: return DisplaySettings.is_fullscreen(),
		func(on: bool) -> void: DisplaySettings.set_fullscreen(on)))
	var f11 := Label.new()
	f11.text = "F11 toggles fullscreen anywhere"
	f11.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f11.add_theme_font_size_override("font_size", 12)
	f11.modulate = Color(TEXT.r, TEXT.g, TEXT.b, 0.6)
	box.add_child(f11)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func(): _settings_panel.visible = false)
	box.add_child(close)

## The button shows the language it will switch TO, in that language — the one
## label in the game that must never be translated, because it is the thing a
## player who cannot read the current language is looking for.
func _language_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = "Language"
	l.custom_minimum_size = Vector2(96, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.text = I18n.locale_name(I18n.current_locale())
	b.pressed.connect(func() -> void:
		I18n.set_locale(I18n.next_locale())
		b.text = I18n.locale_name(I18n.current_locale())
		_retranslate())
	row.add_child(b)
	_settings_widgets.append(func() -> void:
		b.text = I18n.locale_name(I18n.current_locale()))
	return row

## Godot retranslates a Control's own `text` when the locale changes, but the map
## cards are rebuilt from data and the settings toggles read their state through
## callbacks, so the panel refreshes itself.
func _retranslate() -> void:
	for refresh in _settings_widgets:
		refresh.call()
	# Set the ENGLISH source text, not tr() of it. Godot auto-translates a
	# Control's own text on every locale change — but only while that text is
	# still the source string. Writing the translated string back in baked
	# Vietnamese into the cards, after which switching to English left the map
	# names in Vietnamese while every other button changed: half the menu in each
	# language, which is exactly the "settings buttons are broken" report.
	for i in _map_cards.size():
		_map_cards[i].text = MapThemes.name_of(i).split(" ")[-1]

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.modulate = Color(SALMON.r, SALMON.g, SALMON.b, 0.95)
	return l

## Label + a button that reads its own state. The getter is re-read after every
## press instead of tracking a bool here, because F11 and the OS can both change
## fullscreen behind this panel's back.
func _toggle_row(label_text: String, getter: Callable, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(96, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = "On" if bool(getter.call()) else "Off"
	b.pressed.connect(func() -> void:
		setter.call(not bool(getter.call()))
		b.text = "On" if bool(getter.call()) else "Off")
	row.add_child(b)
	_settings_widgets.append(func() -> void:
		b.text = "On" if bool(getter.call()) else "Off")
	return row

## < 1280 x 720 > — a stepper rather than a dropdown so the popup never has to be
## themed to match a UI that is otherwise entirely hand-built. ASCII arrows on
## purpose: the pixel font has no U+25C0/U+25B6 and drew them as tofu boxes.
func _size_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = "Window"
	l.custom_minimum_size = Vector2(96, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)

	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var refresh := func() -> void:
		var i: int = DisplaySettings.size_index()
		var s: Vector2i = DisplaySettings.SIZES[i] if i >= 0 else DisplayServer.window_get_size()
		value.text = "%d x %d" % [s.x, s.y]

	var step := func(dir: int) -> void:
		var sizes: Array[Vector2i] = DisplaySettings.SIZES
		var i: int = DisplaySettings.size_index()
		if i < 0:
			# Currently a hand-dragged size: step to the nearest listed one.
			i = 0
			var w: int = DisplayServer.window_get_size().x
			for k in sizes.size():
				if sizes[k].x <= w:
					i = k
		var next: int = clampi(i + dir, 0, sizes.size() - 1)
		# Never offer a window taller than the screen it has to fit on.
		var usable: Vector2i = DisplayServer.screen_get_usable_rect(
			DisplayServer.window_get_current_screen()).size
		while next > 0 and (sizes[next].x > usable.x or sizes[next].y > usable.y):
			next -= 1
		DisplaySettings.set_window_size(sizes[next])
		refresh.call()

	var left := Button.new()
	left.text = "<"
	left.custom_minimum_size = Vector2(38, 36)
	left.pressed.connect(func() -> void: step.call(-1))
	row.add_child(left)
	row.add_child(value)
	var right := Button.new()
	right.text = ">"
	right.custom_minimum_size = Vector2(38, 36)
	right.pressed.connect(func() -> void: step.call(1))
	row.add_child(right)

	refresh.call()
	_settings_widgets.append(refresh)
	return row

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

## The panel reads CREDITS.md straight out of the pack rather than keeping a
## second copy of the same list in code — two copies of an attribution list is
## how one of them ends up wrong.
func _on_credits() -> void:
	if _credits_panel != null and is_instance_valid(_credits_panel):
		_credits_panel.visible = not _credits_panel.visible
		return
	var size := Vector2(620, 470)
	_credits_panel = PanelContainer.new()
	_credits_panel.custom_minimum_size = size
	_credits_panel.size = size
	var ui: Control = _settings_panel.get_parent()
	ui.add_child(_credits_panel)
	var place := func() -> void:
		var vp: Vector2 = _credits_panel.get_viewport_rect().size
		_credits_panel.position = (vp - _credits_panel.size) * 0.5
	_credits_panel.resized.connect(place)
	get_viewport().size_changed.connect(place)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_credits_panel.add_child(box)
	var head := Label.new()
	head.text = "Credits"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 22)
	box.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 12)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = _credits_text()
	scroll.add_child(text)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(func() -> void: _credits_panel.visible = false)
	box.add_child(close)
	CuteButton.apply_all(_credits_panel)
	place.call()

## Markdown stripped down to something a Label can show: the tables in
## CREDITS.md are for reading on GitHub, and pipes and hashes on screen just look
## like a file someone forgot to format.
func _credits_text() -> String:
	var f := FileAccess.open("res://CREDITS.md", FileAccess.READ)
	if f == null:
		return "See CREDITS.md in the game folder."
	var out: PackedStringArray = []
	for raw in f.get_as_text().split("
"):
		var line: String = raw.strip_edges()
		f = f  # keep the handle alive for the whole loop
		if line.begins_with("|---") or line.is_empty():
			continue
		if line.begins_with("#"):
			out.append("")
			out.append(line.lstrip("# ").to_upper())
			continue
		if line.begins_with("|"):
			var cells: PackedStringArray = []
			for c in line.split("|"):
				var t: String = c.strip_edges()
				if t.is_empty():
					continue
				# "[218460](https://…)" -> "218460"
				if t.begins_with("["):
					t = t.substr(1, maxi(t.find("]") - 1, 0))
				cells.append(t)
			out.append("  " + " · ".join(cells))
			continue
		out.append(line.replace("**", ""))
	return "
".join(out)

func _on_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible
	if _settings_panel.visible:
		for refresh in _settings_widgets:
			refresh.call()

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
