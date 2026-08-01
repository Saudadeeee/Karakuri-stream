extends StaticBody3D

## Chong chóng nước (water pinwheel). Purely playful: a stream splashing onto
## its cell gives the wheel a burst of spin (StreamManager calls splash()),
## which winds down with friction — so it flutters in the rhythm of whatever
## machine feeds it. Variants recolour the petals.

const BAMBOO := Color(0.549, 0.702, 0.412)
const ACCENT := Color(0.878, 0.478, 0.372)

var grid_cell: Vector3i
var _wheel: Node3D
var _petal_mats: Array[StandardMaterial3D] = []
var _speed: float = 0.0

func _ready() -> void:
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.035; pc.bottom_radius = 0.05; pc.height = 0.9; pc.radial_segments = 7
	pole.mesh = pc
	pole.position = Vector3(0, -0.05, 0)
	pole.material_override = _mat(BAMBOO)
	add_child(pole)

	_wheel = Node3D.new()
	_wheel.position = Vector3(0, 0.34, 0.09)
	add_child(_wheel)
	var hub := MeshInstance3D.new()
	var hc := SphereMesh.new()
	hc.radius = 0.05; hc.height = 0.1; hc.radial_segments = 7; hc.rings = 4
	hub.mesh = hc
	hub.material_override = _mat(ACCENT)
	_wheel.add_child(hub)
	for i in 4:
		var petal := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.3, 0.14, 0.02)
		petal.mesh = b
		var pm := _mat(Color("#F49CC4"))
		petal.material_override = pm
		_petal_mats.append(pm)
		var arm := Node3D.new()
		arm.rotation.z = i * PI * 0.5
		arm.add_child(petal)
		petal.position = Vector3(0.2, 0.0, 0.0)
		petal.rotation.x = 0.5   # angled like a real pinwheel blade
		_wheel.add_child(arm)

func apply_variant(v: Dictionary) -> void:
	var col := Color(v.get("color", "#F49CC4"))
	for m in _petal_mats:
		m.albedo_color = col

## A stream tick landed on this cell — spin up (with a soft paper flutter).
func splash() -> void:
	_speed = minf(_speed + 6.0, 14.0)
	AudioManager.play_flutter(global_position)

func _process(delta: float) -> void:
	if _speed <= 0.01:
		return
	_wheel.rotate_z(_speed * delta)
	_speed = maxf(_speed - delta * 3.0, 0.0)   # wind-down friction

func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	return m
