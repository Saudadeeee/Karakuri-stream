extends Control

## Left-edge vertical strip of icon-only buttons. Each icon is a small 3D block
## rendered live in its own tiny SubViewport (slowly spinning). Gear/Bell keep
## real meshes so their icon instances the actual scene; Wood/Water are meshless
## in-world (they only exist as merged occupancy isosurfaces), so their icons
## use a stand-in rounded box carrying the same wood/water shader material.

const WOOD_SHADER: Shader = preload("res://shaders/wood.gdshader")
const WATER_SHADER: Shader = preload("res://shaders/water.gdshader")

const COLUMNS: int = 2
const ICON_SIZE: int = 48
const ICON_GAP: int = 6
const REVEAL_ZONE: float = 170.0  # px from left edge where UI is fully shown
const FADE_MIN_ALPHA: float = 0.18
const SPIN_SPEED: float = 0.9

## One-line onboarding hints — hovering an icon tells you what the block DOES
## (several blocks have hidden pairings a new player would never guess).
const HINTS: Dictionary = {
	BlockData.Type.WOOD: "Building block — click again for Wood/Dirt/Moss/Stone",
	BlockData.Type.WATER: "Still pond — powers any gear touching it",
	BlockData.Type.SOURCE: "Spout — pours a stream straight down",
	BlockData.Type.PIPE: "Self-connecting pipe — click again for closed/open",
	BlockData.Type.GEAR: "Spins when touching water — chain them to transfer power",
	BlockData.Type.BELL: "Rings when a stream hits it or a gear strikes it",
	BlockData.Type.JELLY: "Bouncy jelly — boings when water lands on it",
	BlockData.Type.SHISHI: "Fills with water, then TIPS: pours onward + knock!",
	BlockData.Type.DRUM: "Drum — beaten by streams or a gear next to it",
	BlockData.Type.CHIME: "Each colour is a note — line them up = a melody",
	BlockData.Type.MUSIC_BOX: "Put beside a SPINNING gear → plays a tune",
	BlockData.Type.SCOOP: "Beside a POND + spinning gear → ladles a new stream",
	BlockData.Type.STONE_LANTERN: "Glowing lantern — prettiest on the Night map",
	BlockData.Type.PINWHEEL: "Pinwheel — spins when a stream hits it",
	BlockData.Type.GATE: "Sluice gate — CLICK it in the world to open/close the flow",
}

## Only blocks with a gameplay mechanic. STONE_LANTERN and PINWHEEL are pure
## decoration and deliberately not offered — their factory/variants/save
## support still exists, re-adding is one line here.
const ENTRIES: Array = [
	BlockData.Type.WOOD,
	BlockData.Type.WATER,
	BlockData.Type.SOURCE,
	BlockData.Type.PIPE,
	BlockData.Type.GEAR,
	BlockData.Type.BELL,
	BlockData.Type.JELLY,
	BlockData.Type.SHISHI,
	BlockData.Type.DRUM,
	BlockData.Type.CHIME,
	BlockData.Type.MUSIC_BOX,
	BlockData.Type.SCOOP,
	BlockData.Type.GATE,
]

@export var placement_controller_path: NodePath

@onready var placement_controller: Node = get_node(placement_controller_path)

var _buttons: Dictionary = {}      # BlockData.Type -> Button
var _pivots: Array[Node3D] = []    # spinning block roots, animated in _process
var _pivot_by_type: Dictionary = {} # BlockData.Type -> pivot (to restyle for variant)
var _viewport_by_type: Dictionary = {} # BlockData.Type -> SubViewport
var _selected_type: int = BlockData.Type.WOOD
var _hovered_type: int = -1
var _faded: bool = false
const COG_BEZEL := preload("res://scripts/ui/cog_bezel.gd")
var _bezel_by_type: Dictionary = {}
var _hint_panel: PanelContainer
var _hint_label: Label

func _ready() -> void:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", ICON_GAP)
	grid.add_theme_constant_override("v_separation", ICON_GAP)
	grid.position = Vector2(16, 16)
	add_child(grid)

	for type in ENTRIES:
		var button := _build_icon_button(type)
		grid.add_child(button)
		_buttons[type] = button
		button.pressed.connect(placement_controller.select_material.bind(type))

	placement_controller.material_changed.connect(_on_material_changed)
	_on_material_changed(BlockData.Type.WOOD)

	# Hover hint card (name + what the block does), themed like everything else.
	_hint_panel = PanelContainer.new()
	_hint_panel.visible = false
	_hint_panel.custom_minimum_size = Vector2(230, 0)
	add_child(_hint_panel)
	var vb := VBoxContainer.new()
	_hint_panel.add_child(vb)
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(_hint_label)

func _build_icon_button(type: BlockData.Type) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	button.toggle_mode = true

	# Wooden cog bezel behind the icon (2D draw, no 3D cost).
	var bezel := COG_BEZEL.new()
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(bezel)
	_bezel_by_type[type] = bezel

	var sub_container := SubViewportContainer.new()
	sub_container.stretch = true
	sub_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(sub_container)

	# Perf: 7 live 3D viewports re-rendering every frame is the single biggest
	# constant GPU cost (each is its own world + 2 lights) — brutal on the
	# gl_compatibility web/mobile targets. Icons render ONCE and freeze; only
	# the selected / hovered icon spins (see _refresh_viewport_modes), so the
	# animation stays exactly where the player is looking.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_container.add_child(viewport)
	_viewport_by_type[type] = viewport
	button.mouse_entered.connect(_on_icon_hover.bind(type, true))
	button.mouse_exited.connect(_on_icon_hover.bind(type, false))

	var pivot := Node3D.new()
	viewport.add_child(pivot)

	pivot.add_child(_build_icon_visual(type, 0))
	_pivots.append(pivot)
	_pivot_by_type[type] = pivot

	var camera := Camera3D.new()
	camera.position = Vector3(1.6, 1.4, 2.2)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	camera.fov = 40.0
	viewport.add_child(camera)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-30.0), 0.0)
	key.light_energy = 1.1
	viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(20.0), deg_to_rad(150.0), 0.0)
	fill.light_energy = 0.5
	viewport.add_child(fill)

	return button

