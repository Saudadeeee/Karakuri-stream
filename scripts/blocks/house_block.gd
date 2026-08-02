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
## 0.42 read as a flat dark slab; 0.58 went too far the other way and on a
## single-cell top the roof became a hat that swallowed the storey under it —
## a two-storey house looked like a ground floor wearing a lid. 0.48 lets the
## pitch read while leaving the upper walls visible.
const ROOF_H := 0.48
const ROOF_OVER := 0.11       # eaves overhang past the wall

## Townscaper's towns read as towns because the buildings are unmistakably
## DIFFERENT COLOURS — a red one, a blue one, a yellow one — not eight shades of
## the same beige. Two earlier passes at this failed for that reason: pale
## plaster over red-brown roofs, so whichever palette a building picked it looked
## identical, and the scene grade then desaturated what little difference was
## left. These are saturated on purpose and survive the grade.
const PALETTES: Array[Dictionary] = [
	{"wall": Color("f6ead2"), "roof": Color("c1452f"), "trim": Color("8a6a4a")},   # cream + tile red
	{"wall": Color("e8503f"), "roof": Color("a8412e"), "trim": Color("6f2c22")},   # tomato
	{"wall": Color("3f7fa6"), "roof": Color("3d6d8c"), "trim": Color("2d4d61")},   # deep sea blue
	{"wall": Color("f0b53c"), "roof": Color("b06327"), "trim": Color("8a6134")},   # saffron
	{"wall": Color("6f9e5a"), "roof": Color("5b7a4e"), "trim": Color("4f6b45")},   # leaf green
	{"wall": Color("f2f0e8"), "roof": Color("74838c"), "trim": Color("77776f")},   # whitewash + slate
	{"wall": Color("c76ba0"), "roof": Color("a85280"), "trim": Color("7a4460")},   # rose
	{"wall": Color("6a5b96"), "roof": Color("5d5081"), "trim": Color("4d4470")},   # violet
]

