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
## One shared musical beat (~109 BPM). Every impact snaps to multiples of its
## source's interval on this one clock, so all machines play IN TIME with each
## other — steady spouts land on the beat, slow ones half-time, quick ones
## double-time: layered tempos become polyrhythm, not mush.
const BASE_BEAT := 0.55
const STREAM_RADIUS := 0.09

const STREAM_SHADER: Shader = preload("res://shaders/stream.gdshader")
const CYAN := Color(0.282, 0.792, 0.894, 0.98)   # #48CAE4, the default water

## DYED STREAMS: a scoop ladling a coloured pond pours THAT colour, and the
## colour transposes every instrument it strikes — pink up a fourth+, lilac
## down a fourth, mint felt-muted. Repaint one pond, re-voice the machine.
const DYE_VOICE: Dictionary = {
	"#f49cc4": {"pitch": 1.4983},   # pink → up
	"#b39de0": {"pitch": 0.75},     # lilac → down
	"#7be0c0": {"vol": -8.0},       # mint → felt-muted
}

var _segments: Array = []            # [{a:Vector3, b:Vector3, color:Color}]
var _impacts: Dictionary = {}        # cell -> {type, interval, phase, next, color}
var _driven_gears: Dictionary = {}   # Vector3i gear cell struck by a stream
var _temp_sources: Dictionary = {}   # Vector3i -> {expire:int, color:Color}
var _clock: float = 0.0              # the beat-grid clock
var _visual_root: Node3D
var _stream_mats: Dictionary = {}    # color html -> ShaderMaterial (max ~4)
var _source_audio: Dictionary = {}   # Vector3i (source cell) -> AudioStreamPlayer3D (trickle loop)
var _dirty := true
var _rebuild_timer := 0.0
var _rings: Array[MeshInstance3D] = []   # pooled impact rings (R5)
var _ring_tweens: Array = []
var _ring_next: int = 0
var _night_burst_ms: Dictionary = {}     # cell -> msec (Night firefly throttle)

func _ready() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)
	GridManager.block_placed.connect(_on_changed)
	GridManager.block_removed.connect(_on_changed)
	GridManager.grid_cleared.connect(_on_changed)
	# Pooled note-colour impact rings — allocated once, reused round-robin.
	for i in 12:
		var mi := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.5
		torus.rings = 24
		torus.ring_segments = 4
		mi.mesh = torus
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1, 1, 1, 0.0)
		mi.material_override = m
		mi.visible = false
		add_child(mi)
		_rings.append(mi)
		_ring_tweens.append(null)

