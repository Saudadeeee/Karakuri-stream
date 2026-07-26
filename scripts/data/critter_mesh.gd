class_name CritterMesh
extends RefCounted

## Procedural chunky animals, built from the same primitive vocabulary as the
## tea doll and the clock movement: spheres and boxes, flat matte, no textures.
## Modelling these in code rather than shipping .glb keeps them tintable per map
## theme (a snow fox, a night-blue cat) and costs a few hundred triangles each.
##
## Convention for every critter: +X is FORWARD (the head end), the origin sits on
## the GROUND between the feet. WildlifeManager just aims +X along the direction
## of travel and drops the root on a surface — no per-species offsets.

const EYE := Color("22304a")

static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = MeshFit.flat(col)
	parent.add_child(mi)
	return mi

static func _ball(parent: Node3D, r: float, pos: Vector3, col: Color, squash: float = 1.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 * squash
	s.radial_segments = 8
	s.rings = 5
	return _part(parent, s, pos, col)

static func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _part(parent, b, pos, col)

static func _cone(parent: Node3D, r: float, h: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 6
	return _part(parent, c, pos, col)

static func _eyes(parent: Node3D, at: Vector3, spread: float, r: float = 0.018) -> void:
	for s in [-1.0, 1.0]:
		_ball(parent, r, at + Vector3(0, 0, spread * s), EYE)

# ------------------------------------------------------------------- species
## Small garden bird. `wing` is returned so the manager can flap it in flight.
static func bird(col: Color, belly: Color) -> Dictionary:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	body.position = Vector3(0, 0.085, 0)
	_ball(body, 0.062, Vector3.ZERO, col, 0.85)
	_ball(body, 0.040, Vector3(0.028, -0.022, 0), belly, 0.7)
	var head := _ball(body, 0.044, Vector3(0.058, 0.048, 0), col)
	_cone(head, 0.017, 0.05, Vector3(0.03, 0.0, 0), Color("e8a33d")).rotation.z = -PI / 2.0
	_eyes(head, Vector3(0.022, 0.012, 0), 0.026)
	_box(body, Vector3(0.075, 0.016, 0.03), Vector3(-0.072, 0.012, 0), col.darkened(0.2)).rotation.z = 0.35
	var wings: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(0, 0.01, 0.045 * s)
		body.add_child(w)
		_ball(w, 0.03, Vector3(-0.01, 0, 0.012 * s), col.darkened(0.12), 0.35).rotation.x = 0.3 * s
		wings.append(w)
	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.008, 0.035, 0.008), Vector3(0.01, 0.018, 0.022 * s), Color("e8a33d"))
	return {"root": root, "body": body, "wings": wings}

## Cat. `tail` swishes, `head` turns to look at things.
static func cat(col: Color) -> Dictionary:
	var root := Node3D.new()
	var body := Node3D.new()
	body.position = Vector3(0, 0.115, 0)
	root.add_child(body)
	_ball(body, 0.085, Vector3(-0.02, 0, 0), col, 0.78)
	var head := _ball(body, 0.062, Vector3(0.085, 0.048, 0), col)
	for s in [-1.0, 1.0]:
		var ear := _cone(head, 0.026, 0.05, Vector3(-0.005, 0.05, 0.03 * s), col)
		ear.rotation.x = 0.3 * s
	_ball(head, 0.03, Vector3(0.045, -0.014, 0), col.lightened(0.28), 0.75)
	_ball(head, 0.011, Vector3(0.068, -0.006, 0), Color("e0918f"), 0.8)
	_eyes(head, Vector3(0.05, 0.016, 0), 0.028, 0.013)
	for x in [0.045, -0.075]:
		for s in [-1.0, 1.0]:
			_box(root, Vector3(0.028, 0.1, 0.028), Vector3(x, 0.05, 0.042 * s), col.darkened(0.08))
	var tail := Node3D.new()
	tail.position = Vector3(-0.1, 0.02, 0)
	body.add_child(tail)
	_box(tail, Vector3(0.12, 0.026, 0.026), Vector3(-0.055, 0.03, 0), col.darkened(0.12)).rotation.z = 0.6
	_ball(tail, 0.02, Vector3(-0.105, 0.075, 0), col.lightened(0.3), 0.9)
	return {"root": root, "body": body, "head": head, "tail": tail}

## Duck — the one critter that lives on the water, so it floats a little low.
static func duck(col: Color) -> Dictionary:
	var root := Node3D.new()
	var body := Node3D.new()
	body.position = Vector3(0, 0.07, 0)
	root.add_child(body)
	_ball(body, 0.088, Vector3.ZERO, col, 0.72)
	_box(body, Vector3(0.06, 0.05, 0.055), Vector3(-0.075, 0.035, 0), col.darkened(0.1)).rotation.z = 0.5
	var neck := _ball(body, 0.036, Vector3(0.062, 0.06, 0), col, 1.5)
	var head := _ball(body, 0.05, Vector3(0.075, 0.125, 0), col)
	_box(head, Vector3(0.055, 0.018, 0.038), Vector3(0.042, -0.012, 0), Color("f2a63d"))
	_eyes(head, Vector3(0.026, 0.014, 0), 0.03)
	neck.rotation.z = -0.2
	return {"root": root, "body": body, "head": head}

## Deer — the shy visitor. Tall, thin legs, pale spots.
static func deer(col: Color) -> Dictionary:
	var root := Node3D.new()
	var body := Node3D.new()
	body.position = Vector3(0, 0.26, 0)
	root.add_child(body)
	_ball(body, 0.105, Vector3.ZERO, col, 0.72)
	for i in 3:
		_ball(body, 0.016, Vector3(-0.05 + i * 0.05, 0.06, 0.055), col.lightened(0.45), 0.4)
		_ball(body, 0.016, Vector3(-0.05 + i * 0.05, 0.06, -0.055), col.lightened(0.45), 0.4)
	var neck := _box(body, Vector3(0.05, 0.14, 0.05), Vector3(0.085, 0.09, 0), col)
	neck.rotation.z = 0.4
	var head := _ball(body, 0.05, Vector3(0.15, 0.17, 0), col, 0.85)
	_ball(head, 0.025, Vector3(0.04, -0.015, 0), col.darkened(0.3), 0.8)
	_eyes(head, Vector3(0.022, 0.018, 0), 0.032)
	for s in [-1.0, 1.0]:
		_cone(head, 0.022, 0.05, Vector3(-0.01, 0.045, 0.026 * s), col.lightened(0.2)).rotation.x = 0.4 * s
	for x in [0.06, -0.07]:
		for s in [-1.0, 1.0]:
			_box(root, Vector3(0.022, 0.24, 0.022), Vector3(x, 0.12, 0.05 * s), col.darkened(0.12))
	_ball(body, 0.028, Vector3(-0.105, 0.03, 0), Color("f6efe2"), 0.9)
	return {"root": root, "body": body, "head": head}