## Awning cloth. The one saturated accent on an otherwise quiet building, so a
## street reads as lived-in rather than as a colour swatch.
const ACCENT := Color("e07a5f")
## One green for every leaf on the building. `MeshBatch` cuts a surface per
## colour, so each shade a cell uses is a draw call it keeps forever — and
## planter, roof garden and courtyard had each grown their own foliage green,
## three shades within 0.03 per channel of one another. No two of them ever sit
## side by side, so the split bought nothing and cost a surface. The deliberate
## two-tone that IS visible — dark tufts on a lighter planter box — stays.
const FOLIAGE := Color("8cb369")
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
var _pop_pending: bool = false
var _dirty: bool = false
var _visual: Node3D
var _batch: MeshBatch
var _base_palette: int = 0
## The digest is split in two so a distant edit does not force ~40 shape queries
## on every cell of a big building. See _digest.
var _digest_cache: PackedByteArray = PackedByteArray()
var _digest_whole: PackedByteArray = PackedByteArray()
var _digest_local: PackedByteArray = PackedByteArray()
## Set when an edit lands within REACH of this cell; cleared once consumed.
## Starts true so the first refresh computes everything.
var _near_local_dirty: bool = true
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
	# Neighbours lean toward a shared district tone, so a corner of the island
	# reads as one quarter rather than as confetti — but one building in five
	# ignores it, because a town with NO outlier looks planned rather than grown.
	var own: float = HouseShape.building_roll(grid_cell, 3)
	var district: float = HouseShape.district_roll(grid_cell, 3)
	var mixed: float = district if own > 0.2 else own
	var spread: float = (own - 0.5) * (0.9 if own > 0.2 else 3.0)
	var pick: int = posmod(int((mixed + spread * 0.25) * PALETTES.size()), PALETTES.size())
	var chosen: Dictionary = PALETTES[pick]
	var light: float = (HouseShape.building_roll(grid_cell, 5) - 0.5) * 0.26
	var roof_light: float = (HouseShape.building_roll(grid_cell, 11) - 0.5) * 0.34
	# The player's variant still leads: it is mixed back in so a deliberately
	# chosen colour stays recognisable across the street rather than being
	# overwritten by the building's own roll.
	# Only a light pull toward the player's variant. At 0.35 the building's own
	# colour was being averaged back into beige and the street went uniform again.
	_palette = {
		"wall": (chosen["wall"] as Color).lerp(base["wall"], 0.12).lightened(light * 0.5),
		"roof": (chosen["roof"] as Color).lerp(base["roof"], 0.12).lightened(roof_light * 0.5),
		"trim": chosen["trim"],
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
## Rebuilds are COALESCED to at most one per frame.
##
## Almost everything a cell draws — its colour, door, chimney, spire, terrace,
## courtyard — is decided from the whole BUILDING, not from its neighbours. The
## old test only refreshed cells sharing a row or column at the same height, so
## removing the base of a tower never told the top, and knocking a cell off one
## arm of an L never told the other. Those cells kept stale roofs and stale
## spires: the "house with no roof after deleting" that got reported.
##
## Any house change therefore has to reach every house. Doing that synchronously
## would rebuild the whole town once per signal; deferring to _process means each
## cell rebuilds at most once per frame however many signals arrive.
func _on_grid_changed(cell: Vector3i) -> void:
	if not _placed:
		return
	# This cell is gone and is only alive until queue_free lands. Rebuilding it
	# would put geometry back for a block that no longer exists.
	if not HouseShape.is_house(grid_cell):
		return
	if cell != grid_cell and not HouseShape.affects(grid_cell, cell):
		return
	# Did the edit land close enough to change what this cell derives from its own
	# neighbourhood? If not, the expensive half of the digest cannot have moved
	# and is reused — see _digest.
	if HouseShape.touches_locally(grid_cell, cell):
		_near_local_dirty = true
	_dirty = true
	set_process(true)

## Every answer this cell's geometry is built from, in one string. Anything the
## build asks `HouseShape` must appear here — leave a query out and the cell
## keeps stale geometry when only that query's answer changed. `_sec_no_stale_
## geometry` in the regression suite is the guard: it rebuilds a town by editing
## and again from scratch and demands the two match exactly, which is precisely
## the failure a missing entry produces.
func _digest(ctx: Dictionary) -> PackedByteArray:
	# WHOLE-BUILDING half. Cheap: every one of these is a lookup into a component
	# flood that is cached per grid version.
	#
	# `building_size` is deliberately dropped. It is the raw cell count, the
	# geometry never reads it, and everything decided FROM it (the decor tier, and
	# so the planters, awnings and roof gardens) appears below as the boolean that
	# came out. Leaving the count in meant adding one cell to a 48-cell building
	# changed all 48 digests, so all 48 threw away a finished mesh and rebuilt an
	# identical one — 76 ms of geometry per click, all of it wasted.
	var shape: Dictionary = ctx.duplicate()
	shape.erase("building_size")
	var whole: Array = [shape, _base_palette, _palette, MapThemes.current]
	if not _placed:
		return var_to_bytes(whole)
	whole.append([HouseShape.has_spire(grid_cell), HouseShape.is_terrace(grid_cell),
			HouseShape.has_roof_garden(grid_cell), HouseShape.has_shutters(grid_cell),
			HouseShape.bears_stilts(grid_cell), HouseShape.decor_tier(grid_cell),
			HouseShape.component_height(grid_cell)])
	var whole_bytes := var_to_bytes(whole)

	# NEIGHBOURHOOD half. ~40 queries, and the expensive part of a refresh. It can
	# only have changed if an edit landed within REACH of this cell — or if the
	# building-wide half moved, since the decor tier feeds the per-face trim.
	if not _near_local_dirty and whole_bytes == _digest_whole and not _digest_local.is_empty():
		_digest_whole = whole_bytes
		return whole_bytes + _digest_local
	_digest_whole = whole_bytes

	var d: Array = []
	d.append([HouseShape.dormer_side(grid_cell), HouseShape.courtyard_dir(grid_cell),
			HouseShape.bunting_dir(grid_cell)])
	d.append([HouseShape.arch_axis(grid_cell), HouseShape.arch_run(grid_cell),
			HouseShape.corbel_sides(grid_cell), HouseShape.roof_top_height(grid_cell)])
	var corners: Array = []
	for ax in [-1, 1]:
		for az in [-1, 1]:
			corners.append(HouseShape.owns_corner(grid_cell, ax, az))
	d.append(corners)
	# The roof surface is stitched from the height field and from which sides the
	# roof runs off, so both go in.
	var roof: Array = []
	for a in [-1, 0, 1]:
		for b in [-1, 0, 1]:
			roof.append(HouseShape.roof_level(grid_cell.x * 2 + a, grid_cell.z * 2 + b, grid_cell.y))
	for n in [Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, 0, 1)]:
		roof.append(HouseShape.is_roof_cell(grid_cell + n))
	d.append(roof)
	# Per-face trim. These take the side and the ground/stacked flags, so they
	# cannot be inferred from anything already in the list.
	var ground: bool = not bool(ctx["stacked"])
	var faces: Array = []
	for side in ctx["open_sides"]:
		var is_door: bool = ctx["door_side"] == side
		faces.append([side, is_door,
				HouseShape.window_offsets(grid_cell, side, is_door),
				HouseShape.has_balcony(grid_cell, side, ctx["stacked"]),
				HouseShape.has_planter(grid_cell, side, ground),
				HouseShape.has_awning(grid_cell, side, true)])
	d.append(faces)
	# var_to_bytes, not str(): identical information, exactly comparable, and six
	# times cheaper on a nested array this size (measured).
	_digest_local = var_to_bytes(d)
	return whole_bytes + _digest_local

