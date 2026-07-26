extends Node

## Animals that actually read the world instead of wandering over it. Every
## species is gated on something the player BUILT, and every species does
## something back — that two-way link is the whole point, otherwise they are
## just decoration that happens to move:
##
##   Birds — need a house to nest near. They perch on roofs, and when a bird
##           lands on a BELL, CHIME or DRUM it PLAYS it. Your garden gets a
##           second musician you didn't program. They scatter when you build.
##   Cat   — needs a small village (2+ houses). Walks the rooftops and paths,
##           refuses to step on water, and at night settles beside a lit stone
##           lantern. Naps where it stops.
##   Ducks — need a real pond (3+ open water cells). They paddle it in a loose
##           line and dip for food, splashing the surface.
##   Deer  — the shy one. Only comes out when the machine is QUIET, and leaves
##           the moment a stream starts running. Turning your garden off is the
##           only way to see it.
##
## Cost control: the grid scan is dirty-flagged and throttled exactly like
## VoxelSurfaceManager, populations are capped, and the caps halve on the web
## LITE profile.

const SCAN_INTERVAL := 0.4
const UP := Vector3i(0, 1, 0)

const BIRD_COLORS: Array[Color] = [Color("6b8fb5"), Color("c98b6b"), Color("7fa87f"), Color("b58fb0")]
const CAT_COLORS: Array[Color] = [Color("d9a441"), Color("55504e"), Color("e8e2d6")]
const DUCK_COLORS: Array[Color] = [Color("f2e3c0"), Color("cfd8dc"), Color("e8c98a")]

## Blocks a bird can play by landing on them, and how hard it hits.
const INSTRUMENTS: Dictionary = {
	BlockData.Type.BELL: "ring",
	BlockData.Type.CHIME: "ring",
	BlockData.Type.DRUM: "hit",
}

var _dirty := true
var _timer := 0.0
var _perches: Array[Vector3i] = []      # top-free cells a bird may land on
var _instruments: Array[Vector3i] = []  # subset of the above that make a sound
var _walkable: Array[Vector3i] = []     # top-free, non-water: cat territory
var _pond: Array[Vector3i] = []         # top-free water
var _houses := 0
var _lanterns: Array[Vector3i] = []

var _birds: Array[Dictionary] = []
var _cats: Array[Dictionary] = []
var _ducks: Array[Dictionary] = []
var _deer: Array[Dictionary] = []
var _quiet := 0.0                       # seconds since the machine last ran

func _ready() -> void:
	GridManager.block_placed.connect(_on_changed)
	GridManager.block_removed.connect(_on_changed)
	GridManager.grid_cleared.connect(_on_cleared)

func _on_changed(cell: Vector3i) -> void:
	_dirty = true
	# Building beside a bird startles it into the air — the garden reacting to
	# you is what sells the animals as alive rather than scenery.
	scatter_near(GridManager.cell_to_world(cell), 3.2)

func _on_cleared() -> void:
	_dirty = true
	for herd in [_birds, _cats, _ducks, _deer]:
		for c in herd:
			if is_instance_valid(c["root"]):
				c["root"].queue_free()
		herd.clear()

func _cap(n: int) -> int:
	return maxi(1, n / 2) if QualityManager.lite else n

# --------------------------------------------------------------- world scan
## One pass over the grid, throttled. Everything the species rules need is
## collected here so no creature ever walks the whole grid itself.
func _scan() -> void:
	_perches.clear(); _instruments.clear(); _walkable.clear()
	_pond.clear(); _lanterns.clear()
	_houses = 0
	for cell in GridManager.get_all_cells():
		var b: BlockData = GridManager.get_block(cell)
		if b == null:
			continue
		if b.type == BlockData.Type.HOUSE:
			_houses += 1
		if b.type == BlockData.Type.STONE_LANTERN:
			_lanterns.append(cell)
		if GridManager.has_block(cell + UP):
			continue                      # buried: nothing can stand here
		if b.type == BlockData.Type.WATER:
			_pond.append(cell)
			continue
		_perches.append(cell)
		if INSTRUMENTS.has(b.type):
			_instruments.append(cell)
		else:
			_walkable.append(cell)

func _process(delta: float) -> void:
	_timer += delta
	if _dirty and _timer >= SCAN_INTERVAL:
		_timer = 0.0
		_dirty = false
		_scan()
		_populate()

	_quiet = 0.0 if StreamManager.is_playing() else _quiet + delta
	var t: float = Time.get_ticks_msec() / 1000.0
	_tick_birds(delta, t)
	_tick_cats(delta, t)
	_tick_ducks(delta, t)
	_tick_deer(delta, t)

