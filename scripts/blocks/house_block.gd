extends StaticBody3D

## A house CELL that builds itself into part of a building. All the "what goes
## where" logic lives in `HouseShape` (read that first); this file only turns that
## decision into geometry, the same split `pipe_block` uses with `PipeRouting`.
##
## The Townscaper feeling comes from what we DON'T draw: a wall between two house
## cells is skipped, so a row reads as one long house with one long roof rather
## than three sheds in a line. Because every cell re-derives itself whenever a
## neighbour changes, knocking a hole in a terrace instantly grows the two new
## end walls, gables and all.

const WALL_T := 0.07          # plaster thickness
## Ridge height above the cell top. At 0.42 the pitch was so shallow that roofs
## read as flat dark slabs from a normal camera angle; 0.58 makes them read as
## roofs without turning the town into spires.
const ROOF_H := 0.58
const ROOF_OVER := 0.11       # eaves overhang past the wall

## The four original palettes were all pale plaster over a red-brown roof, so
## whichever one a building picked it came out looking the same — a test town
## rendered as one uniform grey block, which is exactly why placing houses felt
## flat. These seven carry real separation in BOTH hue and value while staying
## inside the clay/pastel family, so a street reads as a street.
const PALETTES: Array[Dictionary] = [
	{"wall": Color("f4ead6"), "roof": Color("b8563c"), "trim": Color("8a6a4a")},   # cream + terracotta
	{"wall": Color("bcd4dd"), "roof": Color("5f6f86"), "trim": Color("6d7b84")},   # sea blue + slate
	{"wall": Color("f3cbc2"), "roof": Color("9c4a63"), "trim": Color("8a5f52")},   # blossom + plum
	{"wall": Color("cfd9b6"), "roof": Color("7d6a3a"), "trim": Color("6f7a5c")},   # sage + olive
	{"wall": Color("f2d49a"), "roof": Color("a8552f"), "trim": Color("8a6134")},   # ochre + rust
	{"wall": Color("d8c8e0"), "roof": Color("6a5578"), "trim": Color("7a6a86")},   # lilac + aubergine
	{"wall": Color("e8e4dd"), "roof": Color("4f5f5a"), "trim": Color("77776f")},   # chalk + pine
]

## Awning cloth. The one saturated accent on an otherwise quiet building, so a
## street reads as lived-in rather than as a colour swatch.
const ACCENT := Color("e07a5f")
const GLASS_DAY := Color("6f8794")
const GLASS_NIGHT := Color("ffd79a")
const SNOW_THEME := 2
const NIGHT_THEME := 3
const SNOW := Color("f4f8fb")

## The map theme is picked on the menu BEFORE main.tscn loads, so reading it at
## build time is enough — houses never have to survive a live theme swap. Plaster
## shifts to sit under each sky (warm under autumn, cool and dim at night) rather
## than staying one bright cream that fights the palette.
const THEME_TINT: Array = [
	{"mix": Color(1, 1, 1), "amount": 0.0},          # Spring — as authored
	{"mix": Color("ffb970"), "amount": 0.16},        # Autumn — warm low sun
	{"mix": Color("dceaf5"), "amount": 0.22},        # Snow — cold and washed out
	{"mix": Color("3d4670"), "amount": 0.42},        # Night — deep blue shadow
]

## Assigning this is what promotes the instance from "loose preview" to "a cell
## in the grid". PlacementController and SaveManager both add the node to the
## tree BEFORE they know the cell, so _ready() would otherwise build a house for
## whatever sits at (0,0,0); the setter rebuilds the moment the real cell lands.
var grid_cell: Vector3i:
	set(value):
		grid_cell = value
		_placed = true
		if is_inside_tree():
			refresh_shape()

var _placed: bool = false
var _visual: Node3D
var _batch: MeshBatch
var _base_palette: int = 0
var _palette: Dictionary = PALETTES[0]

