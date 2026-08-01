extends CanvasLayer

## F3: a small readout of what the renderer is actually doing.
##
## This exists because the web build is the one that struggles and it is the one
## build we cannot profile from here — desktop GL runs the same scene an order of
## magnitude faster, so "it's fine on my machine" proves nothing about a browser.
## With this, a player on the slow device can read the real numbers off the
## screen and say which of them is bad.
##
## DRAW CALLS is the number to watch on the gl_compatibility target: it is what
## costs, long before triangle count does.

const KEY := KEY_F3

var _label: Label
var _accum := 0.0
var _frames := 0
var _fps := 0.0

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	panel.modulate = Color(1, 1, 1, 0.88)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(_label)
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY:
		visible = not visible
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	# Average over ~half a second; a per-frame number is unreadable noise.
	_accum += delta
	_frames += 1
	if _accum >= 0.5:
		_fps = float(_frames) / _accum
		_accum = 0.0
		_frames = 0
	_label.text = "%.0f fps   %.1f ms\ndraw %d   objects %d\ntris %d\n%s" % [
		_fps, 1000.0 / maxf(_fps, 0.001),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"LITE profile" if QualityManager.lite else "FULL profile"]