func apply_variant(v: Dictionary) -> void:
	_base_palette = int(v.get("palette", 0)) % PALETTES.size()
	if is_inside_tree():
		refresh_shape()

## How much of a frame every house in the town may spend rebuilding, together.
## A time budget rather than a cell count because cells are not equal: a plain
## middle-of-a-terrace cell is a fraction of a corner cell carrying a spire, an
## arch and a courtyard, and three of the latter is a dropped frame.
##
## 3 ms leaves the rest of the frame — rendering a 48-house town, the streams,
## the wildlife scan — inside 16 ms on the machine this was measured on.
const REBUILD_BUDGET_US := 3000
static var _budget_frame: int = -1
static var _budget_us_left: int = 0

# ----------------------------------------------------------------- assembly
## Returns true when geometry was actually rebuilt, which is what the per-frame
## budget is spent on.
func refresh_shape() -> bool:
	# Cleared HERE, not in _process: refresh_shape is also called directly by
	# _ready, the grid_cell setter and apply_variant, and each of those ends by
	# turning _process off again. A cell that was already dirty when one of them
	# ran kept the flag set with nothing left to service it — harmless while the
	# flag only caused a redundant rebuild, but a permanent "still rebuilding" as
	# soon as anything waits on it.
	_dirty = false
	var ctx: Dictionary = HouseShape.context(grid_cell) if _placed else HouseShape.lone_context()
	_resolve_palette()

	# Most cells told to refresh have nothing to change. A building's door,
	# chimney and storey count come from the whole component, so adding one cell
	# to an 80-cell building legitimately concerns all 80 — but only the two
	# nearest the change actually LOOK different, and the other 78 were throwing
	# away a finished mesh and generating an identical one. At ~1.75 ms a cell
	# that was 140 ms in the frame after every click, which is the hitch a player
	# feels as the town gets big.
	#
	# So: work out what this cell has decided, and if it has decided exactly what
	# it decided last time, keep the geometry. The decisions are dictionary
	# lookups over a cached flood; the geometry is ~1000 triangles and ten
	# surface uploads.
	var digest := _digest(ctx)
	_near_local_dirty = false
	if digest == _digest_cache and _visual != null and is_instance_valid(_visual):
		return false
	_digest_cache = digest

	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	_glow.clear()
	_visual = Node3D.new()
	add_child(_visual)
	_batch = MeshBatch.new()
	var wall_col: Color = _tint(_palette["wall"])
	var trim_col: Color = _tint(_palette["trim"])

	if ctx["floor"]:
		_batch.box(Vector3(1.02, 0.09, 1.02), Vector3(0, -0.5, 0), trim_col)   # stone footing

	for side in ctx["open_sides"]:
		_build_face(side, ctx, wall_col, trim_col)
	_build_corners(ctx, wall_col)

	_build_underside(ctx, trim_col)
	if ctx["has_above"]:
		_build_storey_band(ctx, trim_col)
	# A spire is not an ornament bolted to a roof — it IS the top of the tower.
	# Building both gave a normal pitched house with a spike stuck through it.
	var spire: bool = HouseShape.has_spire(grid_cell)
	var terrace: bool = HouseShape.is_terrace(grid_cell)
	if ctx["roof"] and not spire and not terrace:
		_build_roof(ctx)
	elif terrace:
		_build_terrace(ctx, trim_col)
	# No chimney under another house's floor — a terrace bearing stilts has a
	# building overhead, and the stack pokes straight into its floorboards.
	if ctx["chimney"] and not (terrace and HouseShape.bears_stilts(grid_cell)):
		_build_chimney(trim_col)
	# Only a real building earns a roof garden, and only where its roof is flat
	# enough on top to stand a pot on — a narrow ridge would just float them.
	if HouseShape.has_roof_garden(grid_cell):
		_build_roof_garden(trim_col)
	var dormer: Vector3i = HouseShape.dormer_side(grid_cell)
	if dormer != Vector3i.ZERO:
		_build_dormer(dormer, wall_col, trim_col)
	# --- the surprises: geometry the player never asked for, earned by a shape ---
	if spire:
		_build_spire(trim_col)
	var court: Vector3i = HouseShape.courtyard_dir(grid_cell)
	if court != Vector3i.ZERO:
		_build_courtyard(court, trim_col)
	var bunt: Vector3i = HouseShape.bunting_dir(grid_cell)
	if bunt != Vector3i.ZERO:
		_build_bunting(bunt)

	# Everything above went into ONE mesh, grouped by colour: four or five draw
	# calls per cell instead of one per plank.
	var mi := MeshInstance3D.new()
	mi.mesh = _batch.build_merged(shared_material(), _special_material)
	_visual.add_child(mi)
	_batch = null
	if _pop_pending:
		_pop_pending = false
		_pop()

	# Only night houses breathe; every other map leaves the panes flat, so a big
	# town costs nothing per frame.
	set_process(MapThemes.current == NIGHT_THEME and not _glow.is_empty())
	return true

