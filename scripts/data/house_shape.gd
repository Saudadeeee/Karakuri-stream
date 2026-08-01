class_name HouseShape
extends RefCounted

## Townscaper's trick, on our grid: the player never places a *house*, they place
## a house CELL, and the building assembles itself.
##
## WALLS are per-cell and trivial: a face with a house neighbour grows no wall,
## so shared walls vanish and a row reads as one wide room.
##
## ROOFS are the hard part, and the reason this file is shaped the way it is. The
## obvious approach — give every top cell its own little gable — falls apart the
## moment a building is more than one cell wide: a 2x2 gets two parallel gables
## sitting side by side, a 3x3 gets three, and an L-shape gets two wings whose
## ridges collide with no valley between them. It reads as a row of sheds, not a
## house.
##
## So the roof is not a per-cell shape at all. It is a HEIGHT FIELD sampled on a
## half-cell grid, where a sample's height is how deep inside the roof footprint
## it sits — a distance transform, which is the discrete cousin of a straight
## skeleton. Every roof form then falls out of one rule, with no special cases:
##
##   1 cell wide  → only the centre line is interior      → a ridge: a gable
##   2 cells wide → only the shared seam is interior      → one ridge down the middle
##   3x3          → the centre reaches depth 2            → a pyramid/hip
##   L-shape      → the inner corner is deep, the notch isn't → a valley, for free
##   any end      → depth falls off to nothing            → a hip, for free
##
## Neighbouring cells sample the SAME shared points, so each cell can build its
## own patch of roof and the patches meet seamlessly with no coordination.
##
## DOORS and CHIMNEYS need the opposite of locality: exactly one per building, no
## matter its shape. That needs the building's extent, so `_component()` floods
## it — cached on `GridManager.version`, so all the cells of one building share a
## single flood per grid change rather than each paying for their own.
##
## Everything is DETERMINISTIC — `_h()` hashes the cell, never randf() — so a
## house looks identical after a reload and after any rebuild.

const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)

## The four horizontal faces, in a fixed order so "first exposed face" is stable.
const SIDES: Array[Vector3i] = [
	Vector3i(0, 0, -1),   # north / -Z
	Vector3i(1, 0, 0),    # east
	Vector3i(0, 0, 1),    # south
	Vector3i(-1, 0, 0),   # west
]

## How many levels the roof height field can climb. 2 is enough for a pyramid on
## a 3x3 and keeps big blocks from growing absurd spires; wider buildings simply
## plateau, which reads as a mansard and is exactly right at this scale.
const ROOF_LEVELS := 2

## Nothing sane reaches this; it exists so a pathological grid can't hang the
## flood fill. Past it, door/chimney fall back to the local corner rule.
const MAX_BUILDING := 4096

static func is_house(cell: Vector3i) -> bool:
	var b: BlockData = GridManager.get_block(cell)
	return b != null and b.type == BlockData.Type.HOUSE

## A cell that is part of the ROOF surface: a house with open sky above.
static func is_roof_cell(cell: Vector3i) -> bool:
	return is_house(cell) and not is_house(cell + UP)

## Stable per-cell pseudo-random in [0,1). Same cell always gives the same value,
## so window counts and trim choices survive a reload.
static func _h(cell: Vector3i, salt: int) -> float:
	var n: int = hash(Vector3i(cell.x * 73856093, cell.y * 19349663, cell.z * 83492791)) ^ (salt * 2654435761)
	return float(absi(n) % 100003) / 100003.0

## Signed deterministic wobble in [-1,1]. The house builder uses this to break
## the perfect squareness of the cubic grid; keeping it here alongside `_h` is
## the reminder that it must stay a HASH — anything random reshuffles the town
## every time the player reloads.
static func jitter(cell: Vector3i, salt: int) -> float:
	return _h(cell, salt) * 2.0 - 1.0

