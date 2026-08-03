class_name HouseRoof
extends RefCounted

## Everything a house cell puts ON TOP of itself: the roof height field, and the
## ornaments a shape earns — spire, terrace, dormer, roof garden, courtyard,
## bunting, chimney.
##
## Split out of house_block.gd, which had grown past 950 lines and was two jobs
## in one file: deciding what this cell is (HouseShape queries, the digest, the
## rebuild budget) and drawing it. This half draws. It is static and takes
## everything it needs, so it holds no state and can be read on its own.
##
## `paint` carries the colours already pushed through the map theme's tint, so
## nothing here has to know what a theme is:
##   roof dark trim leaf glass deck cord accent flag_gold flag_sky snow snowy

## Ridge height above the cell top, and how far the eaves reach past the wall.
## These live with the roof rather than with the cell, which is the whole point
## of the split.
const ROOF_H := 0.48
const ROOF_OVER := 0.11
const ROOF_STEP: Array[float] = [0.0, ROOF_H, ROOF_H * 1.5]   # keep in step with HouseShape.ROOF_RISE
const ROOF_THICK := 0.07

## A LOW, WIDE, THIN panel on the face pointing `out` — a balustrade, a sill, a
## dormer pane. Not to be confused with a full-height wall panel: a terrace built
## out of those came out as a ring of roofless walls.
static func slab(out: Vector3, w: float, h: float) -> Vector3:
	return Vector3(h if absf(out.x) > 0.5 else w, h, h if absf(out.z) > 0.5 else w)

static func roof(batch: MeshBatch, cell: Vector3i, paint: Dictionary, _ctx: Dictionary) -> void:
	var col: Color = paint["roof"]
	var top: Array = _roof_samples(cell, 0.0)
	_emit_roof_surface(batch, top, col, false)
	# Underside, reversed so it faces down, plus a rim so the eaves have an edge.
	var under: Array = _roof_samples(cell, -ROOF_THICK)
	_emit_roof_surface(batch, under, paint["dark"], true)
	_emit_roof_rim(batch, cell, top, under, paint["dark"])
	if bool(paint["snowy"]):
		# Snow rides ON the roof, inset so the tile edge still shows at the eaves —
		# a fully coated roof turns the whole village into white blobs.
		_emit_roof_surface(batch, _roof_samples(cell, 0.035, 0.13), paint["snow"], false)

## The 3x3 sample grid for this cell, as world-local positions.
## `lift` raises the whole sheet; `inset` pulls the outer ring inward (used for
## the snow layer). Outer samples push OUT by the eaves overhang, but only on
## sides where the roof actually ends — pushing out into a neighbour would make
## the two cells' eaves intersect and z-fight down the whole terrace.
static func _roof_samples(cell: Vector3i, lift: float, inset: float = 0.0) -> Array:
	var pts: Array = []
	for iz in 3:
		var row: Array = []
		for ix in 3:
			var a: int = ix - 1
			var b: int = iz - 1
			var x: float = a * 0.5
			var z: float = b * 0.5
			if a != 0 and not HouseShape.is_roof_cell(cell + Vector3i(a, 0, 0)):
				x = a * (0.5 + ROOF_OVER - inset)
			if b != 0 and not HouseShape.is_roof_cell(cell + Vector3i(0, 0, b)):
				z = b * (0.5 + ROOF_OVER - inset)
			var level: int = HouseShape.roof_level(cell.x * 2 + a, cell.z * 2 + b, cell.y)
			row.append(Vector3(x, 0.5 + ROOF_STEP[level] + lift, z))
		pts.append(row)
	return pts

static func _emit_roof_surface(batch: MeshBatch, p: Array, col: Color, flip: bool) -> void:
	for iz in 2:
		for ix in 2:
			var a: Vector3 = p[iz][ix]
			var b: Vector3 = p[iz][ix + 1]
			var c: Vector3 = p[iz + 1][ix + 1]
			var d: Vector3 = p[iz + 1][ix]
			if flip:
				batch.quad(d, c, b, a, col)
			else:
				batch.quad(a, b, c, d, col)

