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

	var seen: Dictionary = {}
	var queue: Array[Vector3i] = [cell]
	seen[cell] = true
	var lo: Vector3i = cell
	var hi: Vector3i = cell
	while not queue.is_empty() and seen.size() < MAX_BUILDING:
		var c: Vector3i = queue.pop_back()
		if _less(c, lo):
			lo = c
		if _less(hi, c):
			hi = c
		for d in GridManager.DIRECTIONS:
			var n: Vector3i = c + d
			if not seen.has(n) and is_house(n):
				seen[n] = true
				queue.append(n)

	var info := {"lo": lo, "hi": hi, "size": seen.size(), "capped": seen.size() >= MAX_BUILDING}
	# Every cell of the building gets the same answer, so one flood serves them all.
	for c in seen:
		_cache[c] = info
	return info

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

	return {
		"open_sides": open_sides,
		"roof": not has_above,
		"floor": not has_below,
		"stacked": has_below,
		"door_side": door_side,
		"chimney": (not has_above) and cell == info["hi"],
		"building_size": info["size"],
	}

## A house standing entirely on its own: four walls, roof, front door, chimney.
## Used for the hotbar icon and the placement ghost, which have no cell in the
## grid yet — without this they would read whatever happens to sit at (0,0,0).
static func lone_context() -> Dictionary:
	return {
		"open_sides": SIDES.duplicate(),
		"roof": true,
		"floor": true,
		"stacked": false,
		"door_side": SIDES[0],
		"chimney": true,
		"building_size": 1,
	}

# ---------------------------------------------------------------------- trim
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

## True when this cell should grow a small balcony on `side`: an upper floor with
## something under it to rest on, and only sometimes, so they read as accents.
static func has_balcony(cell: Vector3i, side: Vector3i, stacked: bool) -> bool:
	return stacked and _h(cell, 91 + side.x * 7 + side.z * 13) < 0.22
