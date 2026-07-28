extends Node

## Dev-only: boot a scene with a REAL renderer, let it settle, save a PNG, quit.
## Headless uses a dummy driver and renders nothing, so this is the only way to
## actually look at the game from a script.
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 tools/shoot.tscn -- scene=... out=...
var _crop := Rect2i()
var want_theme := -1
var _zoom := -1.0
var _pitch := -1.0

func _ready() -> void:
	var target := "res://scenes/main_menu.tscn"
	var out := "user://shot.png"
	var build := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="): target = a.substr(6)
		elif a.begins_with("out="): out = "user://" + a.substr(4)
		elif a == "build": build = true
		elif a.begins_with("theme="): want_theme = int(a.substr(6))
		elif a.begins_with("zoom="): _zoom = float(a.substr(5))
		elif a.begins_with("pitch="): _pitch = float(a.substr(6))
		elif a.begins_with("crop="):
			var n: PackedStringArray = a.substr(5).split(",")
			_crop = Rect2i(int(n[0]), int(n[1]), int(n[2]), int(n[3]))
	# The game scene calls MapThemes.load_current() in _ready, which would stomp
	# anything set here — so the choice has to go through settings.cfg, and be put
	# back afterwards so a screenshot never changes the player's chosen map.
	var prev := MapThemes.current
	if want_theme >= 0:
		MapThemes.current = want_theme
		MapThemes.save_current()

	var s: Node = load(target).instantiate()
	add_child(s)
	for _f in range(40):
		await get_tree().process_frame
	_frame(s)
	if build:
		# main.tscn auto-loads the last save on entry ("seamless continue"), so a
		# test shot would otherwise be the sample build PLUS whatever was lying in
		# user://save_data.json — which is how a bird ended up perching on thin
		# air in an earlier diagnostic and briefly looked like a game bug.
		GridManager.clear_all()
		await get_tree().process_frame
		_village(s)
	for _f in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if _crop != Rect2i():
		img = img.get_region(_crop)
		# Blow it up so small UI details are actually legible in the saved PNG.
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	_report()
	print("SHOT ", ProjectSettings.globalize_path(out), "  theme=", MapThemes.name_of(MapThemes.current))
	if want_theme >= 0:
		MapThemes.current = prev
		MapThemes.save_current()
	get_tree().quit()

## A small sample build so a screenshot shows the actual game, not empty ground.
func _village(root: Node) -> void:
	var plan := []
	# The four reported cases, side by side and well separated:
	#  A x=-6  four-storey tower  -> spire (is it a house with a spike on top?)
	#  B x=-2  base + ONE cell out -> what supports a 1-cell overhang?
	#  C x=1   base + TWO cells out -> columns
	#  D x=5   two towers + a 2-cell span -> arch underside
	for e in [
		[0,0,0],[1,0,0],[2,0,0], [0,1,0],[1,1,0],
		[0,0,1],[2,0,1],
		[0,0,2],[1,0,2],[2,0,2], [2,1,2],
		[4,0,0],[4,1,0],[4,2,0],
		[4,0,2],[5,0,2],
	]:
		plan.append([Vector3i(e[0], e[1], e[2]), BlockData.Type.HOUSE])
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

## Pull the orbit camera in / change its angle so a shot can actually SHOW the
## thing under test instead of the whole island from far away.
func _frame(root: Node) -> void:
	if _zoom < 0.0 and _pitch < 0.0:
		return
	var cam := root.find_child("OrbitRig", true, false)
	if cam == null:
		return
	if _zoom > 0.0:
		cam.set("_target_zoom", _zoom)
		var arm = cam.get_node_or_null("SpringArm3D")
		if arm != null:
			arm.spring_length = _zoom
	if _pitch > 0.0:
		cam.set("_pitch", deg_to_rad(_pitch))

## What the wildlife manager thinks exists, so a screenshot can be checked
## against it rather than squinting.
func _report() -> void:
	print("WILDLIFE birds=%d cats=%d ducks=%d deer=%d | perches=%d walkable=%d pond=%d houses=%d"
		% [WildlifeManager._birds.size(), WildlifeManager._cats.size(),
		   WildlifeManager._ducks.size(), WildlifeManager._deer.size(),
		   WildlifeManager._perches.size(), WildlifeManager._walkable.size(),
		   WildlifeManager._pond.size(), WildlifeManager._houses])
	print("STREAM segments=%d impacts=%d playing=%s sources=%d visual_children=%d"
		% [StreamManager._segments.size(), StreamManager._impacts.size(),
		   str(StreamManager.is_playing()),
		   GridManager.get_all_cells_of_type(BlockData.Type.SOURCE).size(),
		   StreamManager._visual_root.get_child_count() if StreamManager._visual_root != null else -1])
	for s in StreamManager._segments:
		print("   seg ", s["a"], " -> ", s["b"])
	for c in StreamManager._impacts:
		print("   impact at ", c, " type=", StreamManager._impacts[c].get("type"))
	for b in WildlifeManager._birds:
		if is_instance_valid(b["root"]):
			print("   bird at ", b["root"].global_position.snapped(Vector3.ONE * 0.01), " state=", b["state"])
	for c in WildlifeManager._cats:
		if is_instance_valid(c["root"]):
			print("   cat  at ", c["root"].global_position.snapped(Vector3.ONE * 0.01))
	for d in WildlifeManager._ducks:
		if is_instance_valid(d["root"]):
			print("   duck at ", d["root"].global_position.snapped(Vector3.ONE * 0.01))