## Fascia band closing the gap between the top sheet and its underside, but only
## along edges where the roof really stops — an interior edge is shared with the
## neighbour's slab and capping it would bury a wall inside the roof.
static func _emit_roof_rim(batch: MeshBatch, cell: Vector3i, top: Array, under: Array, col: Color) -> void:
	var edges: Array = [
		[Vector3i(0, 0, -1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]],
		[Vector3i(0, 0, 1), [Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]],
		[Vector3i(-1, 0, 0), [Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0)]],
		[Vector3i(1, 0, 0), [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]],
	]
	for e in edges:
		if HouseShape.is_roof_cell(cell + (e[0] as Vector3i)):
			continue
		var idx: Array = e[1]
		for i in idx.size() - 1:
			var m: Vector2i = idx[i]
			var n: Vector2i = idx[i + 1]
			batch.quad(top[m.y][m.x], top[n.y][n.x], under[n.y][n.x], under[m.y][m.x], col)

## Pots and a little tree on the flat of a big roof. This is the payoff for
## building UP and WIDE rather than sprawling — the reward has to be visible from
## the normal play camera, so it sits on the highest surface the building has.
static func roof_garden(batch: MeshBatch, cell: Vector3i, paint: Dictionary, trim_col: Color) -> void:
	var top: float = 0.5 + ROOF_STEP[HouseShape.ROOF_LEVELS] + 0.02
	var leaf: Color = paint["leaf"]
	for i in 3:
		var a: float = HouseShape.building_roll(cell, 31 + i) * TAU
		var at := Vector3(cos(a) * 0.22, top, sin(a) * 0.22)
		batch.box(Vector3(0.15, 0.12, 0.15), at + Vector3(0, 0.06, 0), trim_col)
		batch.box(Vector3(0.11, 0.16, 0.11), at + Vector3(0, 0.19, 0), leaf)
		if i == 0:
			batch.box(Vector3(0.05, 0.2, 0.05), at + Vector3(0, 0.3, 0), paint["dark"])
			batch.box(Vector3(0.26, 0.2, 0.26), at + Vector3(0, 0.44, 0), leaf)

## A small gabled window pushing out of a roof slope.
##
## In a dense town the roofs are the largest unbroken surfaces on screen and they
## currently say nothing — a dormer is the cheapest thing that makes a roofline
## look inhabited rather than like a lid. Sits at the eaves end of the slope it
## faces, so it reads as breaking through the roof rather than floating on it.
static func dormer(batch: MeshBatch, cell: Vector3i, paint: Dictionary, side: Vector3i, wall_col: Color, trim_col: Color) -> void:
	var out := Vector3(float(side.x), 0.0, float(side.z))
	var at: Vector3 = out * 0.28 + Vector3(0, 0.5 + ROOF_H * 0.36, 0)
	# Box body, then a little roof over it, then the glass.
	batch.box(Vector3(0.30, 0.28, 0.30) + out.abs() * 0.06, at, wall_col)
	batch.box(Vector3(0.38, 0.07, 0.38) + out.abs() * 0.06,
		at + Vector3(0, 0.17, 0), paint["roof"])
	batch.box(slab(out, 0.18, 0.16), at + out * 0.17 + Vector3(0, -0.01, 0), paint["glass"])
	batch.box(slab(out, 0.22, 0.04), at + out * 0.18 + Vector3(0, -0.11, 0), trim_col)

## A flat, railed roof terrace: paving, a low balustrade on every open edge, and
## a couple of pots. Built where a taller neighbour stands over this roof, so a
## stepped town grows usable ledges instead of a staircase of pitched roofs.
static func terrace(batch: MeshBatch, cell: Vector3i, paint: Dictionary, ctx: Dictionary, trim_col: Color) -> void:
	var deck: Color = paint["deck"]
	batch.box(Vector3(1.04, 0.1, 1.04), Vector3(0, 0.5, 0), deck)
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
		batch.box(slab(out, 1.04, 0.18), out * 0.46 + Vector3(0, 0.63, 0), trim_col)
		batch.box(slab(out, 1.04, 0.06) + out.abs() * 0.05, out * 0.46 + Vector3(0, 0.73, 0), deck)
	var leaf: Color = paint["leaf"]
	for i in 2:
		var a: float = HouseShape.building_roll(cell, 41 + i) * TAU
		var at := Vector3(cos(a) * 0.28, 0.6, sin(a) * 0.28)
		batch.box(Vector3(0.16, 0.14, 0.16), at, trim_col)
		batch.box(Vector3(0.13, 0.2, 0.13), at + Vector3(0, 0.16, 0), leaf)