## One exposed wall: plaster panel, then whatever that face earned — a door, some
## windows, maybe a balcony.
func _build_face(side: Vector3i, ctx: Dictionary, wall_col: Color, trim_col: Color) -> void:
	var horiz := Vector3(float(side.z), 0.0, float(-side.x))   # along the face
	var out := Vector3(float(side.x), 0.0, float(side.z))
	# A hair of variation per panel: depth and lateral shift, both sub-centimetre.
	var wobble: float = _jitter(side.x * 13 + side.z * 29) * 0.014
	var lean: float = _jitter(side.x * 5 + side.z * 3) * 0.01
	_batch.box(_face_size(side, 1.0 + wobble, WALL_T),
		out * (0.5 - WALL_T * 0.5 + wobble * 0.5) + horiz * lean, wall_col)
	_build_brickwork(side, out, horiz, wall_col)

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

## A 45-degree post down every vertical corner where two exposed walls meet.
##
## This is the single biggest remaining "it is a cube" tell. Townscaper has no
## right-angled corners anywhere — its grid is a relaxed quad mesh — and we
## cannot change our grid without rewriting stream routing, gear meshing, the
## water isosurface and the save format along with it. Chamfering fakes the
## symptom instead: a cube with its corners cut stops reading as a cube from
## every angle, for one box per corner in the batch we are already building.
func _build_corners(ctx: Dictionary, wall_col: Color) -> void:
	var open_sides: Array = ctx["open_sides"]
	for ax in [-1, 1]:
		for az in [-1, 1]:
			# Only where BOTH of the meeting walls actually exist, otherwise the
			# post hangs in the air off the side of a shared wall.
			if not (Vector3i(ax, 0, 0) in open_sides and Vector3i(0, 0, az) in open_sides):
				continue
			var j: float = _jitter(11 + ax * 3 + az * 7) * 0.012
			_batch.box(Vector3(0.17, 1.0, 0.17),
				Vector3(ax * (0.5 - 0.055 + j), 0.0, az * (0.5 - 0.055 + j)),
				wall_col, Basis(Vector3(0, 1, 0), PI / 4.0))

## Deterministic wobble in [-1,1] for this cell. Individually a few millimetres
## and invisible; collectively it is the difference between a printed row of
## boxes and something built by hand. Comes from the cell hash, NEVER randf() —
## a random source here would reshuffle the whole town on every reload.
func _jitter(salt: int) -> float:
	return HouseShape.jitter(grid_cell, salt)

## FULL-HEIGHT panel covering one face: `span` goes into BOTH the vertical and
## the horizontal axis, so this is only ever right for something that fills the
## whole face — a wall. For anything low (a sill, a band, a balustrade) use
## `_slab`, which takes width and height separately. Mixing the two up turned a
## terrace balustrade into a ring of full-height walls.
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
	_batch.box(_slab(out, 0.22, 0.06), centre + out * 0.06 + Vector3(0, -0.14, 0), _tint(FOLIAGE))
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

