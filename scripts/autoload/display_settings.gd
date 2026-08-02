extends Node

## Window mode, resolution and vsync — the three things a desktop player expects
## to find and this game had none of. Kept in settings.cfg beside the audio
## volumes (same file, its own section) and applied before the first frame the
## player sees, so a chosen fullscreen never flashes a small window first.
##
## Web is deliberately excluded: a page cannot resize its own window, and browser
## fullscreen needs a user gesture the settings panel already is — so the panel
## offers only the fullscreen toggle there (see main_menu.gd).

const SETTINGS_PATH: String = "user://settings.cfg"

## Windowed sizes offered in the settings panel. 16:9 only — the camera framing
## and the UI margins are tuned for it, and every current desktop can do 720p.
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _windowed_size: Vector2i = Vector2i(1280, 720)
var _resize_debounce: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	# A player dragging the window edge is choosing a size; keep it. size_changed
	# fires every pixel of that drag, so the write waits until they let go.
	_resize_debounce = Timer.new()
	_resize_debounce.wait_time = 0.6
	_resize_debounce.one_shot = true
	_resize_debounce.timeout.connect(remember_current_size)
	add_child(_resize_debounce)
	get_tree().root.size_changed.connect(func() -> void: _resize_debounce.start())

func _unhandled_input(event: InputEvent) -> void:
	# F11 everywhere, menu included. The convention is old enough that players
	# try it before they look for a setting.
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F11:
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ queries
func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func is_vsync() -> bool:
	return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

## Which entry of SIZES the window currently matches, or -1 for a size the
## player set by dragging the window edge (which is theirs to keep).
func size_index() -> int:
	return SIZES.find(_windowed_size)

# ------------------------------------------------------------------ setters
func set_fullscreen(on: bool) -> void:
	if on == is_fullscreen():
		return
	if on:
		# Remember the windowed size first — leaving fullscreen has to put the
		# window back where it was, not at whatever the desktop resolution is.
		_remember_windowed_size()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_window_size(_windowed_size)
	_save()

func set_window_size(size: Vector2i) -> void:
	_windowed_size = size
	if is_fullscreen():
		# Store the choice; it takes effect when they come back out.
		_save()
		return
	_apply_window_size(size)
	_save()

func set_vsync(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
	_save()

## Called when the player drags the window edge — keep their size, don't fight it.
func remember_current_size() -> void:
	if not is_fullscreen():
		_remember_windowed_size()
		_save()

# ------------------------------------------------------------------ internals
func _remember_windowed_size() -> void:
	var s := DisplayServer.window_get_size()
	if s.x > 0 and s.y > 0:
		_windowed_size = s

func _apply_window_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	# Re-centre: a window resized from its top-left corner can end up with its
	# title bar off the top of the screen, which is unrecoverable with a mouse.
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var w: int = int(cfg.get_value("display", "window_width", _windowed_size.x))
	var h: int = int(cfg.get_value("display", "window_height", _windowed_size.y))
	if w > 0 and h > 0:
		_windowed_size = Vector2i(w, h)

	set_vsync(bool(cfg.get_value("display", "vsync", true)))
	if OS.has_feature("web"):
		return
	# The dev harnesses (tools/shoot.gd, tools/perf.gd) run with an explicit
	# --resolution, and their numbers only mean something at that size — a saved
	# window size resizing them under their feet turned a 1600x900 perf run into
	# a secretly-1280x720 one. Engine flags are stripped from get_cmdline_args(),
	# so the flag itself cannot be tested for; what CAN be tested is the result.
	# A boot window that already differs from the project default means something
	# on the command line asked for it, and that beats a stored preference.
	var project_default := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)))
	if DisplayServer.window_get_size() != project_default:
		return
	if bool(cfg.get_value("display", "fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		_apply_window_size(_windowed_size)

func _save() -> void:
	var cfg := ConfigFile.new()
	# Load first so the audio section written by the menus survives.
	cfg.load(SETTINGS_PATH)
	cfg.set_value("display", "fullscreen", is_fullscreen())
	cfg.set_value("display", "window_width", _windowed_size.x)
	cfg.set_value("display", "window_height", _windowed_size.y)
	cfg.set_value("display", "vsync", is_vsync())
	cfg.save(SETTINGS_PATH)