## The player's variant picks a FAMILY; the building picks its own exact shade
## within it. Without this a street of same-variant houses is one flat block of
## identical grey — which is what a test town actually looked like, and the
## reason placing houses stopped being interesting. Townscaper's whole charm is
## that no two buildings match, so the variety has to come from the BUILDING,
## not from the player having to remember to cycle the variant every time.
func _resolve_palette() -> void:
	var base: Dictionary = PALETTES[_base_palette]
	if not _placed:
		_palette = base
		return
	# Blending 34% between two pale palettes was invisible — a test town came out
	# as one uniform grey. A building now takes a WHOLE palette of its own and
	# then shifts it, so neighbours are obviously different houses.
	var pick: int = int(HouseShape.building_roll(grid_cell, 3) * PALETTES.size()) % PALETTES.size()
	var chosen: Dictionary = PALETTES[pick]
	var light: float = (HouseShape.building_roll(grid_cell, 5) - 0.5) * 0.26
	var roof_light: float = (HouseShape.building_roll(grid_cell, 11) - 0.5) * 0.34
	# The player's variant still leads: it is mixed back in so a deliberately
	# chosen colour stays recognisable across the street rather than being
	# overwritten by the building's own roll.
	_palette = {
		"wall": (chosen["wall"] as Color).lerp(base["wall"], 0.35).lightened(light),
		"roof": (chosen["roof"] as Color).lerp(base["roof"], 0.35).lightened(roof_light),
		"trim": (chosen["trim"] as Color).lerp(base["trim"], 0.5),
	}
var _glow: Array[StandardMaterial3D] = []
var _phase: float = randf() * TAU

func _ready() -> void:
	GridManager.block_placed.connect(_on_grid_changed)
	GridManager.block_removed.connect(_on_grid_changed)
	refresh_shape()

## Wider than the usual 6-neighbour test: HouseShape measures how far the
## building RUNS along X and Z to pick the ridge direction, so a cell added
## several steps down the same row can flip this cell's roof. Any house change
## sharing a row or column with us (same y) has to re-trigger the rebuild.
func _on_grid_changed(cell: Vector3i) -> void:
	if not _placed:
		return
	if cell == grid_cell:
		refresh_shape()
		return
	var d: Vector3i = cell - grid_cell
	if d.y == 0 and (d.x == 0 or d.z == 0):
		refresh_shape()
	elif absi(d.x) <= 1 and absi(d.y) <= 1 and absi(d.z) <= 1:
		refresh_shape()

func apply_variant(v: Dictionary) -> void:
	_base_palette = int(v.get("palette", 0)) % PALETTES.size()
	if is_inside_tree():
		refresh_shape()

# ----------------------------------------------------------------- assembly
func refresh_shape() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	_glow.clear()
	_visual = Node3D.new()
	add_child(_visual)

	var ctx: Dictionary = HouseShape.context(grid_cell) if _placed else HouseShape.lone_context()
	_resolve_palette()
	_batch = MeshBatch.new()
	var wall_col: Color = _tint(_palette["wall"])
	var trim_col: Color = _tint(_palette["trim"])

	if ctx["floor"]:
		_batch.box(Vector3(1.02, 0.09, 1.02), Vector3(0, -0.5, 0), trim_col)   # stone footing

	for side in ctx["open_sides"]:
		_build_face(side, ctx, wall_col, trim_col)

	_build_underside(ctx, trim_col)
	if ctx["has_above"]:
		_build_storey_band(ctx, trim_col)
	if ctx["roof"]:
		_build_roof(ctx)
	if ctx["chimney"]:
		_build_chimney(trim_col)
	# Only a real building earns a roof garden, and only where its roof is flat
	# enough on top to stand a pot on — a narrow ridge would just float them.
	if HouseShape.has_roof_garden(grid_cell):
		_build_roof_garden(trim_col)

	# Everything above went into ONE mesh, grouped by colour: four or five draw
	# calls per cell instead of one per plank.
	var mi := MeshInstance3D.new()
	mi.mesh = _batch.build(_material_for)
	_visual.add_child(mi)
	_batch = null

	# Only night houses breathe; every other map leaves the panes flat, so a big
	# town costs nothing per frame.
	set_process(MapThemes.current == NIGHT_THEME and not _glow.is_empty())

## One exposed wall: plaster panel, then whatever that face earned — a door, some
## windows, maybe a balcony.
func _build_face(side: Vector3i, ctx: Dictionary, wall_col: Color, trim_col: Color) -> void:
	var horiz := Vector3(float(side.z), 0.0, float(-side.x))   # along the face
	var out := Vector3(float(side.x), 0.0, float(side.z))
	_batch.box(_face_size(side, 1.0, WALL_T), out * (0.5 - WALL_T * 0.5), wall_col)

	var is_door: bool = ctx["door_side"] == side
	var ground: bool = not bool(ctx["stacked"])
	if is_door:
		_build_door(out, horiz, trim_col)
	for ox in HouseShape.window_offsets(grid_cell, side, is_door):
		_build_window(out, horiz * ox, trim_col, ground)
	if HouseShape.has_balcony(grid_cell, side, ctx["stacked"]):
		_build_balcony(out, horiz, trim_col)
	# Street level meets the grass with something growing, not a hard edge.
	if HouseShape.has_planter(grid_cell, side, ground) and not is_door:
		_build_planter(out, horiz, trim_col)