## Brick courses in RELIEF, not in texture.
##
## The art style is untextured flat-shaded — every surface in the game is a solid
## colour, and the meshes are procedurally batched with no UVs to map an image
## onto. Painting bricks would mean adding a UV pipeline and a texture atlas to
## one block type while everything around it stayed flat, which would make the
## house look pasted in rather than detailed.
##
## So the bricks are GEOMETRY: shallow courses proud of the plaster, offset every
## other row so the joints stagger the way real brick does, in a shade of the
## wall's own colour. Detail without a new colour costs no extra draw call, since
## MeshBatch groups by colour — see the note on the palette.
const BRICK_ROWS := 5
const BRICK_D := 0.018

func _build_brickwork(side: Vector3i, out: Vector3, horiz: Vector3, wall_col: Color) -> void:
	var shade: Color = wall_col.darkened(0.07)
	var face: float = 0.5 - WALL_T + BRICK_D * 0.5
	for r in BRICK_ROWS:
		var y: float = -0.4 + float(r) * (0.8 / float(BRICK_ROWS - 1))
		var j: float = _jitter(side.x * 3 + side.z * 5 + r * 17) * 0.01
		# One proud course per row: a shallow band across the wall.
		_batch.box(_slab(out, 0.92, 0.055) + out.abs() * BRICK_D,
			out * face + Vector3(0, y + j, 0), shade)
		# Perpends, staggered every other course so the joints break like real
		# brickwork instead of lining up into a grid.
		var stagger: float = 0.0 if r % 2 == 0 else 0.115
		for i in 4:
			var x: float = -0.345 + float(i) * 0.23 + stagger
			if absf(x) > 0.4:
				continue
			_batch.box(_slab(out, 0.03, 0.055) + out.abs() * (BRICK_D * 1.6),
				out * face + horiz * x + Vector3(0, y + j, 0), shade)

## Which of the four sides a face normal belongs to.
func _side_of(out: Vector3) -> Vector3i:
	return Vector3i(roundi(out.x), 0, roundi(out.z))

## A trough of greenery along the foot of the wall.
func _build_planter(out: Vector3, horiz: Vector3, trim_col: Color) -> void:
	var at: Vector3 = out * 0.56 + Vector3(0, -0.44, 0)
	_batch.box(_slab(out, 0.5, 0.14) + out.abs() * 0.1, at, trim_col)
	_batch.box(_slab(out, 0.44, 0.1) + out.abs() * 0.08, at + Vector3(0, 0.08, 0), _tint(FOLIAGE))
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
## The whole town shares this one matte material and carries its colours in the
## vertex stream. Created once, never per cell — a town of 120 houses used to
## allocate ~600 StandardMaterial3D and pay a draw call for each.
static var _shared_mat: StandardMaterial3D

static func shared_material() -> StandardMaterial3D:
	if _shared_mat == null:
		_shared_mat = MeshFit.flat(Color.WHITE)
		_shared_mat.vertex_color_use_as_albedo = true
	return _shared_mat

## Only the lit night window needs a material of its own, because it emits. Every
## other colour rides the shared one, so this returns null for them.
func _special_material(col: Color) -> Variant:
	if MapThemes.current == NIGHT_THEME and col.is_equal_approx(GLASS_NIGHT):
		var m := MeshFit.flat(col)
		m.emission_enabled = true
		m.emission = GLASS_NIGHT
		m.emission_energy_multiplier = 1.0
		_glow.append(m)
		return m
	return null

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
	# A cell bridging between two supported neighbours gets an ARCH — the thing
	# that turns a stacked street into an arcade you can see through, and the
	# single most Townscaper-looking piece of geometry in the game.
	var axis: Vector3i = HouseShape.arch_axis(grid_cell)
	if axis != Vector3i.ZERO:
		_build_arch(axis, trim_col)
	elif bool(ctx["overhang"]):
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

## A round-headed arch spanning `axis`, built as a fan of short chords so the
## curve reads without needing a curved primitive. The springings sit inside the
## cell's two ends and the crown reaches the cell floor, so neighbouring arch
## cells in a row line up into a continuous arcade.
const ARCH_SEGMENTS := 7
const ARCH_RISE := 0.62

