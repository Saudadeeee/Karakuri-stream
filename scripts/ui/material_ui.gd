extends Control

## Left-edge vertical strip of icon-only buttons. Each icon is a small 3D block
## rendered live in its own tiny SubViewport (slowly spinning). Gear/Bell keep
## real meshes so their icon instances the actual scene; Wood/Water are meshless
## in-world (they only exist as merged occupancy isosurfaces), so their icons
## use a stand-in rounded box carrying the same wood/water shader material.

const WOOD_SHADER: Shader = preload("res://shaders/wood.gdshader")
const WATER_SHADER: Shader = preload("res://shaders/water.gdshader")

const ICON_SIZE: int = 72
const ICON_GAP: int = 14
const REVEAL_ZONE: float = 170.0  # px from left edge where UI is fully shown
const FADE_MIN_ALPHA: float = 0.18
const SPIN_SPEED: float = 0.9

const ENTRIES: Array = [
	BlockData.Type.WOOD,
	BlockData.Type.WATER,
	BlockData.Type.SOURCE,
	BlockData.Type.PIPE,
	BlockData.Type.GEAR,
	BlockData.Type.BELL,
	BlockData.Type.JELLY,
]

@export var placement_controller_path: NodePath

@onready var placement_controller: Node = get_node(placement_controller_path)

var _buttons: Dictionary = {}      # BlockData.Type -> Button
var _pivots: Array[Node3D] = []    # spinning block roots, animated in _process
var _pivot_by_type: Dictionary = {} # BlockData.Type -> pivot (to restyle for variant)

func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", ICON_GAP)
	vbox.position = Vector2(16, 16)
	add_child(vbox)

	for type in ENTRIES:
		var button := _build_icon_button(type)
		vbox.add_child(button)
		_buttons[type] = button
		button.pressed.connect(placement_controller.select_material.bind(type))

	placement_controller.material_changed.connect(_on_material_changed)
	_on_material_changed(BlockData.Type.WOOD)

func _build_icon_button(type: BlockData.Type) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	button.toggle_mode = true

	var sub_container := SubViewportContainer.new()
	sub_container.stretch = true
	sub_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(sub_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_container.add_child(viewport)

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
	for pivot in _pivots:
		if is_instance_valid(pivot):
			pivot.rotate_y(SPIN_SPEED * delta)

	var mouse_x: float = get_viewport().get_mouse_position().x
	var target_alpha: float = 1.0 if mouse_x <= REVEAL_ZONE else FADE_MIN_ALPHA
	modulate.a = lerpf(modulate.a, target_alpha, clampf(delta * 6.0, 0.0, 1.0))

func _on_material_changed(type: BlockData.Type, variant: int = 0) -> void:
	for button_type in _buttons:
		_buttons[button_type].set_pressed_no_signal(button_type == type)
	# Rebuild the selected type's icon so it SHOWS the current variant
	# (open pipe, dirt block, pink water, mill wheel, …).
	var pivot: Node3D = _pivot_by_type.get(type)
	if pivot != null:
		for c in pivot.get_children():
			c.queue_free()
		pivot.add_child(_build_icon_visual(type, variant))
