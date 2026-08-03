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
const REVEAL_ZONE: float = 240.0  # px from left edge where UI is fully shown
## The strip used to fade to 0.18, which on a wide screen meant the palette was
## effectively invisible for most of a session — the player could not see what
## they had selected, and new players never learned the vocabulary at all. It
## still recedes (this is a calm game, not a toolbar), but it stays readable.
const FADE_MIN_ALPHA: float = 0.45
## How long the strip stays fully lit after a keyboard selection. Picking a block
## with 1-0 used to change something the player could barely see.
const KEY_REVEAL_TIME: float = 2.0
const SPIN_SPEED: float = 0.9
## Where icon instances pretend to live: far below any island so a shape-from-
## neighbours block resolves to its lone form.
const ICON_CELL := Vector3i(0, -4096, 0)

## Contents, order and hover text all come from BlockCatalog — add a block
## there and it appears here.
static var ENTRIES: Array = BlockCatalog.palette_types()

@export var placement_controller_path: NodePath

@onready var placement_controller: Node = get_node(placement_controller_path)

var _buttons: Dictionary = {}      # BlockData.Type -> Button
var _pivots: Array[Node3D] = []    # spinning block roots, animated in _process
var _pivot_by_type: Dictionary = {} # BlockData.Type -> pivot (to restyle for variant)
var _viewport_by_type: Dictionary = {} # BlockData.Type -> SubViewport
var _selected_type: int = BlockData.Type.WOOD
var _hovered_type: int = -1
var _faded: bool = false
## Seconds of full opacity still owed to a keyboard selection.
var _reveal_left: float = 0.0
const COG_BEZEL := preload("res://scripts/ui/cog_bezel.gd")
const TOUCH_CONTROLS := preload("res://scripts/ui/touch_controls.gd")
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

	# Last, and deferred: the starting selection wants to show its hint card on a
	# touch device, and that needs both the card to exist and the buttons to have
	# been laid out so the card knows where to sit.
	_on_material_changed.call_deferred(BlockData.Type.WOOD)

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

	# The shortcut, printed on the icon. The keys existed from the start and were
	# listed once on the first-run card — which is exactly the moment a new player
	# is least able to memorise eleven of them. On the icon it needs no memory.
	var shortcut: int = int(BlockCatalog.entry(type).get("key", KEY_NONE))
	if shortcut != KEY_NONE:
		var tag := Label.new()
		tag.text = _key_glyph(shortcut)
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color(0.20, 0.17, 0.14, 1.0))
		# Cream halo, because the icons behind it range from pale water to dark
		# stone and a single colour would vanish on one of them.
		tag.add_theme_color_override("font_outline_color", Color(1.0, 0.97, 0.91, 1.0))
		# 2, not 4: this is a pixel font at 12 px, and a fat outline grows inward
		# far enough to eat the glyph it is supposed to separate.
		tag.add_theme_constant_override("outline_size", 2)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Fill the button and align inside it. Anchoring the label's own corner
		# and nudging it put "Minus" outside the icon, over the island.
		tag.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		# Inset, or the glyph sits exactly on the rect edge and its outline is
		# sheared off — the digits read as half-digits.
		tag.offset_right = -6.0
		tag.offset_bottom = -4.0
		button.add_child(tag)

	var pivot := Node3D.new()
	viewport.add_child(pivot)

	_add_icon_visual(pivot, type, 0)
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
		# Blocks that shape themselves from their neighbours (pipe) build nothing
		# until refresh_shape() runs, which left the pipe icon an empty cog. Point
		# them at a cell no build can reach so they resolve to their lone form —
		# reading the real grid at (0,0,0) would make the icon depend on whatever
		# the player happens to have built there.
		if "grid_cell" in m:
			m.grid_cell = ICON_CELL
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

## What to print on the icon. OS.get_keycode_string returns key NAMES — "Minus",
## "Equal" — which are both wrong (the player sees `-` and `=` on the keyboard)
## and too long to sit in a 48 px icon.
func _key_glyph(keycode: int) -> String:
	match keycode:
		KEY_MINUS: return "-"
		KEY_EQUAL: return "="
		_: return OS.get_keycode_string(keycode)

## refresh_shape() has to run with the node already in the tree — that is where
## the procedural blocks build their geometry.
func _add_icon_visual(pivot: Node3D, type: BlockData.Type, variant: int) -> void:
	var v: Node3D = _build_icon_visual(type, variant)
	pivot.add_child(v)
	if v.has_method("refresh_shape"):
		v.refresh_shape()

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

	if _hint_left > 0.0:
		_hint_left = maxf(_hint_left - delta, 0.0)
		if _hint_left == 0.0 and _hovered_type == -1 and _hint_panel != null:
			_hint_panel.visible = false

	var mouse_x: float = get_viewport().get_mouse_position().x
	var lit: bool = mouse_x <= REVEAL_ZONE or _reveal_left > 0.0
	_reveal_left = maxf(_reveal_left - delta, 0.0)
	var target_alpha: float = 1.0 if lit else FADE_MIN_ALPHA
	modulate.a = lerpf(modulate.a, target_alpha, clampf(delta * 6.0, 0.0, 1.0))
	# When the strip fades out, freeze even the selected icon's viewport.
	var faded: bool = target_alpha < 1.0
	if faded != _faded:
		_faded = faded
		_refresh_viewport_modes()

## Touch has no hover, so the hint card — the only place the game says what a
## block DOES — never appeared on a phone at all. Selecting one shows it for a
## few seconds instead, which is the same moment a mouse player would be reading
## it and needs no gesture of its own.
const TOUCH_HINT_TIME: float = 3.5
var _hint_left: float = 0.0

func _show_hint(type: int) -> void:
	if _hint_panel == null:
		return
	var vname: String = str(BlockVariants.get_variant(type, 0).get("name", ""))
	_hint_label.text = "%s
%s" % [tr(vname), tr(BlockCatalog.hint(type))]
	var btn: Button = _buttons.get(type)
	if btn == null:
		return
	_hint_panel.position = Vector2(16.0 + float(COLUMNS * (ICON_SIZE + ICON_GAP)) + 14.0,
		btn.global_position.y)
	_hint_panel.visible = true

func _on_icon_hover(type: int, entered: bool) -> void:
	_hovered_type = type if entered else -1
	_refresh_viewport_modes()
	# Hint card floats next to the hovered icon.
	if entered and _hint_panel != null:
		var vname: String = str(BlockVariants.get_variant(type, 0).get("name", ""))
		_hint_label.text = "%s\n%s" % [vname, BlockCatalog.hint(type)]
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
	# Show the strip for a moment on every selection. Clicking an icon already
	# has the pointer in the reveal zone; this is for the keyboard, where the
	# only feedback used to be a change inside a 45%-faded panel.
	_reveal_left = KEY_REVEAL_TIME
	if TOUCH_CONTROLS.should_show():
		_show_hint(type)
		_hint_left = TOUCH_HINT_TIME
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
		_add_icon_visual(pivot, type, variant)
