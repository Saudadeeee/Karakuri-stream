extends Node

## The Karakuri stream: every SOURCE block pours a stream straight down; the
## stream is routed cell-by-cell through bamboo PIPE/PIPE_BEND blocks (entering
## one port, leaving the other) and otherwise falls under gravity until it
## strikes a block. The struck cell plays a sound by its type (wood knock, bell
## chime, gear clack + spin) on a gentle repeating cadence — the whole point of
## the toy. This replaces the old "water floods everywhere" behaviour; static
## WATER blocks still form ponds, they just don't spill any more.

const DOWN := Vector3i(0, -1, 0)
const MAX_STEPS := 80
const MAP_RADIUS := 8.5
const REBUILD_INTERVAL := 0.05
const IMPACT_INTERVAL := 0.55        # seconds between repeated impact sounds
const STREAM_RADIUS := 0.09

var _segments: Array = []            # [{a:Vector3, b:Vector3}] world-space
var _impacts: Dictionary = {}        # Vector3i target cell -> BlockData.Type
var _driven_gears: Dictionary = {}   # Vector3i gear cell struck by a stream
var _temp_sources: Dictionary = {}   # Vector3i -> expire msec (shishi dumps)
var _visual_root: Node3D
var _stream_mat: StandardMaterial3D
var _source_audio: Dictionary = {}   # Vector3i (source cell) -> AudioStreamPlayer3D (trickle loop)
var _dirty := true
var _rebuild_timer := 0.0
var _impact_timer := 0.0

func _ready() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)
	# Same fresh cyan (#48CAE4) as the water shader so water looks identical
	# before, during and after flowing through the pipes.
	_stream_mat = StandardMaterial3D.new()
	_stream_mat.albedo_color = Color(0.282, 0.792, 0.894, 0.98)
	_stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stream_mat.roughness = 0.3
	_stream_mat.emission_enabled = true
	_stream_mat.emission = Color(0.12, 0.42, 0.48)
	_stream_mat.emission_energy_multiplier = 0.18
	GridManager.block_placed.connect(_on_changed)
	GridManager.block_removed.connect(_on_changed)
	GridManager.grid_cleared.connect(_on_changed)

func _on_changed(_cell: Vector3i = Vector3i.ZERO) -> void:
	_dirty = true

## A karakuri block (shishi-odoshi) dumping its load becomes a short-lived
## stream source at `cell` — the water visibly continues on below it.
func add_temp_source(cell: Vector3i, duration_s: float) -> void:
	_temp_sources[cell] = Time.get_ticks_msec() + int(duration_s * 1000.0)
	_dirty = true

## A scoop is ladling when it borders a pond AND a powered gear (the gear
## lifts, the pond supplies) — then this cell pours a new stream.
func is_scoop_active(cell: Vector3i) -> bool:
	var b: BlockData = GridManager.get_block(cell)
	if b == null or b.type != BlockData.Type.SCOOP:
		return false
	var has_water := false
	var has_power := false
	for dir in GridManager.DIRECTIONS:
		var nb: BlockData = GridManager.get_block(cell + dir)
		if nb == null:
			continue
		if nb.type == BlockData.Type.WATER:
			has_water = true
		elif nb.type == BlockData.Type.GEAR and GearManager.is_powered(cell + dir):
			has_power = true
	return has_water and has_power

func _process(delta: float) -> void:
	# Expire finished shishi dumps (and retrace without them). Also drop a dump
	# whose shishi was REMOVED mid-pour — otherwise water keeps streaming out
	# of the empty cell until the timer runs out.
	var now: int = Time.get_ticks_msec()
	for cell in _temp_sources.keys():
		var b: BlockData = GridManager.get_block(cell)
		if _temp_sources[cell] <= now or b == null or b.type != BlockData.Type.SHISHI:
			_temp_sources.erase(cell)
			_dirty = true
	if _dirty:
		_rebuild_timer += delta
		if _rebuild_timer >= REBUILD_INTERVAL:
			_rebuild_timer = 0.0
			_dirty = false
			_rebuild()
	# Repeating impact sounds — a steady water-and-wood rhythm.
	if not _impacts.is_empty():
		_impact_timer += delta
		if _impact_timer >= IMPACT_INTERVAL:
			_impact_timer = 0.0
			for cell in _impacts:
				_play_impact(cell, _impacts[cell])

# ---------------------------------------------------------------- tracing
func _rebuild() -> void:
	_segments.clear()
	_impacts.clear()
	_driven_gears.clear()
	var sources: Array = GridManager.get_all_cells_of_type(BlockData.Type.SOURCE)
	for cell in sources:
		_trace(cell)
	# Karakuri-made water: tipping shishi tubes + ladling scoops pour too.
	for cell in _temp_sources:
		_trace(cell)
	for cell in GridManager.get_all_cells_of_type(BlockData.Type.SCOOP):
		if is_scoop_active(cell):
			_trace(cell)
	_refresh_source_audio(sources)
	_render()