# ------------------------------------------------------------ roof height field
## Height level of a roof sample point, in DOUBLED cell coordinates: a cell whose
## centre is (cx, cz) covers doubled x in [2cx-1, 2cx+1]. So doubled-even points
## are cell centres and edge midpoints, doubled-odd points are corners — half-cell
## resolution, which is the minimum needed to express a ridge running down the
## middle of a one-cell-wide run.
##
## The level is how many rings of roof cells surround the sample. Ring k spans
## Chebyshev radius 2k-1 in doubled units: ring 1 is the cells actually touching
## the point, ring 2 the cells one step beyond, and so on.
static func roof_level(dx: int, dz: int, y: int) -> int:
	var level := 0
	while level < ROOF_LEVELS:
		if not _ring_is_roof(dx, dz, y, 2 * (level + 1) - 1):
			break
		level += 1
	return level

## How far the roof rises above this cell's top face, at the cell's CENTRE.
## Anything that stands on a house — a perching bird, a cat crossing the rooftops
## — has to add this, or it stands at the level of the eaves and ends up buried
## inside the roof it is supposed to be sitting on.
## Must stay in step with house_block.ROOF_STEP.
const ROOF_RISE: Array[float] = [0.0, 0.48, 0.72]

static func roof_top_height(cell: Vector3i) -> float:
	if not is_roof_cell(cell):
		return 0.0
	return ROOF_RISE[roof_level(cell.x * 2, cell.z * 2, cell.y)]

static func _ring_is_roof(dx: int, dz: int, y: int, r: int) -> bool:
	# Cells whose doubled centre lies within Chebyshev radius r of the sample.
	var cx0: int = int(ceil(float(dx - r) / 2.0))
	var cx1: int = int(floor(float(dx + r) / 2.0))
	var cz0: int = int(ceil(float(dz - r) / 2.0))
	var cz1: int = int(floor(float(dz + r) / 2.0))
	for cx in range(cx0, cx1 + 1):
		for cz in range(cz0, cz1 + 1):
			if not is_roof_cell(Vector3i(cx, y, cz)):
				return false
	return true

# -------------------------------------------------------------------- support
## Nothing sane needs a longer leg than this; it stops a house dropped at y=200
## from growing a two-hundred-cell pillar.
const MAX_STILT := 16

## Anything solid — house, wood, stone, whatever — counts as ground to stand on.
## A house on a wood plinth is supported; only genuinely open air is not.
static func _solid(cell: Vector3i) -> bool:
	return GridManager.has_block(cell)

## How many cells of open air sit under this one before it reaches something
## solid, or the island surface at y=0. Zero means it is already resting on
## something. This is what a house needs to know to grow legs.
static func support_drop(cell: Vector3i) -> int:
	var n := 0
	var c: Vector3i = cell + DOWN
	while n < MAX_STILT and c.y >= 0 and not _solid(c):
		n += 1
		c += DOWN
	return n

## True when this cell hangs in the air but the building it belongs to is held up
## somewhere alongside it — an overhanging upper storey rather than a hut on
## stilts. The two want different things underneath: a cantilever wants a corbel
## bracket back into the wall it juts out from, not a pillar to the ground.
static func is_overhang(cell: Vector3i) -> bool:
	if support_drop(cell) == 0:
		return false
	for d in SIDES:
		var n: Vector3i = cell + d
		if is_house(n) and support_drop(n) == 0:
			return true
	return false

## The axis a cell SPANS, or ZERO. A house cell hanging over open ground with
## supported house cells on BOTH sides of an axis is a bridge, and a bridge in
## this kind of town wants an ARCH under it, not a bracket and not a pillar
## dropped through the gap.
##
## Arches are most of what makes a Townscaper street feel like a place rather
## than a row of boxes: the ground floor turns into an arcade you can see
## through, and they appear purely because of how the player stacked things.
## How far an arch will look for a footing. Beyond this a span reads as a long
## viaduct and wants piers, which is what the stilt path already does.
const ARCH_SPAN := 4

