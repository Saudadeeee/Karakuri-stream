extends Node

const CELL_SIZE: float = 1.0

const DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

signal block_placed(cell: Vector3i)
signal block_removed(cell: Vector3i)
signal grid_cleared

var _blocks: Dictionary = {} # Vector3i -> BlockData

## Secondary index so get_all_cells_of_type() doesn't have to scan every
## block in the grid to find the handful of a given type — without this,
## every reactive autoload (and GearManager every single frame) pays a cost
## proportional to the TOTAL block count instead of just the type it cares
## about, which turns a large build into an O(n²) mess as it's built up.
var _cells_by_type: Dictionary = {} # BlockData.Type -> Dictionary[Vector3i, true]

func has_block(cell: Vector3i) -> bool:
	return _blocks.has(cell)

func get_block(cell: Vector3i) -> BlockData:
	return _blocks.get(cell)

func set_block(cell: Vector3i, block: BlockData) -> void:
	if _blocks.has(cell):
		_unindex(cell, _blocks[cell].type)
	_blocks[cell] = block
	_index(cell, block.type)
	block_placed.emit(cell)

func remove_block(cell: Vector3i) -> void:
	if not _blocks.has(cell):
		return
	var block: BlockData = _blocks[cell]
	if is_instance_valid(block.node):
		block.node.queue_free()
	_unindex(cell, block.type)
	_blocks.erase(cell)
	block_removed.emit(cell)

## Wipes the whole grid in one shot instead of calling remove_block() per
## cell — a per-cell loop would trigger a full-grid rescan in every reactive
## autoload for every single block, which gets slow fast on a large build.
func clear_all() -> void:
	for block in _blocks.values():
		if is_instance_valid(block.node):
			block.node.queue_free()
	_blocks.clear()
	_cells_by_type.clear()
	grid_cleared.emit()

func _index(cell: Vector3i, type: BlockData.Type) -> void:
	if not _cells_by_type.has(type):
		_cells_by_type[type] = {}
	_cells_by_type[type][cell] = true

func _unindex(cell: Vector3i, type: BlockData.Type) -> void:
	if _cells_by_type.has(type):
		_cells_by_type[type].erase(cell)

func get_neighbors(cell: Vector3i) -> Dictionary:
	var neighbors: Dictionary = {}
	for dir in DIRECTIONS:
		var n_cell: Vector3i = cell + dir
		if _blocks.has(n_cell):
			neighbors[dir] = _blocks[n_cell]
	return neighbors

## Cells sit on the ground plane (world y=0): cell.y=0 spans world y [0, 1),
## so a block's bottom rests exactly on the floor instead of straddling it.
## X/Z stay centered on integer coordinates (no floor reference needed there).
func world_to_cell(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		roundi(world_pos.x / CELL_SIZE),
		floori(world_pos.y / CELL_SIZE),
		roundi(world_pos.z / CELL_SIZE)
	)

func cell_to_world(cell: Vector3i) -> Vector3:
	return Vector3(cell.x, cell.y + 0.5, cell.z) * CELL_SIZE

func get_all_cells_of_type(type: BlockData.Type) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if _cells_by_type.has(type):
		for cell in _cells_by_type[type]:
			cells.append(cell)
	return cells

## Every occupied cell regardless of type — used by SaveManager to serialize
## the whole grid. Not used by the per-type reactive autoloads (they use
## get_all_cells_of_type), so this doesn't need the same index treatment.
func get_all_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for cell in _blocks:
		cells.append(cell)
	return cells
