extends Node

## Dev-only frame-cost probe. Boots a scene with a REAL renderer, forces the WEB
## LITE profile so desktop numbers mean something about the web build, builds a
## representative load, then reports frame time and what the renderer is actually
## being asked to draw.
##
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##       tools/perf.tscn -- scene=res://scenes/main.tscn lite=1 houses=24
##
## Reading the numbers: DRAW CALLS is the one that matters on gl_compatibility.
## Primitives are cheap, state changes are not.

var _lite := true
var _houses := 24
var _label := "run"

func _ready() -> void:
	var target := "res://scenes/main.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="): target = a.substr(6)
		elif a.begins_with("lite="): _lite = a.substr(5) != "0"
		elif a.begins_with("houses="): _houses = int(a.substr(7))
		elif a.begins_with("label="): _label = a.substr(6)

	# WITHOUT THIS EVERY MEASUREMENT IS A LIE. With vsync on, every configuration
	# reports exactly the refresh interval (6.95ms on a 144Hz panel) whatever the
	# scene costs, because the frame is spent waiting for the monitor. The first
	# run of this harness "measured" 144fps for an empty island and for a village
	# alike, which says nothing at all.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	# Force the profile BEFORE the scene builds, so it applies the same way the
	# real web build would.
	QualityManager.lite = _lite

	var s: Node = load(target).instantiate()
	add_child(s)
	for _f in range(45):
		await get_tree().process_frame
	GridManager.clear_all()
	await get_tree().process_frame
	if _houses > 0:
		_build(s)
	for _f in range(120):
		await get_tree().process_frame

	# Measure over a decent window; a single frame is noise.
	var frames := 180
	var t0: int = Time.get_ticks_usec()
	var worst := 0
	var prev: int = t0
	for _f in range(frames):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxi(worst, now - prev)
		prev = now
	var total: int = Time.get_ticks_usec() - t0

	var avg_ms: float = float(total) / float(frames) / 1000.0
	print("PERF[%s] lite=%s houses=%d  avg=%.2fms (%.0f fps)  worst=%.2fms" % [
		_label, str(_lite), _houses, avg_ms, 1000.0 / maxf(avg_ms, 0.001), float(worst) / 1000.0])
	print("   draw_calls=%d  objects=%d  primitives=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	var env: Environment = _env_of(s)
	if env != null:
		print("   glow=%s shadows=%s msaa=%d fog=%s adjust=%s" % [
			str(env.glow_enabled), str(_sun_shadow(s)),
			int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)),
			str(env.fog_enabled), str(env.adjustment_enabled)])
	print("   viewports=%d critters=%d particles=%d" % [
		_count(get_tree().root, "SubViewport"),
		WildlifeManager._birds.size() + WildlifeManager._cats.size()
			+ WildlifeManager._ducks.size() + WildlifeManager._deer.size(),
		_count(get_tree().root, "GPUParticles3D")])
	_breakdown(s)
	get_tree().quit()

## Which subtree is actually costing draw calls. "Fast enough overall" hides a
## single group doing most of the work.
func _breakdown(root: Node) -> void:
	var rows: Array = []
	for c in root.get_children():
		var surf := _surfaces(c)
		if surf[0] > 0:
			rows.append([c.name, surf[0], surf[1]])
	# The autoloads parent their visuals to themselves, not to the scene.
	for a in ["SceneryManager", "CloudSea", "IslandBuilder", "KarakuriClock",
			"DecorManager", "PondDecorManager", "WildlifeManager", "StreamManager",
			"VoxelSurfaceManager", "AmbientLeaves", "FireflyManager"]:
		var n := get_node_or_null("/root/" + a)
		if n != null:
			var surf := _surfaces(n)
			if surf[0] > 0:
				rows.append([a, surf[0], surf[1]])
	rows.sort_custom(func(x, y): return x[1] > y[1])
	print("   --- surfaces / verts by group ---")
	for r in rows:
		print("     %-22s %4d surfaces  %7d verts" % [r[0], r[1], r[2]])

func _surfaces(n: Node) -> Array:
	var s := 0
	var v := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		s = m.get_surface_count()
		for i in s:
			var arr: Array = m.surface_get_arrays(i)
			if not arr.is_empty():
				v += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for k in n.get_children():
		var r := _surfaces(k)
		s += r[0]; v += r[1]
	return [s, v]

func _env_of(root: Node) -> Environment:
	var we := root.find_child("WorldEnvironment", true, false)
	return we.environment if we != null else null

func _sun_shadow(root: Node) -> bool:
	var sun := root.find_child("DirectionalLight3D", true, false)
	return sun != null and sun.shadow_enabled

func _count(n: Node, cls: String) -> int:
	var c: int = 1 if n.is_class(cls) else 0
	for k in n.get_children():
		c += _count(k, cls)
	return c

## A village roughly the size someone would actually build, plus a pond and a
## running machine, so the numbers reflect play rather than an empty island.
func _build(root: Node) -> void:
	var n := 0
	for i in _houses:
		var c := Vector3i(-4 + (i % 6), i / 12, -3 + ((i / 6) % 2))
		_place(root, c, BlockData.Type.HOUSE)
		n += 1
	for z in 3:
		for x in 3:
			_place(root, Vector3i(2 + x, 0, 1 + z), BlockData.Type.WATER)
	_place(root, Vector3i(0, 2, 3), BlockData.Type.SOURCE)
	_place(root, Vector3i(0, 0, 4), BlockData.Type.BELL)
	_place(root, Vector3i(-1, 0, 4), BlockData.Type.GEAR)
	_place(root, Vector3i(-2, 0, 4), BlockData.Type.DRUM)

func _place(root: Node, c: Vector3i, type: int) -> void:
	if GridManager.has_block(c):
		return
	var inst: Node3D = BlockFactory.instantiate(type)
	root.add_child(inst)
	inst.position = GridManager.cell_to_world(c)
	if "grid_cell" in inst:
		inst.grid_cell = c
	GridManager.set_block(c, BlockData.new(type, inst))
	if inst.has_method("refresh_shape"):
		inst.refresh_shape()