## Size of a slab covering one face: full across, thin through.
func _face_size(side: Vector3i, span: float, thick: float) -> Vector3:
	return Vector3(thick, span, span) if side.x != 0 else Vector3(span, span, thick)

func _build_door(out: Vector3, horiz: Vector3, trim_col: Color) -> void:
	_batch.box(_slab(out, 0.40, 0.66), out * 0.5 + Vector3(0, -0.17, 0), trim_col)
	_batch.box(_slab(out, 0.30, 0.56), out * 0.52 + Vector3(0, -0.2, 0), _dark())
	# Doorstep + a paper lantern on a bracket: the "someone lives here" detail.
	_batch.box(_slab(out, 0.44, 0.06), out * 0.56 + Vector3(0, -0.47, 0), trim_col)
	_batch.box(Vector3(0.12, 0.16, 0.12), out * 0.46 + horiz * 0.3 + Vector3(0, 0.16, 0), _glass_col())

func _build_window(out: Vector3, offset: Vector3, trim_col: Color, ground: bool = false) -> void:
	var centre: Vector3 = out * 0.5 + offset + Vector3(0, 0.08, 0)
	_batch.box(_slab(out, 0.30, 0.30), centre, trim_col)
	_batch.box(_slab(out, 0.22, 0.22), centre + out * 0.03, _glass_col())
	# Flower box under the sill — small, but it's what makes a wall look lived-in.
	_batch.box(_slab(out, 0.26, 0.07), centre + out * 0.05 + Vector3(0, -0.19, 0), trim_col)
	_batch.box(_slab(out, 0.22, 0.06), centre + out * 0.06 + Vector3(0, -0.14, 0), _tint(Color("8cb369")))
	var across := Vector3(absf(out.z), 0.0, absf(out.x))
	# Shutters are a per-BUILDING trait, so a house either has them everywhere or
	# nowhere — half-shuttered walls look like an unfinished job, not a style.
	if HouseShape.has_shutters(grid_cell):
		for s2 in [-1.0, 1.0]:
			_batch.box(_slab(out, 0.08, 0.28), centre + out * 0.02 + across * (0.19 * s2), _dark())
	# Ground-floor awning: shop-front warmth exactly where a passer-by would see it.
	if ground and HouseShape.has_awning(grid_cell, _side_of(out), true):
		# Use the same _slab helper as every other wall piece. A hand-rolled size
		# vector here produced a huge flat sheet jutting out of the building —
		# the face axes are easy to get wrong when out can point along X or Z.
		var lip: Vector3 = centre + out * 0.12 + Vector3(0, 0.23, 0)
		_batch.box(_slab(out, 0.34, 0.05) + out.abs() * 0.16, lip, _tint(ACCENT))
		_batch.box(_slab(out, 0.34, 0.06), centre + out * 0.04 + Vector3(0, 0.2, 0), _tint(ACCENT).darkened(0.12))

## Which of the four sides a face normal belongs to.
func _side_of(out: Vector3) -> Vector3i:
	return Vector3i(roundi(out.x), 0, roundi(out.z))

## A trough of greenery along the foot of the wall.
func _build_planter(out: Vector3, horiz: Vector3, trim_col: Color) -> void:
	var at: Vector3 = out * 0.56 + Vector3(0, -0.44, 0)
	_batch.box(_slab(out, 0.5, 0.14) + out.abs() * 0.1, at, trim_col)
	_batch.box(_slab(out, 0.44, 0.1) + out.abs() * 0.08, at + Vector3(0, 0.08, 0), _tint(Color("8cb369")))
	for s2 in [-0.14, 0.13]:
		_batch.box(Vector3(0.07, 0.16, 0.07), at + horiz * s2 + Vector3(0, 0.16, 0), _tint(Color("7aa85c")))

