class_name HouseShape
extends RefCounted

## Townscaper's trick, on our grid: the player never places a *house*, they place
## a house CELL, and the building assembles itself from what's around it. Every
## piece below is decided purely from the six neighbours plus a stable hash of the
## cell, which is what makes it feel designed rather than stamped:
##
##   wall     — only on faces with no house neighbour (shared walls vanish, so two
##              cells side by side read as one wide room, not two huts)
##   roof     — only when nothing sits on top; the ridge runs along whichever
##              horizontal axis the building is LONGER on, so a 3x1 terrace gets
##              one continuous ridge instead of three competing little gables
##   door     — one per building: the ground-level cell that has no neighbour to
##              -X and none to -Z, i.e. the building's near corner
##   chimney  — the opposite corner of the roof (+X/+Z free), so door and chimney
##              land on different cells on anything bigger than a single hut
##   balcony  — upper floor, exposed face, with a house below to sit on
##
## Everything is O(1) in the neighbour lookup — no flood fill, no component
## search — which is what lets a cell re-derive itself on every grid change the
## same way `PipeRouting` does for bamboo, without cost growing with build size.
## It is also fully DETERMINISTIC: `_h()` hashes the cell, never randf(), so a
## house looks identical after save/load and after any rebuild.

const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)

## The four horizontal faces, in a fixed order so "first exposed face" is stable.
const SIDES: Array[Vector3i] = [
	Vector3i(0, 0, -1),   # north / -Z
	Vector3i(1, 0, 0),    # east
	Vector3i(0, 0, 1),    # south
	Vector3i(-1, 0, 0),   # west
]

static func is_house(cell: Vector3i) -> bool:
	var b: BlockData = GridManager.get_block(cell)
	return b != null and b.type == BlockData.Type.HOUSE

## Stable per-cell pseudo-random in [0,1). Same cell always gives the same value,
## so window counts and trim choices survive a reload.
static func _h(cell: Vector3i, salt: int) -> float:
	var n: int = hash(Vector3i(cell.x * 73856093, cell.y * 19349663, cell.z * 83492791)) ^ (salt * 2654435761)
	return float(absi(n) % 100003) / 100003.0

## How far the building runs along `axis` (Vector3i unit) from this cell, both
## directions — used to pick the ridge direction and to stretch trim.
static func _run(cell: Vector3i, axis: Vector3i) -> int:
	var n := 1
	for s in [1, -1]:
		var p: Vector3i = cell + axis * s
		while is_house(p):
			n += 1
			p += axis * s
	return n

## Everything one house cell needs to build itself. Read once per refresh.
static func context(cell: Vector3i) -> Dictionary:
	var open_sides: Array[Vector3i] = []
	for d in SIDES:
		if not is_house(cell + d):
			open_sides.append(d)

	var has_above: bool = is_house(cell + UP)
	var has_below: bool = is_house(cell + DOWN)
	var run_x: int = _run(cell, Vector3i(1, 0, 0))
	var run_z: int = _run(cell, Vector3i(0, 0, 1))

	# Ridge along the longer run. Ties go to X so a square block is consistent
	# across all its cells (a per-cell coin flip would give a broken zigzag roof).
	var ridge_x: bool = run_x >= run_z

	# Near corner (nothing to -X, nothing to -Z) at the bottom of the building.
	var is_corner_near: bool = not is_house(cell + Vector3i(-1, 0, 0)) \
		and not is_house(cell + Vector3i(0, 0, -1))
	# Far corner, for the chimney.
	var is_corner_far: bool = not is_house(cell + Vector3i(1, 0, 0)) \
		and not is_house(cell + Vector3i(0, 0, 1))

	var door_side: Vector3i = Vector3i.ZERO
	if not has_below and is_corner_near and not open_sides.is_empty():
		door_side = open_sides[0]

	return {
		"open_sides": open_sides,
		"roof": not has_above,
		"ridge_x": ridge_x,
		"floor": not has_below,
		"stacked": has_below,
		"door_side": door_side,
		"chimney": (not has_above) and is_corner_far,
		"run_x": run_x,
		"run_z": run_z,
	}

## A house standing entirely on its own: four walls, roof, front door, chimney.
## Used for the hotbar icon and the placement ghost, which have no cell in the
## grid yet — without this they would read whatever happens to sit at (0,0,0).
static func lone_context() -> Dictionary:
	return {
		"open_sides": SIDES.duplicate(),
		"roof": true,
		"ridge_x": true,
		"floor": true,
		"stacked": false,
		"door_side": SIDES[0],
		"chimney": true,
		"run_x": 1,
		"run_z": 1,
	}

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

## Lantern hanging by the door — every doorway gets one, it's the warm little
## detail that sells "someone lives here" at night.
static func lantern_side(ctx: Dictionary) -> Vector3i:
	return ctx["door_side"]