## Spawn/despawn so the population always matches what the world can support.
## Population has to GROW WITH the thing that supports it, not switch on. The
## first version gated on "is there a house at all", so one hut instantly had
## three birds hopping on it and two houses added two cats — a crowd on a build
## with nothing in it yet. Animals should feel like they found the place, which
## means the first one arrives alone and the rest turn up as the village does.
## {arrives at, then one more every, hard cap}. The FIRST threshold is kept low
## on purpose — one house should still earn one bird, because a bird landing on
## your bell is the moment the whole feature exists for. It is the CROWD that was
## wrong, so the second and third only turn up once there is a real village.
##   1 house  -> 1 bird                 (was: 3 birds)
##   4 houses -> 1 bird + 1 cat         (was: 3 birds + 2 cats)
##   9 houses -> 3 birds + 1 cat
const BIRDS := [1, 4, 3]
const CATS := [4, 6, 2]
const DUCKS := [3, 5, 3]

func _populate() -> void:
	var birds: int = 0 if _perches.is_empty() else _scaled(_houses, BIRDS)
	var cats: int = 0 if _walkable.is_empty() else _scaled(_houses, CATS)
	_fit(_birds, _cap(birds), _make_bird)
	_fit(_cats, _cap(cats), _make_cat)
	_fit(_ducks, _cap(_scaled(_pond.size(), DUCKS)), _make_duck)

## One creature once `supply` reaches rule[0], then one more per rule[1] beyond
## that, never more than rule[2].
func _scaled(supply: int, rule: Array) -> int:
	if supply < int(rule[0]):
		return 0
	return mini(int(rule[2]), 1 + (supply - int(rule[0])) / int(rule[1]))

func _fit(herd: Array, want: int, maker: Callable) -> void:
	while herd.size() > want:
		var c: Dictionary = herd.pop_back()
		_poof(c)
	while herd.size() < want:
		herd.append(maker.call())

func _poof(c: Dictionary) -> void:
	if is_instance_valid(c["root"]):
		SceneryManager.burst(c["root"].global_position + Vector3(0, 0.2, 0), Color(0.9, 0.9, 0.85))
		c["root"].queue_free()

func _rand_cell(pool: Array[Vector3i]) -> Vector3i:
	return pool[randi() % pool.size()]

func _top_of(cell: Vector3i) -> Vector3:
	return GridManager.cell_to_world(cell) + Vector3(0, 0.5, 0)

# ------------------------------------------------------------------- birds
func _make_bird() -> Dictionary:
	var col: Color = BIRD_COLORS.pick_random()
	var parts: Dictionary = CritterMesh.bird(col, col.lightened(0.45))
	add_child(parts["root"])
	var cell: Vector3i = _rand_cell(_perches)
	parts["root"].position = _top_of(cell)
	return {
		"root": parts["root"], "body": parts["body"], "wings": parts["wings"],
		"state": "perch", "wait": randf_range(2.0, 6.0),
		"from": parts["root"].position, "to": parts["root"].position,
		"t": 0.0, "dur": 1.0, "cell": cell, "phase": randf() * TAU,
	}

func _tick_birds(delta: float, t: float) -> void:
	for b in _birds:
		if not is_instance_valid(b["root"]):
			continue
		if b["state"] == "perch":
			_bird_perched(b, delta, t)
		else:
			_bird_flying(b, delta)

func _bird_perched(b: Dictionary, delta: float, t: float) -> void:
	b["wait"] -= delta
	# Idle hop + head bob so a perched bird never reads as a statue.
	b["body"].position.y = 0.085 + absf(sin(t * 2.3 + b["phase"])) * 0.012
	for w in b["wings"]:
		w.rotation.z = lerpf(w.rotation.z, 0.0, delta * 6.0)
	if b["wait"] <= 0.0:
		_bird_launch(b)

func _bird_launch(b: Dictionary) -> void:
	if _perches.is_empty():
		return
	b["from"] = b["root"].position
	b["cell"] = _rand_cell(_perches)
	b["to"] = _top_of(b["cell"])
	b["dur"] = maxf(0.6, b["from"].distance_to(b["to"]) / 3.2)
	b["t"] = 0.0
	b["state"] = "fly"