## Gear/Bell have real meshes → show the actual scene. Wood/Water are meshless
## in-world, so the icon is a stand-in rounded box wearing the same shader.
func _build_icon_visual(type: BlockData.Type, variant: int) -> Node3D:
	# Everything except the meshless merged Wood/Water shows its real model.
	if type != BlockData.Type.WOOD and type != BlockData.Type.WATER:
		var m: Node3D = BlockFactory.instantiate(type)
		if m.has_method("apply_variant"):
			m.apply_variant(BlockVariants.get_variant(type, variant))
		return m
	var vcol: Color = BlockVariants.color_of(type, variant)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.9, 0.9)
	# Subdivide so the shaders (which shade per-vertex-interpolated world pos)
	# have geometry to work with on the icon-scale cube.
	box.subdivide_width = 3
	box.subdivide_height = 3
	box.subdivide_depth = 3
	mi.mesh = box

	var mat := ShaderMaterial.new()
	if type == BlockData.Type.WATER:
		mat.shader = WATER_SHADER
		mat.set_shader_parameter("water_color", Color(vcol.r, vcol.g, vcol.b, 0.97))
		mat.set_shader_parameter("deep_color", Color(vcol.darkened(0.2).r, vcol.darkened(0.2).g, vcol.darkened(0.2).b, 0.99))
	else:
		mat.shader = WOOD_SHADER
		mat.set_shader_parameter("base_color", vcol)
		mat.set_shader_parameter("grain_color", vcol.darkened(0.28))
		mat.set_shader_parameter("grain_scale", 4.0)
		mat.set_shader_parameter("grain_strength", 0.15)
		mat.set_shader_parameter("rim_color", vcol.lightened(0.35))
		mat.set_shader_parameter("rim_power", 4.0)
		mat.set_shader_parameter("rim_strength", 0.26)
	mi.material_override = mat
	return mi

func _process(delta: float) -> void:
	# Spin only the pivots whose viewport is live (selected/hovered) — the
	# frozen ones would be wasted math AND look torn when they wake.
	for type in _viewport_by_type:
		if _viewport_by_type[type].render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			var pivot: Node3D = _pivot_by_type[type]
			if is_instance_valid(pivot):
				pivot.rotate_y(SPIN_SPEED * delta)
			var bz = _bezel_by_type.get(type)
			if bz != null:
				bz.rot += delta * 0.7
				bz.queue_redraw()

	var mouse_x: float = get_viewport().get_mouse_position().x
	var target_alpha: float = 1.0 if mouse_x <= REVEAL_ZONE else FADE_MIN_ALPHA
	modulate.a = lerpf(modulate.a, target_alpha, clampf(delta * 6.0, 0.0, 1.0))
	# When the strip fades out, freeze even the selected icon's viewport.
	var faded: bool = target_alpha < 1.0
	if faded != _faded:
		_faded = faded
		_refresh_viewport_modes()

func _on_icon_hover(type: int, entered: bool) -> void:
	_hovered_type = type if entered else -1
	_refresh_viewport_modes()
	# Hint card floats next to the hovered icon.
	if entered and _hint_panel != null:
		var vname: String = str(BlockVariants.get_variant(type, 0).get("name", ""))
		_hint_label.text = "%s\n%s" % [vname, HINTS.get(type, "")]
		var btn: Button = _buttons[type]
		# Clear of the whole grid, not the hovered button's column.
		_hint_panel.position = Vector2(16.0 + float(COLUMNS * (ICON_SIZE + ICON_GAP)) + 14.0, btn.global_position.y)
		_hint_panel.visible = true
	elif _hint_panel != null:
		_hint_panel.visible = false

## One live (UPDATE_ALWAYS) viewport at a time — selected, or hovered — the
## rest frozen on their last frame (UPDATE_ONCE keeps the image).
func _refresh_viewport_modes() -> void:
	for type in _viewport_by_type:
		var live: bool = not _faded and (type == _hovered_type or (type == _selected_type and _hovered_type == -1))
		var vp: SubViewport = _viewport_by_type[type]
		var mode := SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE
		if vp.render_target_update_mode != mode:
			vp.render_target_update_mode = mode

func _on_material_changed(type: BlockData.Type, variant: int = 0) -> void:
	for button_type in _buttons:
		_buttons[button_type].set_pressed_no_signal(button_type == type)
	_selected_type = type
	for bt in _bezel_by_type:
		var b = _bezel_by_type[bt]
		if b.selected != (bt == type):
			b.selected = (bt == type)
			b.queue_redraw()
	_refresh_viewport_modes()
	# Rebuild the selected type's icon so it SHOWS the current variant
	# (open pipe, dirt block, pink water, mill wheel, …).
	var pivot: Node3D = _pivot_by_type.get(type)
	if pivot != null:
		for c in pivot.get_children():
			c.queue_free()
		pivot.add_child(_build_icon_visual(type, variant))
