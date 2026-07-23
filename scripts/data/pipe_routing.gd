class_name PipeRouting
extends RefCounted

## Minecraft-pipe-style auto-connect: a bamboo pipe opens toward EVERY adjacent
## pipe/source, so any combination forms automatically — straight, elbow, T,
## cross, even 3D junctions. Single source of truth used by pipe_block (builds a
## stub toward each connection) and StreamManager (routes water through them,
## branching at junctions).

const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)

## The neighbour directions that are a PIPE or a SOURCE.
static func connections(cell: Vector3i) -> Array:
	var conns: Array = []
	for d in GridManager.DIRECTIONS:
		var b: BlockData = GridManager.get_block(cell + d)
		if b != null and (b.type == BlockData.Type.PIPE or b.type == BlockData.Type.SOURCE):
			conns.append(d)
	return conns

## Open ports for water routing: the connections, or a plain vertical pass-through
## when the pipe stands alone (so a lone connector under a source still drops it).
static func ports_for(cell: Vector3i) -> Array:
	var c: Array = connections(cell)
	return c if not c.is_empty() else [UP, DOWN]