## A tall thin tower stops being a house and becomes a landmark: a tapered spire
## with a weathervane on top. Visible from anywhere on the island, which is the
## whole point of rewarding someone for building UP.
static func spire(batch: MeshBatch, cell: Vector3i, paint: Dictionary, trim_col: Color) -> void:
	var roof: Color = paint["roof"]
	# The spire IS the roof now, so it starts at the wall head and carries a proper
	# eaves course — a bare needle on a flat top read as a spike stuck through a
	# house rather than as the top of a tower.
	batch.box(Vector3(1.16, 0.1, 1.16), Vector3(0, 0.54, 0), roof)
	var base: float = 0.59
	var steps := 6
	for i in steps:
		var t: float = float(i) / float(steps)
		var w: float = lerpf(0.92, 0.14, t)
		batch.box(Vector3(w, 0.3, w), Vector3(0, base + 0.15 + t * 1.5, 0), roof)
	var top: float = base + 1.72
	batch.box(Vector3(0.05, 0.28, 0.05), Vector3(0, top, 0), trim_col)
	# Weathervane: a little arrow across the mast, turned by the cell hash so no
	# two towers in a town point the same way.
	var ang: float = HouseShape.building_roll(cell, 97) * TAU
	batch.box(Vector3(0.34, 0.04, 0.05), Vector3(0, top + 0.16, 0), trim_col,
		Basis(Vector3(0, 1, 0), ang))

## Ring an empty cell with houses and the hole becomes a planted courtyard.
## Built INTO the neighbouring empty cell, by whichever surrounding cell owns it,
## so it appears exactly once however many houses touch it.
static func courtyard(batch: MeshBatch, cell: Vector3i, paint: Dictionary, dir: Vector3i, trim_col: Color) -> void:
	var at := Vector3(float(dir.x), 0.0, float(dir.z))
	var paving: Color = paint["deck"]
	batch.box(Vector3(0.92, 0.12, 0.92), at + Vector3(0, -0.46, 0), paving)
	# A small tree in the middle, and a bench against one side.
	var leaf: Color = paint["leaf"]
	batch.box(Vector3(0.09, 0.34, 0.09), at + Vector3(0, -0.23, 0), trim_col)
	batch.box(Vector3(0.44, 0.3, 0.44), at + Vector3(0, 0.02, 0), leaf)
	batch.box(Vector3(0.3, 0.24, 0.3), at + Vector3(0, 0.24, 0), leaf)
	batch.box(Vector3(0.34, 0.05, 0.13), at + Vector3(-0.28, -0.3, 0.26), trim_col)

## A line of little flags strung across a one-cell gap between two rooftops at
## the same height. Only the NEAR cell of the pair draws it, so the line appears
## once rather than twice in the same place.
static func bunting(batch: MeshBatch, cell: Vector3i, paint: Dictionary, dir: Vector3i) -> void:
	var along := Vector3(float(dir.x), 0.0, float(dir.z))
	var top: float = 0.5 + HouseShape.roof_top_height(cell) + 0.16
	var cord: Color = paint["cord"]
	var flags: Array[Color] = [paint["accent"], paint["flag_gold"], paint["flag_sky"]]
	var span := 2.0
	for i in 7:
		var t: float = (float(i) + 0.5) / 7.0
		# Sag: the cord dips in the middle the way a real line does.
		var sag: float = sin(t * PI) * 0.16
		var at: Vector3 = along * (t * span) + Vector3(0, top - sag, 0)
		batch.box(along * 0.3 + Vector3(0.03, 0.03, 0.03), at, cord)
		batch.box(Vector3(0.07, 0.13, 0.07), at + Vector3(0, -0.09, 0), flags[i % flags.size()])

static func chimney(batch: MeshBatch, cell: Vector3i, paint: Dictionary, host: Node3D, trim_col: Color) -> void:
	var at := Vector3(0.26, 0.5 + ROOF_H * 0.55, 0.26)
	batch.box(Vector3(0.18, 0.46, 0.18), at, trim_col)
	batch.box(Vector3(0.24, 0.06, 0.24), at + Vector3(0, 0.25, 0), paint["dark"])
	_add_smoke(host, at + Vector3(0, 0.3, 0))

## Slow chimney smoke. Amount goes through QualityManager so the web LITE build
## halves it — a street of houses is the one thing here that can multiply
## particle systems, so this must scale with the profile like everything else.
static func _add_smoke(host: Node3D, at: Vector3) -> void:
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
	host.add_child(p)
