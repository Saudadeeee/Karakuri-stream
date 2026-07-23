extends StaticBody3D

## A bamboo spout that pours a water stream straight down from its cell (traced
## by StreamManager). The model is a CELL-CENTRED vertical bamboo tube with its
## mouth at the bottom centre — so it lines up perfectly with a pipe directly
## below and with the centred stream (an earlier off-centre side spout made the
## body, the pipe below and the falling water all disagree). It's radially
## symmetric, so facing a neighbouring pond is now purely cosmetic.

const MODEL: PackedScene = preload("res://assets/3DModel/generated/source.glb")

var grid_cell: Vector3i
var _model: Node3D

func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	MeshFit.fit_bottom(_model, 0.92, -0.5)
	MeshFit.matte(_model)
	GridManager.block_placed.connect(_on_grid_changed)
	GridManager.block_removed.connect(_on_grid_changed)

func _on_grid_changed(cell: Vector3i) -> void:
	if cell == grid_cell or (cell - grid_cell) in GridManager.DIRECTIONS:
		face_adjacent_water()

## Spin the spout (authored pointing +X) toward a neighbouring water block.
func face_adjacent_water() -> void:
	for d in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		var b: BlockData = GridManager.get_block(grid_cell + d)
		if b != null and b.type == BlockData.Type.WATER:
			basis = _basis_towards_x(d)
			return

static func _basis_towards_x(d: Vector3i) -> Basis:
	match d:
		Vector3i(0, 0, 1):
			return Basis(Vector3(0, 1, 0), -PI / 2.0)
		Vector3i(-1, 0, 0):
			return Basis(Vector3(0, 1, 0), PI)
		Vector3i(0, 0, -1):
			return Basis(Vector3(0, 1, 0), PI / 2.0)
		_:
			return Basis.IDENTITY
