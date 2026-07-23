extends Control

## Left-edge vertical strip of icon-only buttons. Each icon is the ACTUAL 3D
## block mesh rendered live in its own tiny SubViewport (slowly spinning), so
## there's no hand-drawn art to keep in sync — change a block's look and its
## icon updates for free. The strip fades out while the player is just
## watching their build and fades back in when the cursor nears the left edge.

const ICON_SIZE: int = 72
const ICON_GAP: int = 14
const REVEAL_ZONE: float = 170.0  # px from left edge where UI is fully shown
const FADE_MIN_ALPHA: float = 0.18
const SPIN_SPEED: float = 0.9

const ENTRIES: Array = [
	BlockData.Type.WOOD,
	BlockData.Type.WATER,
	BlockData.Type.GEAR,
	BlockData.Type.BELL,
]

@export var placement_controller_path: NodePath

@onready var placement_controller: Node = get_node(placement_controller_path)

var _buttons: Dictionary = {}   # BlockData.Type -> Button
var _pivots: Array[Node3D] = [] # spinning block roots, animated in _process

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

	var block: Node3D = BlockFactory.instantiate(type)
	pivot.add_child(block)
	_pivots.append(pivot)

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

func _process(delta: float) -> void:
	for pivot in _pivots:
		if is_instance_valid(pivot):
			pivot.rotate_y(SPIN_SPEED * delta)

	var mouse_x: float = get_viewport().get_mouse_position().x
	var target_alpha: float = 1.0 if mouse_x <= REVEAL_ZONE else FADE_MIN_ALPHA
	modulate.a = lerpf(modulate.a, target_alpha, clampf(delta * 6.0, 0.0, 1.0))

func _on_material_changed(type: BlockData.Type) -> void:
	for button_type in _buttons:
		_buttons[button_type].set_pressed_no_signal(button_type == type)
