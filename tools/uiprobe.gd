extends Node
func _ready() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	for _f in range(25):
		await get_tree().process_frame
	var win := get_window()
	print("WINDOW size=%s  content_scale_size=%s  factor=%.3f  stretch=%d"
		% [win.size, win.content_scale_size, win.content_scale_factor, win.content_scale_mode])
	print("VIEWPORT visible_rect=%s" % get_viewport().get_visible_rect().size)
	var ui := game.find_child("MaterialPicker", true, false)
	var n := 0
	for c in ui.find_children("*", "SubViewport", true, false):
		var sv: SubViewport = c
		var cont: Control = sv.get_parent()
		print("ICON subviewport=%s  container=%s  msaa=%d  scale3d=%.2f"
			% [sv.size, cont.size, sv.msaa_3d, sv.scaling_3d_scale])
		n += 1
		if n >= 2:
			break
	get_tree().quit()