func _bird_flying(b: Dictionary, delta: float) -> void:
	b["t"] += delta / b["dur"]
	var p: float = clampf(b["t"], 0.0, 1.0)
	# Arc up over the middle of the hop, and flap hardest at the top.
	var pos: Vector3 = (b["from"] as Vector3).lerp(b["to"], p) + Vector3(0, sin(p * PI) * 0.9, 0)
	var prev: Vector3 = b["root"].position
	b["root"].position = pos
	var vel: Vector3 = pos - prev
	if vel.length() > 0.0001:
		b["root"].rotation.y = atan2(-vel.z, vel.x)
	var flap: float = sin(b["t"] * 34.0) * 0.9
	for i in (b["wings"] as Array).size():
		b["wings"][i].rotation.z = flap * (1.0 if i == 0 else -1.0)
	if p >= 1.0:
		b["state"] = "perch"
		b["wait"] = randf_range(2.5, 7.0)
		_bird_land(b)

## The payoff: a bird that lands on an instrument PLAYS it.
func _bird_land(b: Dictionary) -> void:
	var block: BlockData = GridManager.get_block(b["cell"])
	if block == null or not is_instance_valid(block.node):
		return
	var method: String = INSTRUMENTS.get(block.type, "")
	if method != "" and block.node.has_method(method):
		block.node.call(method)

## Anything sudden nearby (a block landing) puts the birds up.
func scatter_near(pos: Vector3, radius: float) -> void:
	for b in _birds:
		if is_instance_valid(b["root"]) and b["state"] == "perch" \
				and b["root"].position.distance_to(pos) <= radius:
			_bird_launch(b)

# -------------------------------------------------------------------- cats
func _make_cat() -> Dictionary:
	var parts: Dictionary = CritterMesh.cat(CAT_COLORS.pick_random())
	add_child(parts["root"])
	var cell: Vector3i = _rand_cell(_walkable)
	parts["root"].position = _top_of(cell)
	return {
		"root": parts["root"], "head": parts["head"], "tail": parts["tail"],
		"state": "sit", "wait": randf_range(3.0, 8.0),
		"from": parts["root"].position, "to": parts["root"].position,
		"t": 0.0, "dur": 1.0, "phase": randf() * TAU, "look": Vector3.ZERO,
	}

func _tick_cats(delta: float, t: float) -> void:
	for c in _cats:
		if not is_instance_valid(c["root"]):
			continue
		# Tail never stops — a still tail reads as a dead animal.
		c["tail"].rotation.y = sin(t * 1.5 + c["phase"]) * 0.35
		if c["state"] == "sit":
			c["wait"] -= delta
			c["root"].position.y = lerpf(c["root"].position.y, (c["to"] as Vector3).y, delta * 6.0)
			if c["look"] != Vector3.ZERO:
				var d: Vector3 = c["look"] - c["root"].position
				c["root"].rotation.y = lerp_angle(c["root"].rotation.y, atan2(-d.z, d.x), delta * 3.0)
			if c["wait"] <= 0.0:
				_cat_walk(c)
		else:
			c["t"] += delta / c["dur"]
			var p: float = clampf(c["t"], 0.0, 1.0)
			var pos: Vector3 = (c["from"] as Vector3).lerp(c["to"], p)
			pos.y += absf(sin(p * PI * 6.0)) * 0.05      # padding gait
			var prev: Vector3 = c["root"].position
			c["root"].position = pos
			var vel: Vector3 = pos - prev
			if vel.length() > 0.0001:
				c["root"].rotation.y = lerp_angle(c["root"].rotation.y, atan2(-vel.z, vel.x), delta * 8.0)
			if p >= 1.0:
				c["state"] = "sit"
				c["wait"] = randf_range(4.0, 11.0)

## Cats pick a destination with a preference, not at random: at night they head
## for a lit lantern, otherwise they take the nearest few walkable spots. Water
## is never in `_walkable`, so they physically cannot decide to swim.
func _cat_walk(c: Dictionary) -> void:
	if _walkable.is_empty():
		return
	var target: Vector3i
	if MapThemes.current == 3 and not _lanterns.is_empty() and randf() < 0.6:
		var lamp: Vector3i = _rand_cell(_lanterns)
		target = _nearest_walkable(GridManager.cell_to_world(lamp))
	else:
		target = _rand_cell(_walkable)
	c["from"] = c["root"].position
	c["to"] = _top_of(target)
	c["dur"] = maxf(0.8, (c["from"] as Vector3).distance_to(c["to"]) / 1.4)
	c["t"] = 0.0
	c["state"] = "walk"