func _build_balcony(out: Vector3, horiz: Vector3, trim_col: Color) -> void:
	var base: Vector3 = out * 0.62 + Vector3(0, -0.24, 0)
	_batch.box(_slab(out, 0.62, 0.06) + out.abs() * 0.24, base, trim_col)
	for s in [-1.0, 1.0]:
		_batch.box(Vector3(0.05, 0.2, 0.05), base + horiz * 0.26 * s + Vector3(0, 0.13, 0), trim_col)
	_batch.box(_slab(out, 0.58, 0.05) + out.abs() * 0.2, base + Vector3(0, 0.24, 0), trim_col)

## Slab lying flat against a face: `w` across, `h` tall, paper-thin through.
func _slab(out: Vector3, w: float, h: float) -> Vector3:
	return Vector3(0.04, h, w) if absf(out.x) > 0.5 else Vector3(w, h, 0.04)

## Glass is picked out by COLOUR, not by material: the batcher groups by colour,
## so windows and door lanterns land in one surface that `_material_for` then
## makes emissive. That's what keeps a lit night house at one extra draw call.
func _glass_col() -> Color:
	return GLASS_NIGHT if MapThemes.current == NIGHT_THEME else GLASS_DAY

## One material per batched colour. Glass at night becomes the emitter the
## windows breathe through.
func _material_for(col: Color) -> StandardMaterial3D:
	var m := MeshFit.flat(col)
	if MapThemes.current == NIGHT_THEME and col.is_equal_approx(GLASS_NIGHT):
		m.emission_enabled = true
		m.emission = GLASS_NIGHT
		m.emission_energy_multiplier = 1.0
		_glow.append(m)
	return m

# ---------------------------------------------------------------- underneath
## What a cell standing in mid-air does about it. Without this, a house placed on
## the second storey with nothing under it simply floats, which reads as a bug
## even in a game with no gravity.
##
## Two different situations, two different answers, because they look wrong if
## swapped:
##   a hut with nothing beside it     -> LEGS: posts down to whatever is below
##   a storey jutting past the one    -> CORBEL: a diagonal brace back into the
##   below it                            wall it grew out of, not a pillar
func _build_underside(ctx: Dictionary, trim_col: Color) -> void:
	var drop: int = int(ctx["support_drop"])
	if drop <= 0:
		return
	if bool(ctx["overhang"]):
		_build_corbels(trim_col)
	else:
		_build_stilts(drop, trim_col)

## Four corner posts with a cross-brace, reaching down to the first solid thing
## below (or the island surface). Corners shared with another airborne cell are
## skipped by HouseShape.owns_corner, so a raised 2x2 platform stands on four
## posts, not sixteen stacked in the same holes.
func _build_stilts(drop: int, trim_col: Color) -> void:
	# owns_corner walks the grid downward for four candidate cells, so resolve
	# the four corners ONCE and reuse the answer for the pads.
	var mine: Array[Vector2i] = []
	for ax in [-1, 1]:
		for az in [-1, 1]:
			if HouseShape.owns_corner(grid_cell, ax, az):
				mine.append(Vector2i(ax, az))
	if mine.is_empty():
		return

	# Posts wear the plain trim colour on purpose: a slightly darker shade would
	# be its own colour, and MeshBatch groups by colour, so it would cost an
	# extra draw call on every raised cell for a difference nobody can see.
	var h: float = float(drop)
	var mid: float = -0.5 - h * 0.5
	for c in mine:
		_batch.box(Vector3(0.13, h, 0.13), Vector3(c.x * 0.34, mid, c.y * 0.34), trim_col)
		# Footpad, so a post lands on something instead of stopping in mid-air.
		_batch.box(Vector3(0.2, 0.06, 0.2), Vector3(c.x * 0.34, -0.5 - h + 0.03, c.y * 0.34), trim_col)
	# A brace partway down: legs this long read as scaffolding without one.
	if h >= 1.6:
		for on_x in [true, false]:
			var size: Vector3 = Vector3(0.78, 0.07, 0.07) if on_x else Vector3(0.07, 0.07, 0.78)
			for s in [-1.0, 1.0]:
				var off: Vector3 = Vector3(0, 0, 0.34 * s) if on_x else Vector3(0.34 * s, 0, 0)
				_batch.box(size, Vector3(0, mid, 0) + off, trim_col)

