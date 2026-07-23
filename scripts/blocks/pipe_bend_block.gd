extends StaticBody3D

## 90° bamboo elbow. Water falls in the TOP port (+Y) and leaves through a
## chosen SIDE port; the R key at placement cycles which side. `apply_ports`
## orients the model (authored with ports {+Y, +X}) by spinning it about Y.

const MODEL: PackedScene = preload("res://assets/3DModel/generated/pipe_elbow.glb")

## Elbow port sets: always {top +Y, one side}, cycled by R.
const PORT_SETS: Array = [
	[Vector3i(0, 1, 0), Vector3i(1, 0, 0)],
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(-1, 0, 0)],
	[Vector3i(0, 1, 0), Vector3i(0, 0, -1)],
]

func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	MeshFit.fit_centered(model, 1.0)
	MeshFit.matte(model)

func apply_ports(ports: Array) -> void:
	var side: Vector3i = ports[1] if ports[0] == Vector3i(0, 1, 0) else ports[0]
	basis = _basis_for(side)

static func _basis_for(side: Vector3i) -> Basis:
	match side:
		Vector3i(0, 0, 1):
			return Basis(Vector3(0, 1, 0), -PI / 2.0)
		Vector3i(-1, 0, 0):
			return Basis(Vector3(0, 1, 0), PI)
		Vector3i(0, 0, -1):
			return Basis(Vector3(0, 1, 0), PI / 2.0)
		_: # +X authored
			return Basis.IDENTITY