## One shared stream material per colour, all pulsing on the same beat.
func _stream_mat_for(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _stream_mats.has(key):
		return _stream_mats[key]
	var m := ShaderMaterial.new()
	m.shader = STREAM_SHADER
	m.set_shader_parameter("water_color", Color(color.r, color.g, color.b, 0.98))
	_stream_mats[key] = m
	return m

func _on_changed(_cell: Vector3i = Vector3i.ZERO) -> void:
	_dirty = true

## A karakuri block (shishi-odoshi) dumping its load becomes a short-lived
## stream source at `cell` — the water visibly continues on below it, KEEPING
## the colour it was filled with (dye flows through the machine).
func add_temp_source(cell: Vector3i, duration_s: float, color: Color = CYAN) -> void:
	_temp_sources[cell] = {"expire": Time.get_ticks_msec() + int(duration_s * 1000.0), "color": color}
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
		if int(_temp_sources[cell]["expire"]) <= now or b == null or b.type != BlockData.Type.SHISHI:
			_temp_sources.erase(cell)
			_dirty = true
	if _dirty:
		_rebuild_timer += delta
		if _rebuild_timer >= REBUILD_INTERVAL:
			_rebuild_timer = 0.0
			_dirty = false
			_rebuild()
	# Beat-grid scheduler: each impact fires on its own interval+PHASE lattice
	# (phase matters for alternator pipes' round-robin), plus ±25ms micro-
	# humanization. Advance with a while so a hitch can't cause drift.
	_clock += delta
	for cell in _impacts:
		var e: Dictionary = _impacts[cell]
		if _clock >= e["next"]:
			while e["next"] <= _clock:
				e["next"] += e["interval"]
			get_tree().create_timer(randf_range(0.0, 0.025)).timeout.connect(
				_play_impact.bind(cell, e["type"]))
	# The whole machine breathes on the downbeat (stream shader emission).
	var pulse: float = 1.0 - beat_phase()
	for key in _stream_mats:
		_stream_mats[key].set_shader_parameter("beat_pulse", pulse)

# ---------------------------------------------------------------- tracing
func _rebuild() -> void:
	_segments.clear()
	_impacts.clear()
	_driven_gears.clear()
	var sources: Array = GridManager.get_all_cells_of_type(BlockData.Type.SOURCE)
	for cell in sources:
		_trace(cell, _interval_for_source(cell), CYAN)
	# Karakuri-made water: tipping shishi tubes keep the colour they drank;
	# scoops pour THE POND'S colour — dye flows through the machine.
	for cell in _temp_sources:
		_trace(cell, BASE_BEAT, _temp_sources[cell]["color"])
	for cell in GridManager.get_all_cells_of_type(BlockData.Type.SCOOP):
		if is_scoop_active(cell):
			_trace(cell, BASE_BEAT, _scoop_color(cell))
	_refresh_source_audio(sources)
	_render()

## The colour of the pond the scoop is ladling from.
func _scoop_color(cell: Vector3i) -> Color:
	for dir in GridManager.DIRECTIONS:
		var nb: BlockData = GridManager.get_block(cell + dir)
		if nb != null and nb.type == BlockData.Type.WATER:
			return BlockVariants.color_of(BlockData.Type.WATER, int(nb.state.get("variant", 0)))
	return CYAN

# ------------------------------------------------ beat-grid accessors (juice)
## Where we are inside the current beat, 0..1 (placement uses this to judge
## whether a click landed "on the beat" for the gold-ring reward).
func beat_phase() -> float:
	return fmod(_clock, BASE_BEAT) / BASE_BEAT

## Seconds until the next 16th-note subdivision — placement voices snap to it
## so a click near a running machine JOINS its rhythm. Near-zero phase counts
## as "now" so the voice never feels delayed when already on grid.
func seconds_to_next_sub(sub_div: int = 4) -> float:
	var sub: float = BASE_BEAT / float(sub_div)
	var ph: float = fmod(_clock, sub)
	return 0.0 if ph < 0.03 else sub - ph

## Any machine currently making rhythm? (No rhythm → no need to quantize.)
func is_playing() -> bool:
	return not _impacts.is_empty()

## The spout's TEMPO variant scales the beat: steady ×1, slow ×2, quick ×0.5.
func _interval_for_source(cell: Vector3i) -> float:
	var b: BlockData = GridManager.get_block(cell)
	if b != null and b.type == BlockData.Type.SOURCE:
		var v: Dictionary = BlockVariants.get_variant(BlockData.Type.SOURCE, int(b.state.get("variant", 0)))
		return BASE_BEAT * float(v.get("tempo", 1.0))
	return BASE_BEAT

## Stack-based tracer that BRANCHES at pipe junctions (T/cross split the water),
## with a visited guard so cross-connected loops can't spin forever.
## Entries are Dictionaries {pos, dir, last_h, hops, interval, phase, color}:
##  - last_h: the last horizontal direction travelled (jelly trampoline arcs it)
##  - hops: jelly bounce count (bounded)
##  - interval/phase: this branch's beat lattice (ALTERNATOR pipes deal exits
##    round-robin: each exit gets interval × n and a staggered phase — one rule,
##    call-and-response for free)
##  - color: the dye carried from the pouring source
func _trace(src: Vector3i, interval: float = BASE_BEAT, color: Color = CYAN) -> void:
	var stack: Array = [{"pos": src, "dir": DOWN, "last_h": Vector3i.ZERO, "hops": 0,
		"interval": interval, "phase": 0.0, "color": color}]
	var seen: Dictionary = {}
	var guard := 0
	while not stack.is_empty() and guard < MAX_STEPS:
		guard += 1
		var st: Dictionary = stack.pop_back()
		var pos: Vector3i = st["pos"]
		var dir: Vector3i = st["dir"]
		var skey: String = "%s|%s" % [pos, dir]
		if seen.has(skey):
			continue
		seen[skey] = true
		var carried_h: Vector3i = dir if dir.y == 0 else st["last_h"]

		var nxt: Vector3i = pos + dir
		# THE LAWN IS NOT IN THE GRID. The island is a sculpted MESH built by
		# IslandBuilder, not a field of blocks, so GridManager has nothing at
		# y<0 to stop a falling stream. Water poured onto open ground therefore
		# used to fall straight THROUGH the island and keep going to y=-18:
		# eighteen segments of invisible thread under the world, no splash, no
		# impact — so `is_playing()` stayed false and a lone spout on the grass
		# was silent and did nothing.
		#
		# Anything over the island disc now lands ON it. The struck "cell" is the
		# first one below ground, because _play_impact splashes at that cell's TOP
		# face, which is exactly y=0 — the surface.
		if nxt.y < 0:
			if Vector2(nxt.x, nxt.z).length() <= MAP_RADIUS + 1.0:
				_add_seg_world(GridManager.cell_to_world(pos), Vector3(nxt.x, 0.0, nxt.z), st["color"])
				_impact(nxt, BlockData.Type.WATER, st["interval"], st["phase"], st["color"])
				continue
			# Past the rim there is no ground: it pours into the cloud sea.
			_add_seg(pos, nxt, st["color"])
			continue
		# Off the side of the island → the stream pours away into the clouds.
		if Vector2(nxt.x, nxt.z).length() > MAP_RADIUS + 1.0:
			_add_seg(pos, nxt, st["color"])
			continue
		var block: BlockData = GridManager.get_block(nxt)
		if block == null:
			# Empty: travel, then gravity takes over (fall) from there.
			_add_seg(pos, nxt, st["color"])
			stack.append(_entry(st, nxt, DOWN, carried_h))
			continue
		if block.type == BlockData.Type.PIPE or block.type == BlockData.Type.PIPE_BEND:
			var ports: Array = PipeRouting.ports_for(nxt)
			var entry: Vector3i = -dir
			if entry in ports:
				_add_seg(pos, nxt, st["color"])
				var exits: Array = []
				for p in ports:
					if p != entry:
						exits.append(p)
				if exits.is_empty():
					stack.append(_entry(st, nxt, DOWN, carried_h))  # dead-end → drip out
				else:
					var v: Dictionary = BlockVariants.get_variant(BlockData.Type.PIPE, int(block.state.get("variant", 0)))
					if bool(v.get("alternator", false)) and exits.size() >= 2:
						# Round-robin dealer: exit i plays every n beats, offset i.
						exits.sort_custom(func(x, y): return [x.x, x.y, x.z] < [y.x, y.y, y.z])
						for i in exits.size():
							var e2: Dictionary = _entry(st, nxt, exits[i], carried_h)
							e2["interval"] = st["interval"] * exits.size()
							e2["phase"] = st["phase"] + float(i) * st["interval"]
							stack.append(e2)
					else:
						for e in exits:                 # plain: branch to every opening
							stack.append(_entry(st, nxt, e, carried_h))
			else:
				# hit the pipe body from a closed side → splashes on the bamboo
				_add_seg(pos, nxt, st["color"])
				_impact(nxt, block.type, st["interval"], st["phase"], st["color"])
			continue
		# SLUICE GATE: open → water passes straight through; closed → blocked
		# (a wood knock on the paddle). Click the gate in the world to toggle.
		if block.type == BlockData.Type.GATE:
			if bool(block.state.get("open", false)):
				_add_seg(pos, nxt, st["color"])
				stack.append(_entry(st, nxt, dir, carried_h))
			else:
				_add_seg(pos, nxt, st["color"])
				_impact(nxt, BlockData.Type.WOOD, st["interval"], st["phase"], st["color"])
			continue
		# JELLY TRAMPOLINE: falling water bounces up-and-over in the last
		# horizontal direction — the stream hops sideways off the jelly.
		if block.type == BlockData.Type.JELLY and dir == DOWN and int(st["hops"]) < 6:
			_add_seg(pos, nxt, st["color"])
			_impact(nxt, block.type, st["interval"], st["phase"], st["color"])
			var arc: Vector3i = carried_h
			if arc == Vector3i.ZERO or GridManager.has_block(pos + arc):
				arc = Vector3i.ZERO
				for d2 in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					if not GridManager.has_block(pos + d2):
						arc = d2
						break
			if arc != Vector3i.ZERO:
				_add_seg(nxt, pos, st["color"])   # the bounce back up
				var eb: Dictionary = _entry(st, pos, arc, arc)
				eb["hops"] = int(st["hops"]) + 1
				stack.append(eb)
			continue
		# solid target (wood / gear / bell / water / source)
		_add_seg(pos, nxt, st["color"])
		_impact(nxt, block.type, st["interval"], st["phase"], st["color"])

## Child stack entry inheriting the branch's lattice + colour.
func _entry(st: Dictionary, pos: Vector3i, dir: Vector3i, last_h: Vector3i) -> Dictionary:
	return {"pos": pos, "dir": dir, "last_h": last_h, "hops": st["hops"],
		"interval": st["interval"], "phase": st["phase"], "color": st["color"]}

func _add_seg(a: Vector3i, b: Vector3i, color: Color = CYAN) -> void:
	_add_seg_world(GridManager.cell_to_world(a), GridManager.cell_to_world(b), color)

## Segment between two exact WORLD points, for the cases where the endpoint is
## not a cell centre — water stopping on the island surface has to end at y=0
## rather than at the centre of the cell below it, or the last half-cell of the
## stream is drawn buried in the lawn.
func _add_seg_world(a: Vector3, b: Vector3, color: Color = CYAN) -> void:
	_segments.append({"a": a, "b": b, "color": color})

func _impact(cell: Vector3i, type: int, interval: float = BASE_BEAT, phase: float = 0.0, color: Color = CYAN) -> void:
	# Preserve an existing entry's schedule so 0.05s retraces never stutter a
	# running groove — but ONLY when both interval AND phase match (alternator
	# branches differ by phase alone).
	var next: float = phase + ceil((_clock - phase) / interval) * interval
	# CONFLUENCE: _impacts is cleared at the top of each rebuild, so an entry
	# already present means a SECOND stream feeds this cell in this very pass —
	# merged water strikes harder (accented voice, see _play_impact).
	var weight: int = 1
	if _impacts.has(cell):
		weight = mini(int(_impacts[cell].get("weight", 1)) + 1, 3)
		if absf(float(_impacts[cell]["interval"]) - interval) < 0.001 \
				and absf(float(_impacts[cell]["phase"]) - phase) < 0.001:
			next = float(_impacts[cell]["next"])
	_impacts[cell] = {"type": type, "interval": interval, "phase": phase, "next": next, "color": color, "weight": weight}
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
		# Slight taper — falling water narrows as it accelerates.
		cyl.top_radius = STREAM_RADIUS * 0.85
		cyl.bottom_radius = STREAM_RADIUS * 1.15
		cyl.height = length
		cyl.radial_segments = 6
		mi.mesh = cyl
		mi.material_override = _stream_mat_for(seg["color"])
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
	# Dye voice: the stream's colour transposes the instrument it strikes.
	var color: Color = CYAN
	if _impacts.has(cell):
		color = _impacts[cell]["color"]
	var dye: Dictionary = DYE_VOICE.get(color.to_html(false), {})
	var pitch_mul: float = float(dye.get("pitch", 1.0))
	# Confluence accent: merged streams strike louder.
	var weight: int = int(_impacts[cell].get("weight", 1)) if _impacts.has(cell) else 1
	# Confluence accent, capped — three merged streams must read "heavier",
	# not "twice as loud on every single beat".
	var vol: float = clampf(float(dye.get("vol", 0.0)) + float(weight - 1) * 2.5, -8.0, 2.0)
	match type:
		BlockData.Type.BELL:
			var node: Node3D = _node_of(cell, BlockData.Type.BELL)
			AudioManager.play_chime(node.global_position if node else pos, -1, pitch_mul)
			if node:
				FireflyManager.burst_at(node.global_position)
				if node.has_method("ring"):
					node.ring()
		BlockData.Type.JELLY:
			AudioManager.play_jelly_bounce(pos)
			var jelly: Node3D = _node_of(cell, BlockData.Type.JELLY)
			if jelly and jelly.has_method("bounce"):
				jelly.bounce()
		# Karakuri targets: the stream OPERATES them instead of just splashing.
		BlockData.Type.SHISHI:
			var shishi: Node3D = _node_of(cell, BlockData.Type.SHISHI)
			if shishi:
				shishi.fill(color)
		BlockData.Type.CHIME:
			var chime: Node3D = _node_of(cell, BlockData.Type.CHIME)
			if chime:
				chime.ring(pitch_mul)
		BlockData.Type.DRUM:
			var drum: Node3D = _node_of(cell, BlockData.Type.DRUM)
			if drum:
				drum.hit()
		BlockData.Type.PINWHEEL:
			var pin: Node3D = _node_of(cell, BlockData.Type.PINWHEEL)
			if pin:
				pin.splash()
		BlockData.Type.GEAR, BlockData.Type.WOOD, BlockData.Type.MUSIC_BOX, \
		BlockData.Type.SCOOP:
			AudioManager.play_wood_pitch(pos, 1.0 * pitch_mul, vol)
		BlockData.Type.WATER:
			# Repeats on the beat for as long as the spout runs — must sit far
			# below the instruments, low-pitched.
			AudioManager.play_splash(pos, -16.0, true)
		_:
			# PIPE/SOURCE deliberately SILENT — water moving through the bamboo
			# system shouldn't knock; only what it finally lands on sings (the
			# constant in-pipe noise was overwhelming).
			pass
	# The splash + pooled ring take the struck NOTE's colour — the machine
	# paints its melody in the air, in time with the quantized sound.
	var tint: Color = _impact_tint(cell, type, color)
	_spawn_splash(pos, tint)
	# LAWN impacts have no block and pos is already grass level — the usual
	# top-face offset would bury the ring inside the island.
	if GridManager.get_block(cell) == null:
		_ring_at(pos + Vector3(0, 0.02, 0), tint)
	else:
		_ring_at(pos - Vector3(0, 0.45, 0), tint)
	# NIGHT runs on light: percussive impacts spark fireflies (throttled).
	if MapThemes.current == 3 and type in [BlockData.Type.CHIME, BlockData.Type.DRUM, BlockData.Type.WOOD, BlockData.Type.JELLY]:
		var now: int = Time.get_ticks_msec()
		if now - int(_night_burst_ms.get(cell, 0)) > int(BASE_BEAT * 2000.0):
			_night_burst_ms[cell] = now
			FireflyManager.burst_at(pos)

## The colour an impact paints with: chime/jelly/pinwheel = their variant
## colour, bell = gold, wood family = warm sand, water = the pond, else = dye.
func _impact_tint(cell: Vector3i, type: int, stream_color: Color) -> Color:
	var b: BlockData = GridManager.get_block(cell)
	var variant: int = int(b.state.get("variant", 0)) if b != null else 0
	match type:
		BlockData.Type.CHIME, BlockData.Type.JELLY, BlockData.Type.PINWHEEL, BlockData.Type.WATER:
			return BlockVariants.color_of(type, variant)
		BlockData.Type.BELL:
			return Color("#F2D06B")
		BlockData.Type.DRUM, BlockData.Type.WOOD, BlockData.Type.GEAR, \
		BlockData.Type.MUSIC_BOX, BlockData.Type.SCOOP:
			return Color("#D4A373")
	return stream_color

## Pooled flat ring at an impact — round-robin over 12 preallocated meshes.
func _ring_at(pos: Vector3, tint: Color) -> void:
	var idx: int = _ring_next
	_ring_next = (_ring_next + 1) % _rings.size()
	var mi: MeshInstance3D = _rings[idx]
	if _ring_tweens[idx] != null and _ring_tweens[idx].is_valid():
		_ring_tweens[idx].kill()
	var m: StandardMaterial3D = mi.material_override
	m.albedo_color = Color(tint.r, tint.g, tint.b, 0.8)
	mi.global_position = pos
	mi.scale = Vector3(0.25, 0.25, 0.25)
	mi.visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.1, 0.25, 1.1), 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(func(): mi.visible = false)
	_ring_tweens[idx] = tw