func _build_arch(axis: Vector3i, trim_col: Color) -> void:
	var run: Dictionary = HouseShape.arch_run(grid_cell)
	if run.is_empty():
		return
	var length: int = int(run["length"])
	var index: int = int(run["index"])
	var along := Vector3(float(axis.x), 0.0, float(axis.z))
	var across := Vector3(float(axis.z), 0.0, float(axis.x)).normalized()
	# One semicircle spans the WHOLE run; this cell draws only its own slice of
	# it, in the run's local coordinates, so the pieces join into a single curve.
	var span: float = float(length)
	var rise: float = ARCH_RISE * clampf(span * 0.55, 0.7, 1.6)
	var prev := Vector3.ZERO
	var segs: int = ARCH_SEGMENTS
	for i in segs + 1:
		# u runs 0..1 across the whole span; this cell covers [index, index+1].
		var u: float = (float(index) + float(i) / float(segs)) / span
		var ang: float = PI * u
		# Position along the arch relative to THIS cell's centre.
		var offset: float = (u * span) - (float(index) + 0.5)
		var pt: Vector3 = along * offset + Vector3(0, -0.5 - rise * sin(ang), 0)
		if i > 0:
			var seg: Vector3 = pt - prev
			var tilt: float = atan2(seg.y, along.dot(seg))
			_batch.box(Vector3(seg.length() + 0.07, 0.15, 0.88), (prev + pt) * 0.5,
				trim_col, Basis(across, tilt) * _axis_basis(along))
		prev = pt
	# Piers only at the ENDS of the run, where the arch actually lands.
	if index == 0:
		_batch.box(along.abs() * 0.17 + across.abs() * 0.86 + Vector3(0, 0.44, 0),
			along * -0.42 + Vector3(0, -0.74, 0), trim_col)
	if index == length - 1:
		_batch.box(along.abs() * 0.17 + across.abs() * 0.86 + Vector3(0, 0.44, 0),
			along * 0.42 + Vector3(0, -0.74, 0), trim_col)

## Orients a box whose local +X should run along `along` (which is a unit axis).
func _axis_basis(along: Vector3) -> Basis:
	return Basis.IDENTITY if absf(along.x) > 0.5 else Basis(Vector3(0, 1, 0), PI / 2.0)

## Diagonal brackets under a cantilevered storey, one per supported neighbour it
## juts out from — the joinery that makes an overhang look deliberate.
func _build_corbels(trim_col: Color) -> void:
	# The bracket springs FROM the wall that holds this cell up, so it sits on the
	# +out side — toward the support. It used to be placed at -out and a full cell
	# below the floor, which put it on the far side hanging in open air, i.e.
	# invisible. A one-cell overhang therefore appeared to be supported by nothing
	# while a two-cell one got proper columns.
	for d in HouseShape.corbel_sides(grid_cell):
		var out := Vector3(float(d.x), 0.0, float(d.z))
		var along := Vector3(float(d.z), 0.0, float(-d.x))
		# Chunky and steeply raked, so a one-cell overhang reads as SUPPORTED at a
		# glance. Slim brackets were technically there and told the player nothing:
		# beside a two-cell overhang on obvious columns they looked like the
		# building was simply floating.
		for s2 in [-0.3, 0.3]:
			var at: Vector3 = out * 0.24 + along * s2 + Vector3(0, -0.62, 0)
			var size := Vector3(0.66, 0.2, 0.2) if absf(out.x) > 0.5 else Vector3(0.2, 0.2, 0.66)
			var tilt := Basis(Vector3(0, 0, 1), -0.72 * signf(out.x)) if absf(out.x) > 0.5 				else Basis(Vector3(1, 0, 0), 0.72 * signf(out.z))
			_batch.box(size, at, trim_col, tilt)
			# A short post at the bracket's outer foot: the visual "this is
			# carrying weight" cue that the columns give for free.
			_batch.box(Vector3(0.12, 0.3, 0.12), out * -0.16 + along * s2 + Vector3(0, -0.78, 0), trim_col)
	# Sill under the overhanging floor, for the brackets to carry.
	_batch.box(Vector3(0.96, 0.1, 0.96), Vector3(0, -0.5, 0), trim_col)

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
const ROOF_STEP: Array[float] = [0.0, ROOF_H, ROOF_H * 1.5]   # mirror HouseShape.ROOF_RISE   # keep in step with HouseShape.ROOF_RISE
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
	var leaf: Color = _tint(FOLIAGE)
	for i in 3:
		var a: float = HouseShape.building_roll(grid_cell, 31 + i) * TAU
		var at := Vector3(cos(a) * 0.22, top, sin(a) * 0.22)
		_batch.box(Vector3(0.15, 0.12, 0.15), at + Vector3(0, 0.06, 0), trim_col)
		_batch.box(Vector3(0.11, 0.16, 0.11), at + Vector3(0, 0.19, 0), leaf)
		if i == 0:
			_batch.box(Vector3(0.05, 0.2, 0.05), at + Vector3(0, 0.3, 0), _dark())
			_batch.box(Vector3(0.26, 0.2, 0.26), at + Vector3(0, 0.44, 0), leaf)

