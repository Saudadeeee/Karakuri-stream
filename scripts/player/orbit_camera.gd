extends Node3D

## Orbit camera with FEEL: rotation carries a little inertia (keeps gliding
## after you let go, eased out), zoom lerps smoothly instead of stepping, and
## two-finger pinch zooms on touch screens. The soft glide is half of what
## makes fiddling with the diorama relaxing.

@export var rotate_speed: float = 0.01
@export var zoom_speed: float = 1.4
@export var min_zoom: float = 4.0
@export var max_zoom: float = 30.0
@export var min_pitch: float = deg_to_rad(15.0)
@export var max_pitch: float = deg_to_rad(80.0)

const INERTIA_DAMP: float = 6.0     # how fast the glide dies (higher = shorter)
const ZOOM_LERP: float = 9.0        # zoom smoothing speed

@onready var spring_arm: SpringArm3D = $SpringArm3D

var _dragging: bool = false
## A little lower than a plan view: 38° keeps the silhouettes of the blocks and
## the mountains behind them, where 45° flattens everything into a map.
var _pitch: float = deg_to_rad(38.0)
var _yaw_vel: float = 0.0           # rad/s carried after release
var _pitch_vel: float = 0.0
## Only a fallback — `_ready` takes the real starting distance from the scene's
## SpringArm3D, which is where it must be changed (`scenes/main.tscn`). Editing
## this constant alone does nothing, which cost a render to work out.
## Close enough that the opening shot is the GARDEN, not the lawn around it. At
## 15 the whole island fitted the frame and the starter machine was a few specks
## on one edge — a bad first second for something meant to look inviting. The
## player can still pull back to `max_zoom`.
var _target_zoom: float = 7.0
var _touches: Dictionary = {}       # index -> position (pinch tracking)
var _pinch_dist: float = -1.0

func _ready() -> void:
	_target_zoom = clampf(spring_arm.spring_length, min_zoom, max_zoom)
	spring_arm.spring_length = _target_zoom
	spring_arm.rotation.x = -_pitch

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			if mb.pressed:
				_yaw_vel = 0.0
				_pitch_vel = 0.0
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom - zoom_speed, min_zoom, max_zoom)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom + zoom_speed, min_zoom, max_zoom)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_apply_orbit(mm.relative)
		# Feed the inertia with the latest drag speed (rad per second-ish).
		_yaw_vel = -mm.relative.x * rotate_speed * 60.0
		_pitch_vel = mm.relative.y * rotate_speed * 60.0
	# --- touch: one finger orbits, two fingers pinch-zoom ---
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_dist = -1.0
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() == 2:
			var pts: Array = _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 0.0:
				_target_zoom = clampf(_target_zoom - (d - _pinch_dist) * 0.03, min_zoom, max_zoom)
			_pinch_dist = d
		elif _touches.size() == 1:
			_apply_orbit(sd.relative)
			_yaw_vel = -sd.relative.x * rotate_speed * 60.0
			_pitch_vel = sd.relative.y * rotate_speed * 60.0

func _apply_orbit(relative: Vector2) -> void:
	rotate_y(-relative.x * rotate_speed)
	_pitch = clampf(_pitch + relative.y * rotate_speed, min_pitch, max_pitch)
	spring_arm.rotation.x = -_pitch

func _process(delta: float) -> void:
	# Glide: keep turning with decaying velocity once the drag is released.
	if not _dragging and (absf(_yaw_vel) > 0.001 or absf(_pitch_vel) > 0.001):
		rotate_y(_yaw_vel * delta)
		_pitch = clampf(_pitch + _pitch_vel * delta, min_pitch, max_pitch)
		spring_arm.rotation.x = -_pitch
		var k: float = exp(-INERTIA_DAMP * delta)
		_yaw_vel *= k
		_pitch_vel *= k
	# Smooth zoom toward the target.
	spring_arm.spring_length = lerpf(spring_arm.spring_length, _target_zoom,
		clampf(ZOOM_LERP * delta, 0.0, 1.0))
