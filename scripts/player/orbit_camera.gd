extends Node3D

@export var rotate_speed: float = 0.01
@export var zoom_speed: float = 0.5
@export var min_zoom: float = 4.0
@export var max_zoom: float = 30.0
@export var min_pitch: float = deg_to_rad(15.0)
@export var max_pitch: float = deg_to_rad(80.0)

@onready var spring_arm: SpringArm3D = $SpringArm3D

var _dragging: bool = false
var _pitch: float = deg_to_rad(45.0)

func _ready() -> void:
	spring_arm.spring_length = clampf(spring_arm.spring_length, min_zoom, max_zoom)
	spring_arm.rotation.x = -_pitch

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clampf(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clampf(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		rotate_y(-mm.relative.x * rotate_speed)
		_pitch = clampf(_pitch + mm.relative.y * rotate_speed, min_pitch, max_pitch)
		spring_arm.rotation.x = -_pitch
