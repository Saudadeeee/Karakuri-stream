class_name GearMesh
extends RefCounted

## Procedural cog/gear mesh — the single "karakuri" motif language reused at
## every scale: a giant one turning under the island, ambient ones in the sky,
## tiny ones framing the UI. Flat extruded cog: a hub ring + `teeth` trapezoid
## teeth, matte wooden. Vertex-coloured (rim darker) so one material serves all.

## Build a SOLID cog in the XY plane (axis = +Z), extruded by `depth`.
## `r_out` = tooth tip radius, `r_in` = tooth root radius, `hub` = raised centre
## boss radius (0 = none). Double-sided disc face + extruded tooth wall.
static func build(teeth: int, r_out: float, r_in: float, hub: float, depth: float,
		face: Color, rim: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz: float = depth * 0.5
	var rim_pts: PackedVector2Array = _rim_profile(teeth, r_out, r_in)
	var n: int = rim_pts.size()

	# Solid disc faces: fan centre → rim, both sides (winding flips per side).
	for si in 2:
		var side: float = 1.0 if si == 0 else -1.0
		var z: float = hz * side
		for i in n:
			var a: Vector3 = Vector3(rim_pts[i].x, rim_pts[i].y, z)
			var b: Vector3 = Vector3(rim_pts[(i + 1) % n].x, rim_pts[(i + 1) % n].y, z)
			_tri(st, Vector3(0, 0, z), a, b, side, face)

	# Tooth wall (silhouette extruded) — darker rim colour.
	for i in n:
		var a2: Vector2 = rim_pts[i]
		var b2: Vector2 = rim_pts[(i + 1) % n]
		_vc(st, rim, Vector3(a2.x, a2.y, -hz))
		_vc(st, rim, Vector3(a2.x, a2.y, hz))
		_vc(st, rim, Vector3(b2.x, b2.y, hz))
		_vc(st, rim, Vector3(a2.x, a2.y, -hz))
		_vc(st, rim, Vector3(b2.x, b2.y, hz))
		_vc(st, rim, Vector3(b2.x, b2.y, -hz))

	# Raised centre boss (a small proud disc) so the hub reads.
	if hub > 0.0:
		var bz: float = hz + depth * 0.25
		var seg: int = 16
		for si in 2:
			var side2: float = 1.0 if si == 0 else -1.0
			var z2: float = (bz if si == 0 else -bz)
			for i in seg:
				var a0: float = TAU * i / seg
				var a1: float = TAU * (i + 1) / seg
				var a := Vector3(cos(a0) * hub, sin(a0) * hub, z2)
				var b := Vector3(cos(a1) * hub, sin(a1) * hub, z2)
				_tri(st, Vector3(0, 0, z2), a, b, side2, rim.lightened(0.12))
		for i in seg:
			var a0: float = TAU * i / seg
			var a1: float = TAU * (i + 1) / seg
			var pa := Vector2(cos(a0) * hub, sin(a0) * hub)
			var pb := Vector2(cos(a1) * hub, sin(a1) * hub)
			_vc(st, rim.lightened(0.06), Vector3(pa.x, pa.y, -bz))
			_vc(st, rim.lightened(0.06), Vector3(pa.x, pa.y, bz))
			_vc(st, rim.lightened(0.06), Vector3(pb.x, pb.y, bz))
			_vc(st, rim.lightened(0.06), Vector3(pa.x, pa.y, -bz))
			_vc(st, rim.lightened(0.06), Vector3(pb.x, pb.y, bz))
			_vc(st, rim.lightened(0.06), Vector3(pb.x, pb.y, -bz))

	st.generate_normals()
	return st.commit()

## A simple matte StandardMaterial3D reading vertex colours.
static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	return m

# ------------------------------------------------------------------ internals
static func _rim_profile(teeth: int, r_out: float, r_in: float) -> PackedVector2Array:
	# 3 boundary points per tooth around a CLOSED ring (no duplicate at the
	# tooth seam — the next tooth's root is the following point): root → tip
	# rise → tip fall. The ring wraps, so tooth i's fall connects to tooth
	# i+1's root.
	var pts := PackedVector2Array()
	var step: float = TAU / float(teeth)
	for i in teeth:
		var a0: float = step * i
		pts.append(Vector2(cos(a0), sin(a0)) * r_in)                       # root
		pts.append(Vector2(cos(a0 + step * 0.3), sin(a0 + step * 0.3)) * r_out)   # tip rise
		pts.append(Vector2(cos(a0 + step * 0.7), sin(a0 + step * 0.7)) * r_out)   # tip fall
	return pts

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, side: float, col: Color) -> void:
	# Wind so the +Z face points outward on each side.
	if side > 0.0:
		_vc(st, col, a); _vc(st, col, b); _vc(st, col, c)
	else:
		_vc(st, col, a); _vc(st, col, c); _vc(st, col, b)

static func _vc(st: SurfaceTool, col: Color, v: Vector3) -> void:
	st.set_color(col)
	st.add_vertex(v)