func _nearest_walkable(to: Vector3) -> Vector3i:
	var best: Vector3i = _walkable[0]
	var best_d: float = INF
	for cell in _walkable:
		var d: float = GridManager.cell_to_world(cell).distance_squared_to(to)
		if d < best_d:
			best_d = d
			best = cell
	return best

## A click near a cat makes it turn and look. Called by PlacementController.
func look_near(pos: Vector3, radius: float = 4.0) -> void:
	for c in _cats:
		if is_instance_valid(c["root"]) and c["root"].position.distance_to(pos) <= radius:
			c["look"] = pos

# ------------------------------------------------------------------- ducks
func _make_duck() -> Dictionary:
	var parts: Dictionary = CritterMesh.duck(DUCK_COLORS.pick_random())
	add_child(parts["root"])
	return {
		"root": parts["root"], "head": parts["head"],
		"angle": randf() * TAU, "radius": randf_range(0.3, 0.9),
		"speed": randf_range(0.25, 0.5), "phase": randf() * TAU,
		"dip": 0.0, "splashed": false,
	}

func _tick_ducks(delta: float, t: float) -> void:
	if _pond.is_empty():
		return
	var centre := Vector3.ZERO
	for cell in _pond:
		centre += GridManager.cell_to_world(cell)
	centre /= float(_pond.size())
	# Radius grows with the pond so ducks use the water they actually have.
	var span: float = clampf(sqrt(float(_pond.size())) * 0.42, 0.3, 3.0)

	for d in _ducks:
		if not is_instance_valid(d["root"]):
			continue
		d["angle"] += delta * d["speed"]
		var r: float = minf(d["radius"], span)
		var pos: Vector3 = centre + Vector3(cos(d["angle"]) * r, 0.52, sin(d["angle"]) * r)
		pos.y += sin(t * 1.4 + d["phase"]) * 0.02      # riding the ripples
		d["root"].position = pos
		d["root"].rotation.y = atan2(-cos(d["angle"]), -sin(d["angle"]))
		# Occasional up-end to feed: head dips, then a splash on the way back.
		if d["dip"] <= 0.0 and randf() < delta / 9.0:
			d["dip"] = 1.0
			d["splashed"] = false
		if d["dip"] > 0.0:
			var p: float = 1.0 - d["dip"]
			d["root"].rotation.z = sin(p * PI) * 0.9
			d["dip"] = maxf(0.0, d["dip"] - delta / 1.1)
			if p > 0.8 and not d["splashed"]:
				d["splashed"] = true
				StreamManager._spawn_splash(pos, Color(0.85, 0.94, 0.98))

# -------------------------------------------------------------------- deer
## The deer is a reward for stillness: it only walks in after the machine has
## been silent a while, and it bolts as soon as water starts running again.
const DEER_QUIET_S := 12.0

func _tick_deer(delta: float, t: float) -> void:
	var wants: bool = _quiet > DEER_QUIET_S and _walkable.size() >= 6 and not QualityManager.lite
	if wants and _deer.is_empty():
		_deer.append(_make_deer())
	elif not wants and not _deer.is_empty():
		for d in _deer:
			_poof(d)
		_deer.clear()
		return

	for d in _deer:
		if not is_instance_valid(d["root"]):
			continue
		d["wait"] -= delta
		# Grazing: the head dips to the ground, lifts to check for danger.
		var graze: float = maxf(0.0, sin(t * 0.5 + d["phase"]))
		d["head"].position.y = 0.17 - graze * 0.16
		d["root"].rotation.y += sin(t * 0.2 + d["phase"]) * delta * 0.4
		if d["wait"] <= 0.0 and not _walkable.is_empty():
			d["wait"] = randf_range(6.0, 14.0)
			d["root"].position = _top_of(_rand_cell(_walkable))

func _make_deer() -> Dictionary:
	var col: Color = MapThemes.theme().get("foliage", Color()) if MapThemes.current == 2 else Color("b98a5e")
	if col == Color():
		col = Color("b98a5e")
	var parts: Dictionary = CritterMesh.deer(col)
	add_child(parts["root"])
	parts["root"].position = _top_of(_rand_cell(_walkable))
	return {"root": parts["root"], "head": parts["head"], "wait": randf_range(5.0, 10.0), "phase": randf() * TAU}
