extends Node

const DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

func _ready() -> void:
	GridManager.block_placed.connect(_on_grid_changed)
	GridManager.block_removed.connect(_on_grid_changed)

func _on_grid_changed(cell: Vector3i) -> void:
	_rebuild_mesh(cell)
	for dir in DIRS:
		_rebuild_mesh(cell + dir)

## Only Wood/Water use the generic box shape and visually merge into a
## continuous mass. Gear/Bell keep their own distinct sculpted mesh (cylinder,
## bell taper) and must never be replaced with the generic cube.
const MERGEABLE_TYPES: Array[BlockData.Type] = [BlockData.Type.WOOD, BlockData.Type.WATER]

func _rebuild_mesh(cell: Vector3i) -> void:
	var block: BlockData = GridManager.get_block(cell)
	if block == null or not is_instance_valid(block.node):
		return
	if not MERGEABLE_TYPES.has(block.type):
		return
	var mesh_instance: MeshInstance3D = block.node.get_node_or_null("MeshInstance3D")
	if mesh_instance == null:
		return

	var neighbors: Dictionary = GridManager.get_neighbors(cell)
	var hidden_dirs: Dictionary = {}
	for dir in neighbors:
		if neighbors[dir].type == block.type:
			hidden_dirs[dir] = true

	mesh_instance.mesh = BlockMeshBuilder.build(hidden_dirs)

	if block.type == BlockData.Type.WATER:
		_update_water_edge_mask(mesh_instance, hidden_dirs)

## Tells the water shader which top-face edges are true pool boundaries
## (show foam) vs touching another water cell (internal seam, suppress foam)
## — same neighbor check that hides the geometry, reused so a connected pool
## reads as one surface instead of a grid of foam-edged tiles.
func _update_water_edge_mask(mesh_instance: MeshInstance3D, hidden_dirs: Dictionary) -> void:
	var material: ShaderMaterial = mesh_instance.get_surface_override_material(0)
	if material == null:
		return
	var mask := Vector4(1.0, 1.0, 1.0, 1.0)
	if hidden_dirs.has(Vector3i(1, 0, 0)):
		mask.x = 0.0
	if hidden_dirs.has(Vector3i(-1, 0, 0)):
		mask.y = 0.0
	if hidden_dirs.has(Vector3i(0, 0, 1)):
		mask.z = 0.0
	if hidden_dirs.has(Vector3i(0, 0, -1)):
		mask.w = 0.0
	material.set_shader_parameter("edge_mask", mask)
