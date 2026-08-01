class_name CuteButton
extends RefCounted

## Makes a plain Button feel like a soft rubber thing you can poke.
##
## Four beats, and they only read as "cute" together:
##   hover   — pops up a touch and tilts, with a quiet high knock
##   press   — SQUASHES wide and short and sinks, like a stamp going down
##   release — overshoots back past its resting size and settles (TRANS_BACK);
##             springing straight to 1.0 feels dead, the overshoot is the toy
##   leave   — unwinds whatever state it was in, even mid-press
##
## Everything is driven through `scale` and `rotation`, never `position` or
## `size`, because these buttons live inside VBoxContainers and a container
## overwrites position/size every layout pass — animating those fights the
## container and jitters. Scale and rotation are pure visual transforms the
## container does not touch.
##
## `pivot_offset` has to track the button's size or it scales from the top-left
## corner and slides sideways as it grows, so it is re-centred on every resize.

const HOVER_SCALE := 1.055
const HOVER_TILT := 0.017
const PRESS_SQUASH := Vector2(1.09, 0.86)
const POP_TIME := 0.13
const SETTLE_TIME := 0.34

## Wire one button. Safe to call twice — the marker meta stops double-tweening,
## which would otherwise fight itself and leave buttons stuck at odd sizes.
##
## `quiet_hover` is for tight rows of small icons: sweeping the mouse across the
## hotbar would otherwise fire a dozen hover knocks in a second, which stops
## being charming immediately. Those still click on press.
static func wire(b: Button, quiet_hover: bool = false) -> void:
	if b.has_meta("cute"):
		return
	b.set_meta("cute", true)
	b.set_meta("cute_quiet", quiet_hover)
	_recenter(b)
	b.resized.connect(_recenter.bind(b))
	b.mouse_entered.connect(_on_hover.bind(b, true))
	b.mouse_exited.connect(_on_hover.bind(b, false))
	b.button_down.connect(_on_down.bind(b))
	b.button_up.connect(_on_up.bind(b))

## Wire every Button under `root`. Menus build their UI in code, so this is the
## one call each of them needs rather than remembering it per button.
static func apply_all(root: Node) -> void:
	if root is Button:
		wire(root)
	for c in root.get_children():
		apply_all(c)

static func _recenter(b: Button) -> void:
	b.pivot_offset = b.size * 0.5

static func _tween(b: Button) -> Tween:
	# One tween per button: starting a second while the first runs leaves two
	# writing to scale on the same frame and the button visibly stutters.
	# has_meta first: get_meta's "default" is only used when it is NOT null, so
	# passing null there still raised "object has no meta values with the key"
	# on the first hover of every button in the game.
	if b.has_meta("cute_tween"):
		var old: Variant = b.get_meta("cute_tween")
		if is_instance_valid(old) and (old as Tween).is_running():
			(old as Tween).kill()
	var t: Tween = b.create_tween().set_parallel(true)
	b.set_meta("cute_tween", t)
	return t

static func _on_hover(b: Button, entered: bool) -> void:
	if b.disabled:
		return
	var t := _tween(b)
	var scale: Vector2 = Vector2.ONE * (HOVER_SCALE if entered else 1.0)
	var tilt: float = HOVER_TILT if entered else 0.0
	t.tween_property(b, "scale", scale, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "rotation", tilt, POP_TIME).set_trans(Tween.TRANS_SINE)
	if entered and not bool(b.get_meta("cute_quiet", false)):
		AudioManager.play_ui_pop(true)

static func _on_down(b: Button) -> void:
	if b.disabled:
		return
	var t := _tween(b)
	t.tween_property(b, "scale", PRESS_SQUASH, 0.06).set_trans(Tween.TRANS_QUAD)
	t.tween_property(b, "rotation", 0.0, 0.06)
	AudioManager.play_ui_pop(false)

static func _on_up(b: Button) -> void:
	if b.disabled:
		return
	# Overshoot on the way back: the springiness IS the effect. Land on the hover
	# size if the pointer is still over it, otherwise all the way home.
	var resting: float = HOVER_SCALE if b.is_hovered() else 1.0
	var t := _tween(b)
	t.tween_property(b, "scale", Vector2.ONE * resting, SETTLE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "rotation", HOVER_TILT if b.is_hovered() else 0.0, SETTLE_TIME) \
		.set_trans(Tween.TRANS_SINE)
