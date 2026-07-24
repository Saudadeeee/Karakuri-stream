extends StaticBody3D

## Gầu múc (water scoop). Next to a POND and a POWERED gear, its wheel turns
## and ladles water up — creating a NEW stream falling from this cell. Water
## drives the gears, the gears lift the water: the full karakuri energy loop.
## StreamManager decides when it's active (is_scoop_active); this script only
## animates. Art: Blockbench mast (static) + cup WHEEL instanced under the
## _wheel pivot so the ladling rotation is the mechanic.

const MAST: PackedScene = preload("res://assets/3DModel/generated/scoop_mast.glb")
const WHEEL: PackedScene = preload("res://assets/3DModel/generated/scoop_wheel.glb")

var grid_cell: Vector3i
var _wheel: Node3D

func _ready() -> void:
	var mast: Node3D = MAST.instantiate()
	add_child(mast)
	MeshFit.fit_bottom(mast, 0.95, -0.5)
	MeshFit.matte(mast)

	# Wheel on the mast-top bearing (matches the fitted mast).
	_wheel = Node3D.new()
	_wheel.position = Vector3(0, 0.38, 0)
	add_child(_wheel)
	var wheel_model: Node3D = WHEEL.instantiate()
	_wheel.add_child(wheel_model)
	MeshFit.fit_centered(wheel_model, 0.72)
	MeshFit.matte(wheel_model)

func _process(delta: float) -> void:
	if StreamManager.is_scoop_active(grid_cell):
		_wheel.rotate_z(1.8 * delta)
