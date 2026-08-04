class_name UiPlace
extends RefCounted

## Puts a panel on screen and keeps it there when the window resizes.
##
## Every panel in this game hangs off a CanvasLayer, which has no rect of its
## own — so anchors resolve against nothing and an anchor-relative offset reads
## as a raw position the moment anything re-lays the panel out. That trap cost a
## controls card that vanished entirely off the bottom of the screen and a
## settings panel that pushed its own Close button past its edge, and the same
## three lines had been copy-pasted into six places by the time it was fixed
## twice. Measure the viewport, place from the panel's OWN size, and re-run on
## every resize.
##
## Call after the panel has been laid out at least once — `resized` fires before
## a container has its final size on the frame it is built.

## Dead centre.
static func centre(panel: Control) -> void:
	_apply(panel, func(vp: Vector2, size: Vector2) -> Vector2:
		return (vp - size) * 0.5)

## Centred horizontally, `margin` above the bottom edge.
static func bottom(panel: Control, margin: float) -> void:
	_apply(panel, func(vp: Vector2, size: Vector2) -> Vector2:
		return Vector2((vp.x - size.x) * 0.5, vp.y - size.y - margin))

static func _apply(panel: Control, at: Callable) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var place := func() -> void:
		if not is_instance_valid(panel) or not panel.is_inside_tree():
			return
		panel.position = at.call(panel.get_viewport_rect().size, panel.size)
	if not panel.resized.is_connected(place):
		panel.resized.connect(place)
	if panel.is_inside_tree():
		var vp := panel.get_viewport()
		if not vp.size_changed.is_connected(place):
			vp.size_changed.connect(place)
	place.call()