## Diagonal brackets under a cantilevered storey, one per supported neighbour it
## juts out from — the joinery that makes an overhang look deliberate.
func _build_corbels(trim_col: Color) -> void:
	for d in HouseShape.corbel_sides(grid_cell):
		var out := Vector3(float(d.x), 0.0, float(d.z))
		var along := Vector3(float(d.z), 0.0, float(-d.x))
		for s in [-0.3, 0.3]:
			var at: Vector3 = -out * 0.34 + along * s + Vector3(0, -0.62, 0)
			var size := Vector3(0.42, 0.1, 0.12) if absf(out.x) > 0.5 else Vector3(0.12, 0.1, 0.42)
			var tilt := Basis(Vector3(0, 0, 1), 0.6 * signf(out.x)) if absf(out.x) > 0.5 \
				else Basis(Vector3(1, 0, 0), -0.6 * signf(out.z))
			_batch.box(size, at, trim_col, tilt)
	# A sill under the overhanging floor so the corbels have something to carry.
	_batch.box(Vector3(0.92, 0.08, 0.92), Vector3(0, -0.52, 0), trim_col)

## Belt course at the top of a wall that has another storey above it. A tower
## without one is a single tall box; with one it reads as floors stacked up.
func _build_storey_band(ctx: Dictionary, trim_col: Color) -> void:
	for side in ctx["open_sides"]:
		var out := Vector3(float(side.x), 0.0, float(side.z))
		var size := Vector3(0.08, 0.07, 1.04) if absf(out.x) > 0.5 else Vector3(1.04, 0.07, 0.08)
		_batch.box(size, out * 0.5 + Vector3(0, 0.46, 0), trim_col)

# --------------------------------------------------------------------- roof
## The roof is not this cell's own shape — it is this cell's PATCH of a surface
## that belongs to the whole building. See HouseShape for why: per-cell gables
## turn anything wider than one cell into a row of sheds.
##
## Nine samples on a half-cell grid (corners, edge midpoints, centre), each given
## a height by HouseShape.roof_level(), then four quads between them. Neighbouring
## cells sample the SAME shared points, so the patches meet exactly — a 3-cell row
## grows one continuous ridge, a 2x2 grows one pyramid, an L grows a valley, and
## every end hips itself, all without the cells talking to each other.
##
## Emitted as a solid slab (top surface, underside, fascia around the rim) because
## an overhanging single surface is see-through from below.
const ROOF_STEP: Array[float] = [0.0, ROOF_H, ROOF_H * 1.5]   # keep in step with HouseShape.ROOF_RISE
const ROOF_THICK := 0.07

func _build_roof(_ctx: Dictionary) -> void:
	var col: Color = _tint(_palette["roof"])
	var top: Array = _roof_samples(0.0)
	_emit_roof_surface(top, col, false)
	# Underside, reversed so it faces down, plus a rim so the eaves have an edge.
	var under: Array = _roof_samples(-ROOF_THICK)
	_emit_roof_surface(under, _dark(), true)
	_emit_roof_rim(top, under, _dark())
	if MapThemes.current == SNOW_THEME:
		# Snow rides ON the roof, inset so the tile edge still shows at the eaves —
		# a fully coated roof turns the whole village into white blobs.
		_emit_roof_surface(_roof_samples(0.035, 0.13), SNOW, false)

## The 3x3 sample grid for this cell, as world-local positions.
## `lift` raises the whole sheet; `inset` pulls the outer ring inward (used for
## the snow layer). Outer samples push OUT by the eaves overhang, but only on
## sides where the roof actually ends — pushing out into a neighbour would make
## the two cells' eaves intersect and z-fight down the whole terrace.
func _roof_samples(lift: float, inset: float = 0.0) -> Array:
	var pts: Array = []
	for iz in 3:
		var row: Array = []
		for ix in 3:
			var a: int = ix - 1
			var b: int = iz - 1
			var x: float = a * 0.5
			var z: float = b * 0.5
			if a != 0 and not HouseShape.is_roof_cell(grid_cell + Vector3i(a, 0, 0)):
				x = a * (0.5 + ROOF_OVER - inset)
			if b != 0 and not HouseShape.is_roof_cell(grid_cell + Vector3i(0, 0, b)):
				z = b * (0.5 + ROOF_OVER - inset)
			var level: int = HouseShape.roof_level(grid_cell.x * 2 + a, grid_cell.z * 2 + b, grid_cell.y)
			row.append(Vector3(x, 0.5 + ROOF_STEP[level] + lift, z))
		pts.append(row)
	return pts

