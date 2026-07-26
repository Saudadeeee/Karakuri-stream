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
const ROOF_H := 0.42          # ridge height above the cell top
const ROOF_OVER := 0.11       # eaves overhang past the wall

## Townscaper's palette logic: quiet plaster, one warm roof, one darker timber.
## The roof stays close in hue across variants so a mixed street still reads as
## one town instead of a colour swatch.
const PALETTES: Array[Dictionary] = [
	{"wall": Color("f2e8d5"), "roof": Color("c1683f"), "trim": Color("8a6a4a")},
	{"wall": Color("cfe0e8"), "roof": Color("9a5f7a"), "trim": Color("6d7b84")},
	{"wall": Color("f6d9d5"), "roof": Color("b5563f"), "trim": Color("8a5f52")},
	{"wall": Color("dbe4cf"), "roof": Color("a1663c"), "trim": Color("6f7a5c")},
]

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
var _palette: Dictionary = PALETTES[0]
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
	_palette = PALETTES[int(v.get("palette", 0)) % PALETTES.size()]
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
	_batch = MeshBatch.new()
	var wall_col: Color = _tint(_palette["wall"])
	var trim_col: Color = _tint(_palette["trim"])

	if ctx["floor"]:
		_batch.box(Vector3(1.02, 0.09, 1.02), Vector3(0, -0.5, 0), trim_col)   # stone footing

	for side in ctx["open_sides"]:
		_build_face(side, ctx, wall_col, trim_col)

	if ctx["roof"]:
		_build_roof(ctx)
	if ctx["chimney"]:
		_build_chimney(trim_col)

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
	if is_door:
		_build_door(out, horiz, trim_col)
	for ox in HouseShape.window_offsets(grid_cell, side, is_door):
		_build_window(out, horiz * ox, trim_col)
	if HouseShape.has_balcony(grid_cell, side, ctx["stacked"]):
		_build_balcony(out, horiz, trim_col)

## Size of a slab covering one face: full across, thin through.
func _face_size(side: Vector3i, span: float, thick: float) -> Vector3:
	return Vector3(thick, span, span) if side.x != 0 else Vector3(span, span, thick)

func _build_door(out: Vector3, horiz: Vector3, trim_col: Color) -> void:
	_batch.box(_slab(out, 0.40, 0.66), out * 0.5 + Vector3(0, -0.17, 0), trim_col)
	_batch.box(_slab(out, 0.30, 0.56), out * 0.52 + Vector3(0, -0.2, 0), _dark())
	# Doorstep + a paper lantern on a bracket: the "someone lives here" detail.
	_batch.box(_slab(out, 0.44, 0.06), out * 0.56 + Vector3(0, -0.47, 0), trim_col)
	_batch.box(Vector3(0.12, 0.16, 0.12), out * 0.46 + horiz * 0.3 + Vector3(0, 0.16, 0), _glass_col())

func _build_window(out: Vector3, offset: Vector3, trim_col: Color) -> void:
	var centre: Vector3 = out * 0.5 + offset + Vector3(0, 0.08, 0)
	_batch.box(_slab(out, 0.30, 0.30), centre, trim_col)
	_batch.box(_slab(out, 0.22, 0.22), centre + out * 0.03, _glass_col())
	# Flower box under the sill — small, but it's what makes a wall look lived-in.
	_batch.box(_slab(out, 0.26, 0.07), centre + out * 0.05 + Vector3(0, -0.19, 0), trim_col)
	_batch.box(_slab(out, 0.22, 0.06), centre + out * 0.06 + Vector3(0, -0.14, 0), _tint(Color("8cb369")))

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

# --------------------------------------------------------------------- roof
## Gable prism sitting on the cell top. The two ends are only capped where the
## building actually STOPS — that's what lets a row of cells share one unbroken
## ridge instead of each growing its own little hut roof.
func _build_roof(ctx: Dictionary) -> void:
	var ridge_x: bool = ctx["ridge_x"]
	var axis := Vector3i(1, 0, 0) if ridge_x else Vector3i(0, 0, 1)
	var cap_neg: bool = not HouseShape.is_house(grid_cell - axis)
	var cap_pos: bool = not HouseShape.is_house(grid_cell + axis)
	# Along the ridge we only overhang at a capped end, otherwise the eaves of
	# two neighbouring cells would intersect and z-fight down the whole terrace.
	var half_along := Vector3(0.5 + (ROOF_OVER if cap_pos else 0.0), 0.0, 0.5 + (ROOF_OVER if cap_neg else 0.0))
	_emit_gable(ridge_x, half_along.x, half_along.z, cap_neg, cap_pos, _tint(_palette["roof"]))
	# Ridge cap board — reads as tile capping and hides the seam between cells.
	var cap := Vector3(1.0, 0.06, 0.1) if ridge_x else Vector3(0.1, 0.06, 1.0)
	var ridge_col: Color = SNOW if MapThemes.current == SNOW_THEME else _dark()
	_batch.box(cap, Vector3(0, 0.5 + ROOF_H, 0), ridge_col)
	if MapThemes.current == SNOW_THEME:
		_snow_cap(ridge_x, half_along)

## Snow lying on the roof: two thin slabs laid along the slopes. Snow settles on
## the UPPER half only — a fully coated roof loses the tile colour entirely and
## the whole village turns into white blobs.
func _snow_cap(ridge_x: bool, half_along: Vector3) -> void:
	var along: float = (half_along.x + half_along.z)
	for s in [-1.0, 1.0]:
		var size := Vector3(along, 0.045, 0.34) if ridge_x else Vector3(0.34, 0.045, along)
		var across: float = 0.17 * s
		var at := Vector3(0, 0.5 + ROOF_H * 0.72, across) if ridge_x else Vector3(across, 0.5 + ROOF_H * 0.72, 0)
		# Lie along the pitch instead of floating flat above it.
		var tilt := Basis(Vector3(1, 0, 0), -0.62 * s) if ridge_x else Basis(Vector3(0, 0, 1), 0.62 * s)
		_batch.box(size, at, SNOW, tilt)

## Emits the gable straight into the batch. Faceted normals come for free —
## MeshBatch computes one per triangle, which is what the flat-shaded art style
## wants anyway (smoothing a roof this chunky just muddies the ridge line).
func _emit_gable(ridge_x: bool, over_pos: float, over_neg: float, cap_neg: bool, cap_pos: bool, col: Color) -> void:
	var w: float = 0.5 + ROOF_OVER          # across the ridge (eaves side)
	var a: float = over_pos                  # along the ridge, + end
	var b: float = over_neg                  # along the ridge, - end
	var top: float = 0.5                     # roof sits on the cell top
	# Corners named along/across so one formula serves both ridge directions.
	var p := func(al: float, ac: float, y: float) -> Vector3:
		return Vector3(al, top + y, ac) if ridge_x else Vector3(ac, top + y, al)

	var bl: Vector3 = p.call(-b, -w, 0.0); var br: Vector3 = p.call(a, -w, 0.0)
	var fl: Vector3 = p.call(-b, w, 0.0);  var fr: Vector3 = p.call(a, w, 0.0)
	var rl: Vector3 = p.call(-b, 0.0, ROOF_H); var rr: Vector3 = p.call(a, 0.0, ROOF_H)

	_batch.quad(bl, br, rr, rl, col)     # one slope
	_batch.quad(fr, fl, rl, rr, col)     # the other slope
	_batch.quad(br, bl, fl, fr, col)     # underside, so eaves aren't see-through
	if cap_pos:
		_batch.tri(br, fr, rr, col)
	if cap_neg:
		_batch.tri(fl, bl, rl, col)

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
