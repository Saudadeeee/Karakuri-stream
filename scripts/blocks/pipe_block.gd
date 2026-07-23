extends StaticBody3D

## Auto-connecting bamboo pipe. Built procedurally as a central hub plus a bamboo
## stub toward EACH connected neighbour (pipe or source) — so it forms straights,
## elbows, T-junctions and crosses automatically, Minecraft-pipe style, with no
## per-shape models or orientation to manage. Rebuilds whenever a neighbour changes.

const BAMBOO := Color(0.549, 0.702, 0.412)   # #8CB369
const ACCENT := Color(0.878, 0.478, 0.372)   # #E07A5F
const STUB_R := 0.15
const HUB_R := 0.2

var grid_cell: Vector3i
var _visual: Node3D
var _open: bool = false   # variant: open-top trough so the water is visible

func _ready() -> void:
	GridManager.block_placed.connect(_on_grid_changed)
	GridManager.block_removed.connect(_on_grid_changed)

func _on_grid_changed(cell: Vector3i) -> void:
	if cell == grid_cell or (cell - grid_cell) in GridManager.DIRECTIONS:
		refresh_shape()

func apply_variant(v: Dictionary) -> void:
	_open = bool(v.get("open", false))
	if is_inside_tree():
		refresh_shape()

func refresh_shape() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	var dirs: Array = PipeRouting.connections(grid_cell)
	if dirs.is_empty():
		dirs = [Vector3i(0, 1, 0), Vector3i(0, -1, 0)]  # lone pipe = vertical tube
	_visual = build_visual(dirs, _open)
	add_child(_visual)

## Shape rules:
##  - A STRAIGHT run (exactly two opposite connections) is ONE clean tube passing
##    through — no round joint bulge.
##  - Anything else (lone, elbow, T, cross, a turn down) keeps the ROUND ball
##    joint + a stub per direction.
## OPEN (variant) horizontal arms become U-channel troughs (floor + two walls,
## open top) so the routed water stream is visibly flowing through. Static so the
## placement ghost can reuse it.
static func build_visual(dirs: Array, open: bool = false) -> Node3D:
	var root := Node3D.new()
	var mat := _mat(BAMBOO)
	var accent := _mat(ACCENT)

	var straight: bool = dirs.size() == 2 and dirs[0] == -Vector3i(dirs[1])
	if straight:
		var axis: Vector3i = dirs[0]
		if open and axis.y == 0:
			_add_trough(root, axis, mat, 1.16, 0.0)      # one long open channel
		else:
			_add_tube_through(root, Vector3(axis), mat, accent)
		return root

	# Junction / bend / lone: a joint at the centre + one arm per direction.
	# CLOSED pipes use a round ball (matches the round tubes); OPEN pipes use a
	# flat box that fills the U-channel cross-section (a round ball stuck on a
	# flat trough looked wrong) — so an open run reads as one seamless channel
	# with square wooden corners, never a bulging bead.
	if open:
		root.add_child(_box(Vector3(0.34, 0.30, 0.34), Vector3(0.0, -0.04, 0.0), mat))
	else:
		root.add_child(_sphere(HUB_R, mat))
	for d in dirs:
		if open and d.y == 0:
			_add_trough(root, d, mat, 0.52, 0.28)
		else:
			_add_tube(root, Vector3(d.x, d.y, d.z), mat, accent)
	return root

## One tube passing straight through the cell along `axis` (no hub).
static func _add_tube_through(root: Node3D, axis: Vector3, mat: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = STUB_R; cyl.bottom_radius = STUB_R; cyl.height = 1.16; cyl.radial_segments = 10
	mi.mesh = cyl
	mi.material_override = mat
	mi.basis = _basis_towards(axis)
	root.add_child(mi)
	for s in [0.42, -0.42]:
		var band := MeshInstance3D.new()
		var b := CylinderMesh.new()
		b.top_radius = STUB_R + 0.03; b.bottom_radius = STUB_R + 0.03; b.height = 0.05; b.radial_segments = 10
		band.mesh = b
		band.material_override = accent
		band.position = axis * s
		band.basis = _basis_towards(axis)
		root.add_child(band)

static func _add_tube(root: Node3D, dv: Vector3, mat: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var stub := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = STUB_R; cyl.bottom_radius = STUB_R; cyl.height = 0.5; cyl.radial_segments = 10
	stub.mesh = cyl
	stub.material_override = mat
	stub.position = dv * 0.3
	stub.basis = _basis_towards(dv)
	root.add_child(stub)
	var band := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = STUB_R + 0.03; bcyl.bottom_radius = STUB_R + 0.03; bcyl.height = 0.05; bcyl.radial_segments = 10
	band.mesh = bcyl
	band.material_override = accent
	band.position = dv * 0.42
	band.basis = _basis_towards(dv)
	root.add_child(band)

## Open U-channel toward horizontal `d`: a floor plate + two side walls, open on
## top. Built along local +X (length `len`, centred at X=`off`), then rotated so
## +X → d.
static func _add_trough(root: Node3D, d: Vector3i, mat: StandardMaterial3D, len: float, off: float) -> void:
	var seg := Node3D.new()
	seg.basis = _basis_x_to(d)
	seg.add_child(_box(Vector3(len, 0.09, 0.32), Vector3(off, -0.16, 0.0), mat))    # floor
	seg.add_child(_box(Vector3(len, 0.26, 0.06), Vector3(off, -0.02, 0.16), mat))   # +Z wall
	seg.add_child(_box(Vector3(len, 0.26, 0.06), Vector3(off, -0.02, -0.16), mat))  # -Z wall
	root.add_child(seg)

static func _sphere(r: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r; s.height = r * 2.0; s.radial_segments = 10; s.rings = 6
	mi.mesh = s
	mi.material_override = mat
	return mi

static func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	return mi

static func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.metallic = 0.0
	return m

## Cylinder default axis is Y — aim it along `dir`.
static func _basis_towards(dir: Vector3) -> Basis:
	if absf(dir.dot(Vector3.UP)) > 0.999:
		return Basis.IDENTITY if dir.y > 0.0 else Basis(Vector3(1, 0, 0), PI)
	return Basis(Quaternion(Vector3.UP, dir.normalized()))

## Rotate so local +X points along horizontal `d`.
static func _basis_x_to(d: Vector3i) -> Basis:
	match d:
		Vector3i(-1, 0, 0):
			return Basis(Vector3(0, 1, 0), PI)
		Vector3i(0, 0, 1):
			return Basis(Vector3(0, 1, 0), -PI / 2.0)
		Vector3i(0, 0, -1):
			return Basis(Vector3(0, 1, 0), PI / 2.0)
		_:
			return Basis.IDENTITY
