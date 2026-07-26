extends Node

## Dev-only: boot a scene with a REAL renderer, let it settle, save a PNG, quit.
## Headless uses a dummy driver and renders nothing, so this is the only way to
## actually look at the game from a script.
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 tools/shoot.tscn -- scene=... out=...
var _crop := Rect2i()

func _ready() -> void:
	var target := "res://scenes/main_menu.tscn"
	var out := "user://shot.png"
	var build := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="): target = a.substr(6)
		elif a.begins_with("out="): out = "user://" + a.substr(4)
		elif a == "build": build = true
		elif a.begins_with("crop="):
			var n: PackedStringArray = a.substr(5).split(",")
			_crop = Rect2i(int(n[0]), int(n[1]), int(n[2]), int(n[3]))
	var s: Node = load(target).instantiate()
	add_child(s)
	for _f in range(40):
		await get_tree().process_frame
	if build:
		_village(s)
		for _f in range(90):
			await get_tree().process_frame
	for _f in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if _crop != Rect2i():
		img = img.get_region(_crop)
		# Blow it up so small UI details are actually legible in the saved PNG.
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("SHOT ", ProjectSettings.globalize_path(out))
	get_tree().quit()

## A small sample build so a screenshot shows the actual game, not empty ground.
func _village(root: Node) -> void:
	var plan := [
		[Vector3i(-2,0,-1), BlockData.Type.HOUSE], [Vector3i(-1,0,-1), BlockData.Type.HOUSE],
		[Vector3i(-2,0,0), BlockData.Type.HOUSE], [Vector3i(-1,0,0), BlockData.Type.HOUSE],
		[Vector3i(-1,1,0), BlockData.Type.HOUSE],
		[Vector3i(1,0,-1), BlockData.Type.HOUSE], [Vector3i(1,1,-1), BlockData.Type.HOUSE],
		[Vector3i(2,1,-1), BlockData.Type.HOUSE],
		[Vector3i(3,0,1), BlockData.Type.WATER], [Vector3i(2,0,1), BlockData.Type.WATER],
		[Vector3i(3,0,2), BlockData.Type.WATER], [Vector3i(2,0,2), BlockData.Type.WATER],
		[Vector3i(0,0,2), BlockData.Type.SOURCE], [Vector3i(0,0,3), BlockData.Type.BELL],
		[Vector3i(-2,0,2), BlockData.Type.GEAR],
	]
	for e in plan:
		var c: Vector3i = e[0]
		var n: Node3D = BlockFactory.instantiate(e[1])
		root.add_child(n)
		n.position = GridManager.cell_to_world(c)
		if "grid_cell" in n:
			n.grid_cell = c
		GridManager.set_block(c, BlockData.new(e[1], n))
		if n.has_method("refresh_shape"):
			n.refresh_shape()