## Where this cell sits inside a spanning run: {axis, index, length}. An arch has
## to be drawn as ONE curve over the WHOLE gap — each cell rendering its own
## complete semicircle produced a row of separate bumps under a bridge instead of
## an arch, which is what a two-cell span actually looked like.
static func arch_run(cell: Vector3i) -> Dictionary:
	var axis: Vector3i = arch_axis(cell)
	if axis == Vector3i.ZERO:
		return {}
	# Walk back to the first airborne cell of the run, then measure it.
	var start: Vector3i = cell
	while is_house(start - axis) and support_drop(start - axis) > 0:
		start -= axis
	var length := 0
	var c: Vector3i = start
	while is_house(c) and support_drop(c) > 0:
		length += 1
		c += axis
	var index := 0
	c = start
	while c != cell:
		index += 1
		c += axis
	return {"axis": axis, "index": index, "length": length}

static func arch_axis(cell: Vector3i) -> Vector3i:
	if support_drop(cell) == 0:
		return Vector3i.ZERO
	# Walk the span in both directions. Requiring the IMMEDIATE neighbours to be
	# supported only ever caught a gap exactly one cell wide, so a two-cell bridge
	# — the normal thing a player builds between two towers — grew no arch at all.
	for axis in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
		if _reaches_support(cell, axis) and _reaches_support(cell, -axis):
			return axis
	return Vector3i.ZERO

## Follow house cells along `dir` and report whether the run lands on one that is
## standing on something, within a sane distance.
static func _reaches_support(cell: Vector3i, dir: Vector3i) -> bool:
	var c: Vector3i = cell + dir
	for _i in ARCH_SPAN:
		if not is_house(c):
			return false
		if support_drop(c) == 0:
			return true
		c += dir
	return false