## Stack-based tracer that BRANCHES at pipe junctions (T/cross split the water),
## with a visited guard so cross-connected loops can't spin forever.
func _trace(src: Vector3i) -> void:
	var stack: Array = [[src, DOWN]]
	var seen: Dictionary = {}
	var guard := 0
	while not stack.is_empty() and guard < MAX_STEPS:
		guard += 1
		var st: Array = stack.pop_back()
		var pos: Vector3i = st[0]
		var dir: Vector3i = st[1]
		var skey: String = "%s|%s" % [pos, dir]
		if seen.has(skey):
			continue
		seen[skey] = true

		var nxt: Vector3i = pos + dir
		# Off the island / into the void → the stream pours away.
		if Vector2(nxt.x, nxt.z).length() > MAP_RADIUS + 1.0 or nxt.y < -18:
			_add_seg(pos, nxt)
			continue
		var block: BlockData = GridManager.get_block(nxt)
		if block == null:
			# Empty: travel, then gravity takes over (fall) from there.
			_add_seg(pos, nxt)
			stack.append([nxt, DOWN])
			continue
		if block.type == BlockData.Type.PIPE or block.type == BlockData.Type.PIPE_BEND:
			var ports: Array = PipeRouting.ports_for(nxt)
			var entry: Vector3i = -dir
			if entry in ports:
				_add_seg(pos, nxt)
				var exits: Array = []
				for p in ports:
					if p != entry:
						exits.append(p)
				if exits.is_empty():
					stack.append([nxt, DOWN])       # dead-end port → drip out the bottom
				else:
					for e in exits:                 # branch to every other opening
						stack.append([nxt, e])
			else:
				# hit the pipe body from a closed side → splashes on the bamboo
				_add_seg(pos, nxt)
				_impact(nxt, block.type)
			continue
		# solid target (wood / gear / bell / water / source)
		_add_seg(pos, nxt)
		_impact(nxt, block.type)

func _add_seg(a: Vector3i, b: Vector3i) -> void:
	_segments.append({"a": GridManager.cell_to_world(a), "b": GridManager.cell_to_world(b)})

func _impact(cell: Vector3i, type: int) -> void:
	_impacts[cell] = type
	if type == BlockData.Type.GEAR:
		_driven_gears[cell] = true

# ---------------------------------------------------------------- rendering
func _render() -> void:
	for c in _visual_root.get_children():
		c.queue_free()
	for seg in _segments:
		var a: Vector3 = seg["a"]
		var b: Vector3 = seg["b"]
		var d: Vector3 = b - a
		var length: float = d.length()
		if length < 0.001:
			continue
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = STREAM_RADIUS
		cyl.bottom_radius = STREAM_RADIUS
		cyl.height = length
		cyl.radial_segments = 6
		mi.mesh = cyl
		mi.material_override = _stream_mat
		mi.position = (a + b) * 0.5
		mi.basis = _basis_towards(d / length)
		_visual_root.add_child(mi)

## A basis whose local +Y points along `dir` (cylinders are Y-aligned).
func _basis_towards(dir: Vector3) -> Basis:
	if absf(dir.dot(Vector3.UP)) > 0.999:
		return Basis.IDENTITY if dir.y > 0.0 else Basis(Vector3(1, 0, 0), PI)
	return Basis(Quaternion(Vector3.UP, dir))

# ---------------------------------------------------------------- sound + splash
func _play_impact(cell: Vector3i, type: int) -> void:
	var pos: Vector3 = GridManager.cell_to_world(cell) + Vector3(0.0, 0.5, 0.0)
	match type:
		BlockData.Type.BELL:
			var node: Node3D = _node_of(cell)
			AudioManager.play_chime(node.global_position if node else pos)
			if node:
				FireflyManager.burst_at(node.global_position)
				if node.has_method("ring"):
					node.ring()
		BlockData.Type.JELLY:
			AudioManager.play_jelly_bounce(pos)
		# Karakuri targets: the stream OPERATES them instead of just splashing.
		BlockData.Type.SHISHI:
			var shishi: Node3D = _node_of(cell)
			if shishi:
				shishi.fill()
		BlockData.Type.CHIME:
			var chime: Node3D = _node_of(cell)
			if chime:
				chime.ring()
		BlockData.Type.DRUM:
			var drum: Node3D = _node_of(cell)
			if drum:
				drum.hit()
		BlockData.Type.PINWHEEL:
			var pin: Node3D = _node_of(cell)
			if pin:
				pin.splash()
		BlockData.Type.GEAR, BlockData.Type.WOOD, BlockData.Type.PIPE, \
		BlockData.Type.PIPE_BEND, BlockData.Type.SOURCE, BlockData.Type.MUSIC_BOX, \
		BlockData.Type.SCOOP:
			AudioManager.play_wood_hit(pos)
		_:
			pass  # water: splash only
	_spawn_splash(pos)

## A continuous water-trickle loop plays from every SOURCE spout — the steady
## babbling brook under all the knocks and chimes.
func _refresh_source_audio(sources: Array) -> void:
	var want: Dictionary = {}
	for c in sources:
		want[c] = true
	for c in _source_audio.keys():
		if not want.has(c):
			var old: AudioStreamPlayer3D = _source_audio[c]
			if is_instance_valid(old):
				old.queue_free()
			_source_audio.erase(c)
	for c in sources:
		if not _source_audio.has(c):
			var p: AudioStreamPlayer3D = AudioManager.make_water_loop_player()
			p.position = GridManager.cell_to_world(c)
			add_child(p)
			p.play()
			_source_audio[c] = p

func _node_of(cell: Vector3i) -> Node3D:
	var b: BlockData = GridManager.get_block(cell)
	return b.node if b != null and is_instance_valid(b.node) else null

func _spawn_splash(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.position = pos
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 55.0
	mat.initial_velocity_min = 0.7
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0, -4.0, 0)
	mat.scale_min = 0.03
	mat.scale_max = 0.06
	p.process_material = mat
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.1
	s.radial_segments = 6
	s.rings = 3
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.7, 0.9, 0.95)
	s.material = dm
	p.draw_pass_1 = s
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)
