extends Node

## Dev-only frame-cost probe. Boots a scene with a REAL renderer, forces the WEB
## LITE profile so desktop numbers mean something about the web build, builds a
## representative load, then reports frame time and what the renderer is actually
## being asked to draw.
##
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##       tools/perf.tscn -- scene=res://scenes/main.tscn lite=1 blocks=24
##
## Reading the numbers: DRAW CALLS is the one that matters on gl_compatibility.
## Primitives are cheap, state changes are not.

var _lite := true
var _blocks := 24
var _label := "run"
var _churn := false
## Place and remove a block during the sample window, i.e. actually play.
var _build_churn := true
var _scene: Node
var _probe_type: int = BlockData.Type.BELL
var _wood := 0
## Houses are their own cost curve: every house cell rebuilds when any house
## changes, so a town has to be measurable on its own.
var _houses := 0

func _ready() -> void:
	var target := "res://scenes/main.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="): target = a.substr(6)
		elif a.begins_with("lite="): _lite = a.substr(5) != "0"
		elif a.begins_with("blocks="): _blocks = int(a.substr(7))
		elif a.begins_with("label="): _label = a.substr(6)
		elif a.begins_with("churn="): _churn = a.substr(6) != "0"
		elif a.begins_with("place="): _build_churn = a.substr(6) != "0"
		elif a.begins_with("ptype="): _probe_type = int(a.substr(6))
		elif a.begins_with("wood="): _wood = int(a.substr(5))
		elif a.begins_with("houses="): _houses = int(a.substr(7))

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
	_scene = s
	add_child(s)
	for _f in range(45):
		await get_tree().process_frame
	GridManager.clear_all()
	await get_tree().process_frame
	if _blocks > 0:
		_build(s)
	for _f in range(120):
		await get_tree().process_frame

	# Measure over a decent window; a single frame is noise.
	var frames := 420
	var samples: Array[float] = []
	var t0: int = Time.get_ticks_usec()
	var prev: int = t0
	var build_cell := Vector3i(-6, 0, -5)
	for f in range(frames):
		# Worst case: the isosurface is asked to re-solve as often as its throttle
		# allows, which is what a machine with flowing water actually does.
		if _churn:
			VoxelSurfaceManager._dirty = true
		# And the player BUILDS. `churn` used to only dirty the isosurface, so
		# every run measured a finished garden being looked at — never the act of
		# placing something, which is the only thing the player ever does. A cost
		# that scaled with the size of the town was invisible here for exactly
		# that reason. Place and remove a house on the edge of the village, on a
		# beat, so the spike lands inside the sample window.
		if _build_churn and f % 30 == 0:
			if GridManager.has_block(build_cell):
				GridManager.remove_block(build_cell)
			else:
				_place(_scene, build_cell, _probe_type)
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		samples.append(float(now - prev) / 1000.0)
		prev = now
	var total: int = Time.get_ticks_usec() - t0
	samples.sort()
	var avg_ms: float = float(total) / float(frames) / 1000.0
	var p50: float = samples[int(frames * 0.50)]
	var p95: float = samples[int(frames * 0.95)]
	var p99: float = samples[int(frames * 0.99)]
	var worst_ms: float = samples[frames - 1]
	# Frames over 16.7 ms — i.e. ones a player on a 60 Hz screen would actually
	# lose. "Twice the median" was scale-dependent and useless: on a scene running
	# at 1.2 ms it flagged every ordinary 3 ms frame as a drop, which made a
	# perfectly healthy build look like it had regressed.
	var spikes := 0
	for ms in samples:
		if ms > 16.7:
			spikes += 1
	print("PERF[%s] lite=%s blocks=%d  avg=%.2f  p50=%.2f (%.0f fps)  p95=%.2f  p99=%.2f  worst=%.2fms  over16ms=%d/%d" % [
		_label, str(_lite), _blocks, avg_ms, p50, 1000.0 / maxf(p50, 0.001), p95, p99, worst_ms, spikes, frames])
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
	# WildlifeManager exists only on the web branch — a direct identifier
	# would be a compile error here, so resolve dynamically.
	var wl: Node = get_node_or_null("/root/WildlifeManager")
	var critters: int = 0
	if wl != null:
		critters = wl._birds.size() + wl._cats.size() + wl._ducks.size() + wl._deer.size()
	print("   viewports=%d critters=%d particles=%d" % [
		_count(get_tree().root, "SubViewport"), critters,
		_count(get_tree().root, "GPUParticles3D") + _count(get_tree().root, "CPUParticles3D")])
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

## A karakuri roughly the size someone would actually build, plus a pond and a
## running machine, so the numbers reflect play rather than an empty island.
## `blocks=N` scales the instrument bank: this build is about a garden FULL of
## things that make a noise, so that is what the load test is made of.
func _build(root: Node) -> void:
	var kit: Array = [BlockData.Type.BELL, BlockData.Type.CHIME, BlockData.Type.DRUM,
			BlockData.Type.PINWHEEL, BlockData.Type.STONE_LANTERN, BlockData.Type.JELLY,
			BlockData.Type.MUSIC_BOX, BlockData.Type.GEAR]
	for i in _blocks:
		_place(root, Vector3i(-6 + (i % 8), i / 24, -4 + ((i / 8) % 3)), kit[i % kit.size()])
	for z in 3:
		for x in 3:
			_place(root, Vector3i(2 + x, 0, 1 + z), BlockData.Type.WATER)
	var hside: int = int(ceil(sqrt(float(_houses))))
	for i in _houses:
		_place(root, Vector3i(-10 + (i % hside), i / (hside * hside), -10 + ((i / hside) % hside)),
				BlockData.Type.HOUSE)
	# Wood and water are the two types drawn as ONE merged isosurface, so their
	# count is what drives the marching-cubes cost.
	var side: int = int(ceil(sqrt(float(_wood))))
	for i in _wood:
		_place(root, Vector3i(-8 + (i % side), 0, 6 + (i / side)), BlockData.Type.WOOD)
	_place(root, Vector3i(0, 2, 3), BlockData.Type.SOURCE)
	_place(root, Vector3i(0, 0, 4), BlockData.Type.BELL)
	_place(root, Vector3i(-1, 0, 4), BlockData.Type.GEAR)
	_place(root, Vector3i(-2, 0, 4), BlockData.Type.DRUM)
	# A machine that keeps CHANGING, which is what a real build does: a
	# shishi-odoshi fills and tips (add_temp_source -> dirty), a scoop ladles the
	# pond, and both keep the stream and the isosurface re-solving. A static
	# scene measures nothing about the drops players actually see.
	_place(root, Vector3i(4, 3, -2), BlockData.Type.SOURCE)
	_place(root, Vector3i(4, 1, -2), BlockData.Type.SHISHI)
	_place(root, Vector3i(4, 0, -2), BlockData.Type.DRUM)
	_place(root, Vector3i(3, 0, 2), BlockData.Type.SCOOP)
	_place(root, Vector3i(1, 0, 2), BlockData.Type.GEAR)

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
