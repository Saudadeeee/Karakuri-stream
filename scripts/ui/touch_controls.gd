extends Control

## The two things a touch player could not do at all.
##
## Placing works on a phone because Godot emulates a left click from a tap. There
## is no gesture that emulates a RIGHT click, and undo was bound to Ctrl+Z — so
## on the Android build you could add blocks and never take one back. The only
## way out of a mistake was the pause menu's Clear, which throws away the whole
## garden.
##
## Deliberately a MODE TOGGLE rather than a long-press: with mouse emulation on, a
## tap already fires "place" the instant the finger lands, so a long-press erase
## would have to place a block first and then undo it — visible, and wrong the
## moment the finger moves. A mode the player can see is also easier to trust:
## the button stays lit while erasing.
##
## Shown only where it is needed. On desktop, right-click and Ctrl+Z already
## exist and two floating buttons would be clutter.

const SIZE := Vector2(64, 64)
const MARGIN := 18.0
const GAP := 12.0

var _placement: Node
var _erase_button: Button

static func should_show() -> bool:
	# The editor reports a touchscreen on some laptops; the flag is what matters
	# on a real phone, and OS.has_feature("mobile") is what the export sets.
	if OS.get_environment("KARAKURI_FORCE_TOUCH") != "":
		return true
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func setup(placement: Node) -> void:
	_placement = placement

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_erase_button = _make_button("Erase", func() -> void:
		if _placement == null:
			return
		_placement.set("erase_mode", not bool(_placement.get("erase_mode")))
		_paint_erase())
	var undo_button := _make_button("Undo", func() -> void: UndoManager.undo())

	add_child(_erase_button)
	add_child(undo_button)
	_paint_erase()

	# Laid out from each button's ACTUAL size, not from SIZE: the label makes them
	# wider than their minimum, and positioning by the constant pushed the Undo
	# button off the right edge of the screen.
	var place := func() -> void:
		var vp: Vector2 = get_viewport_rect().size
		# Bottom right: the pause button owns the top right, the palette the left.
		undo_button.position = Vector2(vp.x - undo_button.size.x - MARGIN,
			vp.y - undo_button.size.y - MARGIN)
		_erase_button.position = Vector2(undo_button.position.x - _erase_button.size.x - GAP,
			vp.y - _erase_button.size.y - MARGIN)
	get_viewport().size_changed.connect(place)
	_erase_button.resized.connect(place)
	undo_button.resized.connect(place)
	CuteButton.apply_all(self)
	await get_tree().process_frame
	place.call()

func _make_button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = SIZE
	b.size = SIZE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(pressed)
	return b

## Erase mode has to be unmistakable — a player who forgets it is on will delete
## the next thing they meant to build.
func _paint_erase() -> void:
	var on: bool = _placement != null and bool(_placement.get("erase_mode"))
	_erase_button.modulate = Color(1.0, 0.55, 0.5) if on else Color.WHITE
	_erase_button.text = "Erase\nON" if on else "Erase"