func _emit_roof_surface(p: Array, col: Color, flip: bool) -> void:
	for iz in 2:
		for ix in 2:
			var a: Vector3 = p[iz][ix]
			var b: Vector3 = p[iz][ix + 1]
			var c: Vector3 = p[iz + 1][ix + 1]
			var d: Vector3 = p[iz + 1][ix]
			if flip:
				_batch.quad(d, c, b, a, col)
			else:
				_batch.quad(a, b, c, d, col)

## Fascia band closing the gap between the top sheet and its underside, but only
## along edges where the roof really stops — an interior edge is shared with the
## neighbour's slab and capping it would bury a wall inside the roof.
func _emit_roof_rim(top: Array, under: Array, col: Color) -> void:
	var edges := [
		[Vector3i(0, 0, -1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]],
		[Vector3i(0, 0, 1), [Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]],
		[Vector3i(-1, 0, 0), [Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0)]],
		[Vector3i(1, 0, 0), [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]],
	]
	for e in edges:
		if HouseShape.is_roof_cell(grid_cell + (e[0] as Vector3i)):
			continue
		var idx: Array = e[1]
		for i in idx.size() - 1:
			var m: Vector2i = idx[i]
			var n: Vector2i = idx[i + 1]
			_batch.quad(top[m.y][m.x], top[n.y][n.x], under[n.y][n.x], under[m.y][m.x], col)

## Pots and a little tree on the flat of a big roof. This is the payoff for
## building UP and WIDE rather than sprawling — the reward has to be visible from
## the normal play camera, so it sits on the highest surface the building has.
func _build_roof_garden(trim_col: Color) -> void:
	var top: float = 0.5 + ROOF_STEP[HouseShape.ROOF_LEVELS] + 0.02
	var leaf: Color = _tint(Color("8cb369"))
	for i in 3:
		var a: float = HouseShape.building_roll(grid_cell, 31 + i) * TAU
		var at := Vector3(cos(a) * 0.22, top, sin(a) * 0.22)
		_batch.box(Vector3(0.15, 0.12, 0.15), at + Vector3(0, 0.06, 0), trim_col)
		_batch.box(Vector3(0.11, 0.16, 0.11), at + Vector3(0, 0.19, 0), leaf)
		if i == 0:
			_batch.box(Vector3(0.05, 0.2, 0.05), at + Vector3(0, 0.3, 0), _dark())
			_batch.box(Vector3(0.26, 0.2, 0.26), at + Vector3(0, 0.44, 0), leaf)

func _build_chimney(trim_col: Color) -> void:
	var at := Vector3(0.26, 0.5 + ROOF_H * 0.55, 0.26)
	_batch.box(Vector3(0.18, 0.46, 0.18), at, trim_col)
	_batch.box(Vector3(0.24, 0.06, 0.24), at + Vector3(0, 0.25, 0), _dark())
	_add_smoke(at + Vector3(0, 0.3, 0))

## Slow chimney smoke. Amount goes through QualityManager so the web LITE build
## halves it — a street of houses is the one thing here that can multiply
## particle systems, so this must scale with the profile like everything else.
func _add_smoke(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = QualityManager.particles(10)
	p.lifetime = 3.4
	p.position = at
	p.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.18
	pm.initial_velocity_max = 0.34
	pm.gravity = Vector3(0.05, 0.12, 0.0)      # drifts up and leans on the breeze
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.color = Color(0.93, 0.92, 0.9, 0.5)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.95, 0.94, 0.92, 0.42)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = qm
	p.draw_pass_1 = q
	_visual.add_child(p)

# ------------------------------------------------------------------ helpers
## One shared dark shade for door panel, ridge cap and chimney cap. They used to
## be three separate `darkened()` values, which the batcher can only read as
## three different colours — i.e. three extra draw calls per house for a
## difference nobody can see at play distance.
func _dark() -> Color:
	return _tint(_palette["roof"].darkened(0.22))

## Push a palette colour toward the current map's light.
func _tint(c: Color) -> Color:
	var t: Dictionary = THEME_TINT[clampi(MapThemes.current, 0, THEME_TINT.size() - 1)]
	return c.lerp(t["mix"], float(t["amount"]))

## Night only (see set_process in refresh_shape): windows warm up on the beat,
## so a town lit at night pulses gently along with the machine.
func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var e: float = 1.0 + sin(t * 1.3 + _phase) * 0.18
	if StreamManager.is_playing():
		e += 0.5 * pow(1.0 - StreamManager.beat_phase(), 2.0)
	for m in _glow:
		m.emission_energy_multiplier = lerpf(m.emission_energy_multiplier, e, 0.2)