## The horizontal directions an overhang can brace itself against: neighbours
## that are house cells standing on something.
static func corbel_sides(cell: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for d in SIDES:
		var n: Vector3i = cell + d
		if is_house(n) and support_drop(n) == 0:
			out.append(d)
	return out

## Which cell is responsible for the pillar at one shared corner. A corner is
## touched by up to four cells; without this rule each would grow its own leg and
## a 2x2 platform would sprout four pillars in the same spot. The lexicographic
## first of the cells that actually need one owns it.
static func owns_corner(cell: Vector3i, ax: int, az: int) -> bool:
	var candidates := [
		cell,
		cell + Vector3i(ax, 0, 0),
		cell + Vector3i(0, 0, az),
		cell + Vector3i(ax, 0, az),
	]
	for c in candidates:
		if c == cell:
			continue
		if is_house(c) and support_drop(c) > 0 and not is_overhang(c) and _less(c, cell):
			return false
	return true

# ------------------------------------------------------------------- building
## The connected run of house cells this one belongs to, flooded in 3D (so a
## tower and its ground floor are one building). Cached on GridManager.version:
## every cell of a building rebuilds on the same grid change, and they all share
## this one result instead of each flooding for itself.
static var _cache_version := -1
static var _cache: Dictionary = {}

static func _component(cell: Vector3i) -> Dictionary:
	if GridManager.version != _cache_version:
		_cache_version = GridManager.version
		_cache = {}
	if _cache.has(cell):
		return _cache[cell]

	# A cell that is NOT a house must never seed a flood. `queue_free()` is
	# deferred, so a just-removed house still receives `block_removed` and
	# rebuilds itself one last time — and the flood, which seeded its start cell
	# unconditionally, walked from the dead cell back into its old building,
	# counted itself as a member, and then wrote that wrong answer into the cache
	# FOR EVERY SURVIVING CELL. That is how deleting the base of a tower left the
	# top still believing it was four storeys tall, keeping a spire it had no
	# right to, and why houses came out looking half-built after a delete.
	# Not cached, either: this answer is about a cell that does not exist.
	if not is_house(cell):
		return {"lo": cell, "hi": cell, "bmin": cell, "bmax": cell, "size": 0, "capped": false}

	var seen: Dictionary = {}
	var queue: Array[Vector3i] = [cell]
	seen[cell] = true
	var lo: Vector3i = cell
	var hi: Vector3i = cell
	# `lo`/`hi` are LEXICOGRAPHIC extremes — they name the building's first and
	# last cell, which is what makes "exactly one door" well defined. They are
	# not a bounding box. `bmin`/`bmax` are the real per-axis box; see
	# `component_box`, which is what tells a house whether a distant edit can
	# possibly concern it.
	var bmin: Vector3i = cell
	var bmax: Vector3i = cell
	while not queue.is_empty() and seen.size() < MAX_BUILDING:
		var c: Vector3i = queue.pop_back()
		if _less(c, lo):
			lo = c
		if _less(hi, c):
			hi = c
		bmin = Vector3i(mini(bmin.x, c.x), mini(bmin.y, c.y), mini(bmin.z, c.z))
		bmax = Vector3i(maxi(bmax.x, c.x), maxi(bmax.y, c.y), maxi(bmax.z, c.z))
		for d in GridManager.DIRECTIONS:
			var n: Vector3i = c + d
			if not seen.has(n) and is_house(n):
				seen[n] = true
				queue.append(n)

	var info := {"lo": lo, "hi": hi, "bmin": bmin, "bmax": bmax,
			"size": seen.size(), "capped": seen.size() >= MAX_BUILDING}
	# Every cell of the building gets the same answer, so one flood serves them all.
	for c in seen:
		_cache[c] = info
	return info

## How far from a building an edit can still change how it looks. The widest
## reach is an arch, which hunts `ARCH_SPAN` cells for something to land on;
## bunting reaches 2 and the roof height field reaches `ROOF_LEVELS`. One spare
## cell on top of the largest.
const REACH := ARCH_SPAN + 1

## Does an edit at `changed` concern the building that `cell` belongs to?
##
## A house is NOT a local thing: its door, chimney and storey count come from
## the whole connected component, so a cell removed at the far end of a long
## terrace really does move the door at this end. But that is the *component*,
## not the map. Every house used to rebuild whenever any house anywhere was
## placed or removed, which made one click cost ~10 ms per house already
## standing — 800 ms in an 80-house town, felt as a hard frame drop the moment
## a garden got big. Everything a building depends on lies inside its own
## bounding box grown by `REACH`, plus the columns beneath it that its stilts
## stand on, so anything outside that can be ignored outright.
static func affects(cell: Vector3i, changed: Vector3i) -> bool:
	var info := _component(cell)
	if int(info["size"]) == 0:
		return false
	var lo: Vector3i = info["bmin"]
	var hi: Vector3i = info["bmax"]
	if changed.x < lo.x - REACH or changed.x > hi.x + REACH:
		return false
	if changed.z < lo.z - REACH or changed.z > hi.z + REACH:
		return false
	# Upward, only the neighbourhood matters. Downward, a house on stilts cares
	# about whatever it is standing on, however far below that turns out to be.
	if changed.y > hi.y + REACH or changed.y < lo.y - (MAX_STILT + 2):
		return false
	return true

## Lexicographic order on cells, so "the building's first cell" is well defined
## for any shape — that is what makes exactly one door possible.
static func _less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.x != b.x:
		return a.x < b.x
	return a.z < b.z

# -------------------------------------------------------------------- context
## Everything one house cell needs to build itself. Read once per refresh.
static func context(cell: Vector3i) -> Dictionary:
	var open_sides: Array[Vector3i] = []
	for d in SIDES:
		if not is_house(cell + d):
			open_sides.append(d)

	var has_above: bool = is_house(cell + UP)
	var has_below: bool = is_house(cell + DOWN)
	var info: Dictionary = _component(cell)

	# The door goes on the building's first cell in lexicographic order (which,
	# because y sorts first, is always on its lowest storey) and the chimney on
	# its last. One of each, for any shape — an L, a plus, a courtyard. On a
	# single-cell hut they coincide, which is fine and rather charming.
	var door_side: Vector3i = Vector3i.ZERO
	if cell == info["lo"] and not open_sides.is_empty():
		door_side = open_sides[0]

	var drop: int = support_drop(cell)
	return {
		"open_sides": open_sides,
		"roof": not has_above,
		"has_above": has_above,
		"floor": not has_below,
		"stacked": has_below,
		"door_side": door_side,
		"chimney": (not has_above) and cell == info["hi"],
		"building_size": info["size"],
		# Vertical situation: resting on something (0), or how far it has to
		# reach down, and whether that reach should be legs or a bracket.
		"support_drop": drop,
		"overhang": drop > 0 and is_overhang(cell),
	}

## A house standing entirely on its own: four walls, roof, front door, chimney.
## Used for the hotbar icon and the placement ghost, which have no cell in the
## grid yet — without this they would read whatever happens to sit at (0,0,0).
static func lone_context() -> Dictionary:
	return {
		"open_sides": SIDES.duplicate(),
		"roof": true,
		"has_above": false,
		"floor": true,
		"stacked": false,
		"door_side": SIDES[0],
		"chimney": true,
		"building_size": 1,
		"support_drop": 0,
		"overhang": false,
	}

# ---------------------------------------------------------------------- trim
## A stable number in [0,1) for the WHOLE building, not this cell.
##
## Per-cell hashes make a building noisy: every cell rolls its own dice, so one
## house ends up with a different mood on each side. Townscaper's charm is the
## opposite — a building is internally consistent and the VARIETY lives between
## buildings. Anything that should read as "this house's character" (its exact
## shade, whether it has a roof garden) must come from here; anything that is
## per-window detail can stay on `_h`.
static func building_roll(cell: Vector3i, salt: int) -> float:
	var lo: Vector3i = _component(cell)["lo"]
	return _h(lo, salt)

## A roll shared by every building in the same rough patch of island.
##
## Fully independent colours read as NOISE rather than as a town — Townscaper
## looks curated because neighbours tend to agree, with the occasional deliberate
## outlier. Quantising the anchor cell into districts gives that for free and
## costs nothing: no extra flood fill, no neighbour search.
static func district_roll(cell: Vector3i, salt: int) -> float:
	var lo: Vector3i = _component(cell)["lo"]
	return _h(Vector3i(floori(lo.x / 4.0), 0, floori(lo.z / 4.0)), salt)

## How much decoration this cell has earned. A lone hut stays plain and a real
## building gets the good stuff — growth is what makes placing another block
## feel like it did something.
static func decor_tier(cell: Vector3i) -> int:
	var n: int = int(_component(cell)["size"])
	if n >= 8:
		return 2
	if n >= 3:
		return 1
	return 0

# ------------------------------------------------------------------ surprises
## Things the building does that the player never asked for, but that make sense
## once they appear. This is where Townscaper's delight actually lives: you stack
## a few cells a certain way and the town answers with something you did not know
## was in there. Each of these is EMERGENT — a consequence of a shape, never a
## dice roll — so finding one twice in the same configuration is reliable, and
## that is what makes it feel like a discovered rule rather than a random prop.

## How many storeys tall this building is.
static func component_height(cell: Vector3i) -> int:
	var info: Dictionary = _component(cell)
	return int(info["hi"].y) - int(info["lo"].y) + 1

## A ROOF TERRACE. A rooftop that sits in the shelter of a TALLER part of the
## town becomes a flat railed terrace instead of a pitched roof — which is both
## what a real builder would do with that space and the thing that gives a
## stepped Townscaper silhouette its usable ledges.
##
## The test is deliberately about the NEIGHBOURHOOD, not the cell: a roof only
## becomes a terrace when something next to it stands over it.
## Terrace-ness belongs to the ROOF PATCH, not to the cell.
##
## Deciding it per cell is the same mistake per-cell gables were: on a 2x2 the
## cell touching the tower became a flat terrace while the one behind it kept a
## pitched roof, so the top of one building came out as a patchwork of decks and
## gables that plainly refused to merge.
##
## The whole connected run of roof cells at this level is therefore decided
## together: if ANY of them stands in the shelter of a taller part, they ALL
## become one continuous deck. One roof area, one answer.
static var _terrace_version := -1
static var _terrace_cache: Dictionary = {}

## A stilted house whose legs land exactly on this cell's top: a house cell
## straight above at height >= 2 with clear air the whole way between. A
## pitched roof under those legs buries the posts and the footpads in its
## slope, so the roof patch flattens into a terrace and the legs stand ON it.
static func bears_stilts(cell: Vector3i) -> bool:
	for k in range(2, MAX_STILT + 1):
		var above: Vector3i = cell + UP * k
		if is_house(above):
			return support_drop(above) == k - 1
		if _solid(above):
			return false
	return false

static func is_terrace(cell: Vector3i) -> bool:
	if not is_roof_cell(cell):
		return false
	if GridManager.version != _terrace_version:
		_terrace_version = GridManager.version
		_terrace_cache = {}
	if _terrace_cache.has(cell):
		return _terrace_cache[cell]

	# Flood the contiguous roof surface at this height.
	var patch: Dictionary = {}
	var queue: Array[Vector3i] = [cell]
	patch[cell] = true
	var sheltered := false
	while not queue.is_empty() and patch.size() < MAX_BUILDING:
		var c: Vector3i = queue.pop_back()
		if bears_stilts(c):
			sheltered = true              # a stilted house stands ON this roof
		for d in SIDES:
			if is_house(c + d + UP):
				sheltered = true          # something taller stands over this patch
			var n: Vector3i = c + d
			if not patch.has(n) and is_roof_cell(n):
				patch[n] = true
				queue.append(n)

	for c in patch:
		_terrace_cache[c] = sheltered
	return sheltered

## A SPIRE: build a tower at least four storeys tall## A SPIRE: build a tower at least four storeys tall and no more than one cell
## thick and it stops being a house with a roof and becomes a landmark. The
## reward for building UP rather than out, and the one piece of the town that is
## visible from anywhere on the island.
## The roof patch this cell belongs to: the contiguous run of roof cells at this
## height. Anything that describes the SHAPE OF A TOP — terrace, spire — has to
## be answered for the patch, or two neighbouring cells give different answers
## and the top comes out as a patchwork.
static func roof_patch(cell: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if not is_roof_cell(cell):
		return out
	var seen: Dictionary = {cell: true}
	var queue: Array[Vector3i] = [cell]
	while not queue.is_empty() and out.size() < MAX_BUILDING:
		var c: Vector3i = queue.pop_back()
		out.append(c)
		for d in SIDES:
			var n: Vector3i = c + d
			if not seen.has(n) and is_roof_cell(n):
				seen[n] = true
				queue.append(n)
	return out

static func has_spire(cell: Vector3i) -> bool:
	if not is_roof_cell(cell) or component_height(cell) < 4 or is_terrace(cell):
		return false
	# A spire crowns a TOWER, so the top has to be a single cell. The old test
	# counted this cell's own neighbours and allowed one — which on a two-wide
	# top is true of BOTH cells, so a broad tower grew two spires side by side.
	# Asking the patch instead makes "is this a tower top" a property of the top.
	return roof_patch(cell).size() == 1

## A COURTYARD: ring house cells around an empty one and the gap becomes a
## planted courtyard rather than a hole. Returns the direction to the enclosed
## cell, or ZERO. Ownership goes to the lexicographically first of the four
## surrounding cells so the courtyard is built exactly once.
static func courtyard_dir(cell: Vector3i) -> Vector3i:
	for d in SIDES:
		var gap: Vector3i = cell + d
		if GridManager.has_block(gap):
			continue
		var ring: Array[Vector3i] = []
		var enclosed := true
		for e in SIDES:
			var n: Vector3i = gap + e
			if not is_house(n):
				enclosed = false
				break
			ring.append(n)
		if not enclosed:
			continue
		var owner: Vector3i = ring[0]
		for r in ring:
			if _less(r, owner):
				owner = r
		if owner == cell:
			return d
	return Vector3i.ZERO

## BUNTING: leave exactly one cell of air between two rooftops at the same height
## and a line of little flags gets strung across it. Rewards building a street
## with a gap in it instead of one solid block, and it is the detail that makes a
## town look inhabited rather than constructed.
static func bunting_dir(cell: Vector3i) -> Vector3i:
	if not is_roof_cell(cell):
		return Vector3i.ZERO
	for d in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
		var gap: Vector3i = cell + d
		var far: Vector3i = cell + d * 2
		if GridManager.has_block(gap):
			continue
		if is_roof_cell(far) and roof_top_height(far) == roof_top_height(cell):
			return d          # only the NEAR cell owns it, so the line is drawn once
	return Vector3i.ZERO

## Windows for one exposed face: 0-2 of them, biased so ground floors (which
## usually carry the door) stay plainer than the storeys above. Returns local
## X offsets across the face.
static func window_offsets(cell: Vector3i, side: Vector3i, is_door_side: bool) -> Array[float]:
	if is_door_side:
		return []
	var r: float = _h(cell, side.x * 31 + side.z * 17)
	if r < 0.18:
		return []                      # blank wall — variety, not every face glazed
	if r < 0.62:
		return [0.0]
	return [-0.21, 0.21]

## A small balcony on `side`: an upper floor with something under it to rest on.
##
## This was 22% and only ever read as "almost never" — a whole town could go by
## without one. Balconies are one of the things people actually look for, so an
## upper storey now grows them about half the time.
static func has_balcony(cell: Vector3i, side: Vector3i, stacked: bool) -> bool:
	return stacked and _h(cell, 91 + side.x * 7 + side.z * 13) < 0.48

## A cloth awning over a GROUND-floor window: shop-front warmth at street level,
## and never on an upper storey where it would look like a mistake.
static func has_awning(cell: Vector3i, side: Vector3i, ground: bool) -> bool:
	return ground and decor_tier(cell) >= 1 and _h(cell, 41 + side.x * 5 + side.z * 11) < 0.38

## Shutters flanking a window. A building either uses shutters or it doesn't —
## rolled per BUILDING so one house doesn't have them on half its windows.
static func has_shutters(cell: Vector3i) -> bool:
	return building_roll(cell, 7) < 0.45

## The side a dormer should face, or ZERO. A dormer only makes sense where the
## roof actually slopes DOWN to an outside edge — pushing one out of a roof that
## continues into the neighbouring cell would bury it in the next roof along.
static func dormer_side(cell: Vector3i) -> Vector3i:
	if decor_tier(cell) < 1 or not is_roof_cell(cell):
		return Vector3i.ZERO
	if roof_level(cell.x * 2, cell.z * 2, cell.y) < 1:
		return Vector3i.ZERO          # eaves-height cell: no slope to sit in
	if _h(cell, 77) > 0.55:
		return Vector3i.ZERO
	# Face the first open direction, so the window looks out over the town.
	for d in SIDES:
		if not is_roof_cell(cell + d):
			return d
	return Vector3i.ZERO

## Potted plants on a roof: only on real buildings, and only where the roof is
## flat enough to stand a pot on — the top of a wide building, not a narrow ridge.
static func has_roof_garden(cell: Vector3i) -> bool:
	if decor_tier(cell) < 2 or not is_roof_cell(cell):
		return false
	if roof_level(cell.x * 2, cell.z * 2, cell.y) < ROOF_LEVELS:
		return false
	return building_roll(cell, 23) < 0.6

## A planter trough at the foot of an exposed ground-floor wall. Cheap, and it is
## what stops a building from meeting the grass in a hard line.
static func has_planter(cell: Vector3i, side: Vector3i, ground: bool) -> bool:
	return ground and _h(cell, 61 + side.x * 3 + side.z * 17) < 0.42
