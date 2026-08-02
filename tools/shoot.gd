extends Node

## Dev-only: boot a scene with a REAL renderer, let it settle, save a PNG, quit.
## Headless uses a dummy driver and renders nothing, so this is the only way to
## actually look at the game from a script.
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 tools/shoot.tscn -- scene=... out=...
##
## Flags after the `--`: scene= out= theme= zoom= pitch= yaw= crop=x,y,w,h
##   build      a sample garden instead of whatever is in the save
##   ui         keep the HUD visible (default hides it, as photo mode does)
##   settings   open the menu's settings panel before the shot
##   journal    open the pause menu's discovery journal before the shot
##   credits    open the menu's credits panel before the shot
var _crop := Rect2i()
var want_theme := -1
var _zoom := -1.0
var _wood_test := false
var _stilt_case := false
var _pool := false
var _mixed := false
var _pitch := -1.0
var _open_settings := false
var _open_journal := false
var _open_credits := false
var _yaw := 999.0

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
		elif a.begins_with("yaw="): _yaw = float(a.substr(4))
		elif a == "woodtest": _wood_test = true
		elif a == "stiltcase": _stilt_case = true
		elif a == "pool": _pool = true
		elif a == "mixed": _mixed = true
		elif a == "settings": _open_settings = true
		elif a == "journal": _open_journal = true
		elif a == "credits": _open_credits = true
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
	if _mixed:
		# Same TYPE, different VARIANT, side by side. Each variant is its own
		# isosurface group with its own mesh, so this is where a seam or a gap
		# between two meshes would show.
		GridManager.clear_all()
		await get_tree().process_frame
		for i in 8:
			var c := Vector3i(i - 4, 0, 0)
			var t: int = BlockData.Type.WOOD if i < 6 else BlockData.Type.WATER
			var v: int = (i % 4) if i < 6 else (i % 2)
			var n: Node3D = BlockFactory.instantiate(t)
			s.add_child(n)
			n.position = GridManager.cell_to_world(c)
			if n.has_method("apply_variant"):
				n.apply_variant(BlockVariants.get_variant(t, v))
			var bd := BlockData.new(t, n)
			bd.state["variant"] = v
			GridManager.set_block(c, bd)
	if _pool:
		# A sunken pool with a wall all round it — the shape the report showed:
		# looking across water at a far bank you should NOT be able to see through.
		GridManager.clear_all()
		await get_tree().process_frame
		for x in range(-3, 4):
			for z in range(-3, 4):
				var edge: bool = absi(x) == 3 or absi(z) == 3
				var t: int = BlockData.Type.WOOD if edge else BlockData.Type.WATER
				for y in ([0, 1] if edge else [0]):
					var c := Vector3i(x, y, z)
					var n: Node3D = BlockFactory.instantiate(t)
					s.add_child(n)
					n.position = GridManager.cell_to_world(c)
					GridManager.set_block(c, BlockData.new(t, n))
	if _stilt_case:
		# The reported bug: build a stilted house FIRST, then a house UNDER its
		# legs. Order matters — the stilts exist before the lower cell does.
		GridManager.clear_all()
		await get_tree().process_frame
		var above := Vector3i(0, 2, 0)
		var na: Node3D = BlockFactory.instantiate(BlockData.Type.HOUSE)
		s.add_child(na)
		na.position = GridManager.cell_to_world(above)
		na.grid_cell = above
		GridManager.set_block(above, BlockData.new(BlockData.Type.HOUSE, na))
		for _f in range(20):
			await get_tree().process_frame
		print("STILT step1 ctx=", HouseShape.context(above))
		for mi in na.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh != null:
				print("STILT step1 aabb y=[%.2f..%.2f]" % [mi.mesh.get_aabb().position.y,
					mi.mesh.get_aabb().position.y + mi.mesh.get_aabb().size.y])
		var below := Vector3i(0, 0, 0)
		var nb: Node3D = BlockFactory.instantiate(BlockData.Type.HOUSE)
		s.add_child(nb)
		nb.position = GridManager.cell_to_world(below)
		nb.grid_cell = below
		GridManager.set_block(below, BlockData.new(BlockData.Type.HOUSE, nb))
		for _f in range(20):
			await get_tree().process_frame
		print("STILT step2 ctx=", HouseShape.context(above))
		for cell in [above, below]:
			var node: Node3D = GridManager.get_block(cell).node
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				if mi.mesh == null:
					continue
				var ab: AABB = mi.mesh.get_aabb()
				print("STILT %s mesh=%s y[%.2f..%.2f] xz-reach=%.2f" % [
					cell, mi.name, ab.position.y, ab.position.y + ab.size.y,
					maxf(maxf(absf(ab.position.x), absf(ab.position.x + ab.size.x)),
						maxf(absf(ab.position.z), absf(ab.position.z + ab.size.z)))])
	if _wood_test:
		GridManager.clear_all()
		await get_tree().process_frame
		for i in 4:
			var n: Node3D = BlockFactory.instantiate(BlockData.Type.WOOD)
			s.add_child(n)
			var c := Vector3i(i - 2, 0, 0)
			n.position = GridManager.cell_to_world(c)
			GridManager.set_block(c, BlockData.new(BlockData.Type.WOOD, n))
	if build:
		# main.tscn auto-loads the last save on entry ("seamless continue"), so a
		# test shot would otherwise be the sample build PLUS whatever was lying in
		# user://save_data.json — which is how a bird ended up perching on thin
		# air in an earlier diagnostic and briefly looked like a game bug.
		GridManager.clear_all()
		await get_tree().process_frame
		_village(s)
		# WildlifeManager rescans on a 0.4 s throttle, and the report at the end
		# reads its pools. Capturing before that lands reported a garden with one
		# instrument in it and no birds, which is the harness being early, not the
		# game being wrong.
		await get_tree().create_timer(1.2).timeout
	# The placement ghost follows the mouse, which in a headless-driven shot sits
	# at the middle of the screen — a big translucent cube parked over whatever
	# the shot was meant to show. Photo mode is what the P key uses; use it here
	# too so a screenshot shows the GARDEN.
	if _open_journal:
		var pm := s.find_child("PauseMenu", true, false)
		if pm != null:
			pm.call("toggle")
			pm.call("_toggle_journal")
			for _f in range(10):
				await get_tree().process_frame
	if _open_settings and s.has_method("_on_settings"):
		s.call("_on_settings")
		for _f in range(10):
			await get_tree().process_frame
	if _open_credits and s.has_method("_on_credits"):
		s.call("_on_credits")
		for _f in range(10):
			await get_tree().process_frame
	var pc := s.find_child("PlacementController", true, false)
	if pc != null:
		pc.set("photo_mode", true)
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
## A whole karakuri, wired end to end: a spout pours onto a wheel, the wheel
## drives a music box, the overflow runs a pipe to a shishi-odoshi that tips onto
## a drum, and the pond feeds a scoop that starts it all again. That is the game
## on this branch, so that is what a screenshot has to show.
func _village(root: Node) -> void:
	var plan := [
		# The pour, and the deck it lands on.
		[Vector3i(0, 3, 0), BlockData.Type.SOURCE],
		[Vector3i(0, 0, 0), BlockData.Type.GEAR],
		[Vector3i(1, 0, 0), BlockData.Type.MUSIC_BOX],
		# Piped away to a shishi that tips onto a drum.
		[Vector3i(0, 1, 1), BlockData.Type.PIPE],
		[Vector3i(0, 0, 1), BlockData.Type.PIPE],
		[Vector3i(0, 0, 2), BlockData.Type.SHISHI],
		[Vector3i(0, -1, 2), BlockData.Type.DRUM],
		# A row of chimes, one note each.
		[Vector3i(-2, 0, 0), BlockData.Type.CHIME],
		[Vector3i(-2, 0, 1), BlockData.Type.CHIME],
		[Vector3i(-2, 0, 2), BlockData.Type.CHIME],
		[Vector3i(-2, 0, 3), BlockData.Type.BELL],
		# Pond, scoop, and the quiet things around the edge.
		[Vector3i(2, 0, 2), BlockData.Type.WATER],
		[Vector3i(3, 0, 2), BlockData.Type.WATER],
		[Vector3i(2, 0, 3), BlockData.Type.WATER],
		[Vector3i(3, 0, 3), BlockData.Type.WATER],
		[Vector3i(2, 0, 1), BlockData.Type.SCOOP],
		[Vector3i(-1, 0, 3), BlockData.Type.STONE_LANTERN],
		[Vector3i(1, 0, 3), BlockData.Type.PINWHEEL],
		[Vector3i(-1, 0, -1), BlockData.Type.JELLY],
		[Vector3i(1, 0, -1), BlockData.Type.WOOD],
		[Vector3i(0, 0, -1), BlockData.Type.WOOD],
		# A small merged house so shots cover the town system too.
		[Vector3i(-3, 0, -2), BlockData.Type.HOUSE],
		[Vector3i(-2, 0, -2), BlockData.Type.HOUSE],
		[Vector3i(-3, 0, -3), BlockData.Type.HOUSE],
		[Vector3i(-3, 1, -2), BlockData.Type.HOUSE],
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
		elif n.has_method("face_adjacent_water"):
			n.face_adjacent_water()

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
	if _yaw < 900.0:
		# The rig turns by rotating the NODE (orbit_camera has no _yaw field), so
		# setting one did nothing at all and every yaw= shot came out identical.
		cam.rotation.y = deg_to_rad(_yaw)

## What the managers think exists, so a screenshot can be checked against it.
## WildlifeManager exists only on the web branch — resolved dynamically.
func _report() -> void:
	var wl: Node = get_node_or_null("/root/WildlifeManager")
	if wl != null:
		print("WILDLIFE birds=%d cats=%d ducks=%d deer=%d | perches=%d walkable=%d pond=%d instruments=%d"
			% [wl._birds.size(), wl._cats.size(), wl._ducks.size(), wl._deer.size(),
			   wl._perches.size(), wl._walkable.size(), wl._pond.size(), wl._instruments.size()])
	print("STREAM segments=%d impacts=%d playing=%s sources=%d visual_children=%d"
		% [StreamManager._segments.size(), StreamManager._impacts.size(),
		   str(StreamManager.is_playing()),
		   GridManager.get_all_cells_of_type(BlockData.Type.SOURCE).size(),
		   StreamManager._visual_root.get_child_count() if StreamManager._visual_root != null else -1])
	for s in StreamManager._segments:
		print("   seg ", s["a"], " -> ", s["b"])
	for c in StreamManager._impacts:
		print("   impact at ", c, " type=", StreamManager._impacts[c].get("type"))
	if wl != null:
		for b in wl._birds:
			if is_instance_valid(b["root"]):
				print("   bird at ", b["root"].global_position.snapped(Vector3.ONE * 0.01), " state=", b["state"])
		for c in wl._cats:
			if is_instance_valid(c["root"]):
				print("   cat  at ", c["root"].global_position.snapped(Vector3.ONE * 0.01))
		for d in wl._ducks:
			if is_instance_valid(d["root"]):
				print("   duck at ", d["root"].global_position.snapped(Vector3.ONE * 0.01))