## A small gabled window pushing out of a roof slope.
##
## In a dense town the roofs are the largest unbroken surfaces on screen and they
## currently say nothing — a dormer is the cheapest thing that makes a roofline
## look inhabited rather than like a lid. Sits at the eaves end of the slope it
## faces, so it reads as breaking through the roof rather than floating on it.
func _build_dormer(side: Vector3i, wall_col: Color, trim_col: Color) -> void:
	var out := Vector3(float(side.x), 0.0, float(side.z))
	var at: Vector3 = out * 0.28 + Vector3(0, 0.5 + ROOF_H * 0.36, 0)
	# Box body, then a little roof over it, then the glass.
	_batch.box(Vector3(0.30, 0.28, 0.30) + out.abs() * 0.06, at, wall_col)
	_batch.box(Vector3(0.38, 0.07, 0.38) + out.abs() * 0.06,
		at + Vector3(0, 0.17, 0), _tint(_palette["roof"]))
	_batch.box(_slab(out, 0.18, 0.16), at + out * 0.17 + Vector3(0, -0.01, 0), _glass_col())
	_batch.box(_slab(out, 0.22, 0.04), at + out * 0.18 + Vector3(0, -0.11, 0), trim_col)

## A flat, railed roof terrace: paving, a low balustrade on every open edge, and
## a couple of pots. Built where a taller neighbour stands over this roof, so a
## stepped town grows usable ledges instead of a staircase of pitched roofs.
func _build_terrace(ctx: Dictionary, trim_col: Color) -> void:
	var deck: Color = _tint(Color("b3a68e"))
	_batch.box(Vector3(1.04, 0.1, 1.04), Vector3(0, 0.5, 0), deck)
	for side in ctx["open_sides"]:
		var out := Vector3(float(side.x), 0.0, float(side.z))
		# Balustrade: a capped LOW wall, only on edges that face out.
		#
		# This used _face_size, which puts its `span` argument into BOTH the
		# vertical and the horizontal axis — so "1.04 wide, 0.09 thick" came out
		# as a 1.04-TALL full-height panel. A terrace therefore rendered as a ring
		# of roofless walls standing around an empty cell, which is exactly what
		# got reported: no block there, walls anyway, and placing a block into it
		# "fixed" it because the cell then stopped being a terrace at all.
		# _slab is the helper for a low, wide, thin panel on a face.
		_batch.box(_slab(out, 1.04, 0.18), out * 0.46 + Vector3(0, 0.63, 0), trim_col)
		_batch.box(_slab(out, 1.04, 0.06) + out.abs() * 0.05, out * 0.46 + Vector3(0, 0.73, 0), deck)
	var leaf: Color = _tint(FOLIAGE)
	for i in 2:
		var a: float = HouseShape.building_roll(grid_cell, 41 + i) * TAU
		var at := Vector3(cos(a) * 0.28, 0.6, sin(a) * 0.28)
		_batch.box(Vector3(0.16, 0.14, 0.16), at, trim_col)
		_batch.box(Vector3(0.13, 0.2, 0.13), at + Vector3(0, 0.16, 0), leaf)

## A tall thin tower stops being a house and becomes a landmark: a tapered spire
## with a weathervane on top. Visible from anywhere on the island, which is the
## whole point of rewarding someone for building UP.
func _build_spire(trim_col: Color) -> void:
	var roof: Color = _tint(_palette["roof"])
	# The spire IS the roof now, so it starts at the wall head and carries a proper
	# eaves course — a bare needle on a flat top read as a spike stuck through a
	# house rather than as the top of a tower.
	_batch.box(Vector3(1.16, 0.1, 1.16), Vector3(0, 0.54, 0), roof)
	var base: float = 0.59
	var steps := 6
	for i in steps:
		var t: float = float(i) / float(steps)
		var w: float = lerpf(0.92, 0.14, t)
		_batch.box(Vector3(w, 0.3, w), Vector3(0, base + 0.15 + t * 1.5, 0), roof)
	var top: float = base + 1.72
	_batch.box(Vector3(0.05, 0.28, 0.05), Vector3(0, top, 0), trim_col)
	# Weathervane: a little arrow across the mast, turned by the cell hash so no
	# two towers in a town point the same way.
	var ang: float = HouseShape.building_roll(grid_cell, 97) * TAU
	_batch.box(Vector3(0.34, 0.04, 0.05), Vector3(0, top + 0.16, 0), trim_col,
		Basis(Vector3(0, 1, 0), ang))

