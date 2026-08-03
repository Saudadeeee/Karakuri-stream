extends Node

## Frame recorder for the store page.
##
##   godot --path . --rendering-driver opengl3 --resolution 960x540 \
##       tools/record.tscn -- seconds=6 fps=20 out=promo
##
## A screenshot cannot sell this game. The whole pitch is that water falls, the
## thing it lands on plays a note, and a bird you did not place rings a bell —
## none of which a still frame contains. This drops a working karakuri on the
## island, orbits slowly around it, and writes one PNG per frame; ffmpeg turns
## the folder into a GIF or an mp4.
##
## Frames are taken on a TIMER, not every rendered frame: the game runs far
## faster than any GIF and capturing every frame would produce a clip in
## slow motion.

const OUT_DIR := "user://record"

var _fps: int = 20
var _seconds: float = 6.0
var _name: String = "promo"
var _zoom: float = 9.0
var _pitch: float = 34.0
var _spin: float = 0.16          # radians per second of camera orbit

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("fps="): _fps = maxi(int(a.substr(4)), 1)
		elif a.begins_with("seconds="): _seconds = maxf(float(a.substr(8)), 0.5)
		elif a.begins_with("out="): _name = a.substr(4)
		elif a.begins_with("zoom="): _zoom = float(a.substr(5))
		elif a.begins_with("pitch="): _pitch = float(a.substr(6))
		elif a.begins_with("spin="): _spin = float(a.substr(5))

	var game: Node = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	for _f in range(30):
		await get_tree().process_frame
	GridManager.clear_all()
	await get_tree().process_frame
	_build_scene(game)

	var rig: Node3D = game.get_node("OrbitRig")
	rig.rotation.y = deg_to_rad(-35.0)
	rig.set("_target_zoom", _zoom)
	rig.set("_pitch", deg_to_rad(_pitch))
	var arm: SpringArm3D = rig.get_node("SpringArm3D")
	arm.spring_length = _zoom
	arm.rotation.x = -deg_to_rad(_pitch)
	# No ghost cube parked in the middle of the shot.
	var pc := game.find_child("PlacementController", true, false)
	if pc != null:
		pc.set("photo_mode", true)
	game.get_node("UI").visible = false

	# Let the water reach the bottom of the chain before recording starts, or the
	# clip opens on a machine that has not started yet.
	await get_tree().create_timer(3.0).timeout

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var total: int = int(_seconds * float(_fps))
	for i in total:
		await get_tree().create_timer(1.0 / float(_fps)).timeout
		rig.rotate_y(_spin / float(_fps))
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%04d.png" % [OUT_DIR, _name, i])
	print("RECORDED %d frames -> %s" % [total, ProjectSettings.globalize_path(OUT_DIR)])
	get_tree().quit()

## A karakuri that runs end to end, arranged so the whole chain is visible from
## one angle: spout -> shishi -> drum, a pond turning a gear that drives a music
## box, a row of chimes, and houses for the birds to arrive at.
func _build_scene(root: Node) -> void:
	var plan := [
		[Vector3i(0, 4, 0), BlockData.Type.SOURCE, 0],
		[Vector3i(0, 2, 0), BlockData.Type.SHISHI, 0],
		[Vector3i(0, 0, 0), BlockData.Type.DRUM, 0],
		[Vector3i(-2, 0, 0), BlockData.Type.CHIME, 0],
		[Vector3i(-2, 0, 1), BlockData.Type.CHIME, 1],
		[Vector3i(-2, 0, 2), BlockData.Type.CHIME, 2],
		[Vector3i(-2, 0, 3), BlockData.Type.CHIME, 3],
		[Vector3i(2, 0, 0), BlockData.Type.WATER, 0],
		[Vector3i(3, 0, 0), BlockData.Type.WATER, 0],
		[Vector3i(2, 0, 1), BlockData.Type.WATER, 0],
		[Vector3i(3, 0, 1), BlockData.Type.WATER, 0],
		[Vector3i(2, 0, -1), BlockData.Type.GEAR, 1],
		[Vector3i(3, 0, -1), BlockData.Type.MUSIC_BOX, 0],
		[Vector3i(1, 0, 2), BlockData.Type.JELLY, 1],
		[Vector3i(0, 0, 3), BlockData.Type.BELL, 0],
		[Vector3i(-1, 0, -2), BlockData.Type.HOUSE, 0],
		[Vector3i(-2, 0, -2), BlockData.Type.HOUSE, 0],
		[Vector3i(-1, 1, -2), BlockData.Type.HOUSE, 0],
		[Vector3i(-2, 0, -3), BlockData.Type.HOUSE, 0],
		[Vector3i(1, 0, -3), BlockData.Type.STONE_LANTERN, 0],
		[Vector3i(2, 0, 3), BlockData.Type.PINWHEEL, 0],
	]
	for e in plan:
		var cell: Vector3i = e[0]
		var inst: Node3D = BlockFactory.instantiate(e[1])
		root.add_child(inst)
		inst.position = GridManager.cell_to_world(cell)
		if "grid_cell" in inst:
			inst.grid_cell = cell
		if inst.has_method("apply_variant"):
			inst.apply_variant(BlockVariants.get_variant(e[1], int(e[2])))
		var bd := BlockData.new(e[1], inst)
		bd.state["variant"] = int(e[2])
		GridManager.set_block(cell, bd)
		if inst.has_method("refresh_shape"):
			inst.refresh_shape()
		elif inst.has_method("face_adjacent_water"):
			inst.face_adjacent_water()
