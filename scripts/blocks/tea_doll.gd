extends Node3D

## Chahakobi ningyō — the Edo tea-serving automaton, the literal icon of
## karakuri. Chunky-cute procedural puppet (no skeleton): a robed cone body
## with an obi band, a calm cream face, and arms holding a tray + teacup. On a
## slow loop it glides forward, dips the tray to "present", then rolls back —
## with a faint wheel-wobble that sells the hidden internal cam. Gentle, minimal.

const WOOD := Color("d4a373")
const OBI := Color("e07a5f")
const CREAM := Color("f4efe2")
const FACE_DARK := Color("2a2a2a")
const BLUSH := Color("f2a6b6")

var _body: Node3D
var _tray: Node3D
var _head: Node3D
var _t: float = 0.0

func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	# Robed body: truncated cone, obi band, base wheels hint.
	_body.add_child(_cyl(0.28, 0.42, 0.7, WOOD, Vector3(0, 0.35, 0)))     # robe
	_body.add_child(_cyl(0.34, 0.34, 0.1, OBI, Vector3(0, 0.5, 0)))       # obi
	_body.add_child(_cyl(0.44, 0.44, 0.08, WOOD.darkened(0.15), Vector3(0, 0.02, 0)))  # base disc
	# Head: cream sphere + calm painted face.
	_head = Node3D.new()
	_head.position = Vector3(0, 0.82, 0)
	_body.add_child(_head)
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.19; sm.height = 0.36
	skull.mesh = sm; skull.material_override = _mat(CREAM)
	_head.add_child(skull)
	_head.add_child(_dot(0.028, FACE_DARK, Vector3(-0.07, 0.02, 0.17)))   # eyes
	_head.add_child(_dot(0.028, FACE_DARK, Vector3(0.07, 0.02, 0.17)))
	_head.add_child(_dot(0.03, BLUSH, Vector3(-0.12, -0.05, 0.15)))       # blush
	_head.add_child(_dot(0.03, BLUSH, Vector3(0.12, -0.05, 0.15)))
	var topknot := MeshInstance3D.new()
	var tk := SphereMesh.new(); tk.radius = 0.07; tk.height = 0.12
	topknot.mesh = tk; topknot.material_override = _mat(Color("6b4a30"))
	topknot.position = Vector3(0, 0.19, 0)
	_head.add_child(topknot)
	# Arms + tray with a teacup, held forward.
	_tray = Node3D.new()
	_tray.position = Vector3(0, 0.6, 0.26)
	_body.add_child(_tray)
	for sx in [-1.0, 1.0]:
		var arm := _cyl(0.05, 0.05, 0.34, WOOD, Vector3(0.17 * sx, 0.02, -0.13))
		arm.rotation.x = -1.1
		_tray.add_child(arm)
	_tray.add_child(_cyl(0.17, 0.17, 0.03, Color("a9764a"), Vector3(0, 0, 0)))   # tray disc
	_tray.add_child(_cyl(0.05, 0.06, 0.07, CREAM, Vector3(0, 0.05, 0)))          # teacup
	_tray.add_child(_cyl(0.08, 0.08, 0.015, CREAM.darkened(0.1), Vector3(0, 0.015, 0)))  # saucer

func _process(delta: float) -> void:
	_t += delta
	# Slow present-and-return cycle (~7s). Glide forward, dip the tray + nod,
	# roll back; a tiny body wobble suggests the internal wheel-cam.
	var cycle: float = fmod(_t, 7.0)
	var fwd: float = smoothstep(0.0, 2.0, cycle) - smoothstep(4.5, 6.5, cycle)
	_body.position.z = fwd * 0.9
	_body.rotation.z = sin(_t * 6.0) * 0.02 * (0.3 + fwd)     # cam wobble
	if is_instance_valid(_tray):
		var present: float = smoothstep(1.6, 2.2, cycle) - smoothstep(3.4, 4.2, cycle)
		_tray.rotation.x = present * 0.4
	if is_instance_valid(_head):
		_head.rotation.x = (smoothstep(1.8, 2.2, cycle) - smoothstep(3.2, 3.8, cycle)) * 0.3

func _cyl(rt: float, rb: float, h: float, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = 12
	mi.mesh = c; mi.position = pos; mi.material_override = _mat(col)
	return mi

func _dot(r: float, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = 7; s.rings = 4
	mi.mesh = s; mi.position = pos; mi.material_override = _mat(col)
	return mi

func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	return m