## Ring an empty cell with houses and the hole becomes a planted courtyard.
## Built INTO the neighbouring empty cell, by whichever surrounding cell owns it,
## so it appears exactly once however many houses touch it.
func _build_courtyard(dir: Vector3i, trim_col: Color) -> void:
	var at := Vector3(float(dir.x), 0.0, float(dir.z))
	var paving: Color = _tint(Color("b3a68e"))
	_batch.box(Vector3(0.92, 0.12, 0.92), at + Vector3(0, -0.46, 0), paving)
	# A small tree in the middle, and a bench against one side.
	var leaf: Color = _tint(FOLIAGE)
	_batch.box(Vector3(0.09, 0.34, 0.09), at + Vector3(0, -0.23, 0), trim_col)
	_batch.box(Vector3(0.44, 0.3, 0.44), at + Vector3(0, 0.02, 0), leaf)
	_batch.box(Vector3(0.3, 0.24, 0.3), at + Vector3(0, 0.24, 0), leaf)
	_batch.box(Vector3(0.34, 0.05, 0.13), at + Vector3(-0.28, -0.3, 0.26), trim_col)

## A line of little flags strung across a one-cell gap between two rooftops at
## the same height. Only the NEAR cell of the pair draws it, so the line appears
## once rather than twice in the same place.
func _build_bunting(dir: Vector3i) -> void:
	var along := Vector3(float(dir.x), 0.0, float(dir.z))
	var top: float = 0.5 + HouseShape.roof_top_height(grid_cell) + 0.16
	var cord: Color = _tint(Color("6b5a45"))
	var flags: Array[Color] = [_tint(ACCENT), _tint(Color("f0b53c")), _tint(Color("bcd4dd"))]
	var span := 2.0
	for i in 7:
		var t: float = (float(i) + 0.5) / 7.0
		# Sag: the cord dips in the middle the way a real line does.
		var sag: float = sin(t * PI) * 0.16
		var at: Vector3 = along * (t * span) + Vector3(0, top - sag, 0)
		_batch.box(along * 0.3 + Vector3(0.03, 0.03, 0.03), at, cord)
		_batch.box(Vector3(0.07, 0.13, 0.07), at + Vector3(0, -0.09, 0), flags[i % flags.size()])

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

## A quick squash-and-settle when the building re-forms around a new neighbour.
## Scale only, on the visual child — never on this StaticBody3D, whose collision
## shape the placement raycast depends on.
func _pop() -> void:
	if not is_inside_tree() or _visual == null:
		return
	_visual.scale = Vector3(1.08, 0.9, 1.08)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.26) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Night only (see set_process in refresh_shape): windows warm up on the beat,
## so a town lit at night pulses gently along with the machine.
func _process(_delta: float) -> void:
	if _dirty:
		# A frame may only pay for so much geometry. After the digest split the
		# cells that actually change are few, but "few" is 4-6 on a click and each
		# is ~2 ms of mesh building — enough to push a frame past 16 ms and be felt
		# as a stutter in a game whose whole promise is calm. Cells over the budget
		# stay dirty and rebuild next frame; the lag is a frame or two on houses
		# away from the cursor, which is invisible, and the frame time stays flat.
		var frame: int = Engine.get_process_frames()
		if _budget_frame != frame:
			_budget_frame = frame
			_budget_us_left = REBUILD_BUDGET_US
		if _budget_us_left <= 0:
			return
		var started: int = Time.get_ticks_usec()
		refresh_shape()
		# Charged whether or not geometry was rebuilt: confirming that nothing
		# changed still costs shape queries, and it is the TOTAL the frame has to
		# stay inside.
		_budget_us_left -= Time.get_ticks_usec() - started
		# refresh_shape decides for itself whether the night glow needs _process;
		# respect that rather than forcing it back on.
		return
	if _glow.is_empty():
		set_process(false)
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	var e: float = 1.0 + sin(t * 1.3 + _phase) * 0.18
	if StreamManager.is_playing():
		e += 0.5 * pow(1.0 - StreamManager.beat_phase(), 2.0)
	for m in _glow:
		m.emission_energy_multiplier = lerpf(m.emission_energy_multiplier, e, 0.2)