## TEMPORARILY DISABLED (user feedback): the per-spout water-trickle loop was
## far too loud and constant. Any existing players are cleaned up; nothing new
## spawns. Re-enable later with a much quieter, filtered loop if wanted.
func _refresh_source_audio(_sources: Array) -> void:
	for c in _source_audio.keys():
		var old: AudioStreamPlayer3D = _source_audio[c]
		if is_instance_valid(old):
			old.queue_free()
	_source_audio.clear()

## The node at `cell`, but ONLY if it is still the type the impact was scheduled
## against.
##
## `_impacts` records a type when the stream is traced and plays it later, so the
## block can be swapped in between — replace a shishi with a house while water is
## falling on it and the pending SHISHI impact would call `fill()` on the house:
##   Invalid call. Nonexistent function 'fill' in base 'StaticBody3D (house_block.gd)'
## Checking the live type here fixes every branch at once, rather than sprinkling
## has_method() guards that each new karakuri block would have to remember.
func _node_of(cell: Vector3i, expect: int = -1) -> Node3D:
	var b: BlockData = GridManager.get_block(cell)
	if b == null or not is_instance_valid(b.node):
		return null
	if expect >= 0 and b.type != expect:
		return null
	return b.node

func _spawn_splash(pos: Vector3, tint: Color = Color(0.7, 0.9, 0.95)) -> void:
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
	dm.albedo_color = tint.lerp(Color.WHITE, 0.3)   # note colour, kept pastel
	dm.emission_enabled = true
	dm.emission = tint * 0.4
	s.material = dm
	p.draw_pass_1 = s
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)
