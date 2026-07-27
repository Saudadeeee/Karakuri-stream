extends Node
func _ready() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	for _f in range(10): await get_tree().process_frame

	# Exactly what a player does: place floor 1, then floor 2 on top of it.
	for label in ["bottom-then-top", "top-then-bottom"]:
		GridManager.clear_all()
		for _f in range(3): await get_tree().process_frame
		var order := [Vector3i(0,0,0), Vector3i(0,1,0)]
		if label == "top-then-bottom": order.reverse()
		for c in order:
			_place(game, c)
			for _f in range(3): await get_tree().process_frame
		for _f in range(5): await get_tree().process_frame
		for c in [Vector3i(0,0,0), Vector3i(0,1,0)]:
			var ctx := HouseShape.context(c)
			var n: Node3D = GridManager.get_block(c).node
			print("%-18s %s roof=%s terrace=%s spire=%s  tris=%d" % [
				label, str(c), ctx["roof"], HouseShape.is_terrace(c), HouseShape.has_spire(c), _tris(n)])
	print("ROOF DONE"); get_tree().quit()

## The real placement path: cell assigned BEFORE set_block, as PlacementController does.
func _place(root: Node, c: Vector3i) -> void:
	var n: Node3D = BlockFactory.instantiate(BlockData.Type.HOUSE)
	root.add_child(n)
	n.position = GridManager.cell_to_world(c)
	n.grid_cell = c
	var b := BlockData.new(BlockData.Type.HOUSE, n)
	b.state["variant"] = 0
	n.apply_variant(BlockVariants.get_variant(BlockData.Type.HOUSE, 0))
	GridManager.set_block(c, b)
	n.refresh_shape()

func _tris(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and n.mesh != null:
		for i in n.mesh.get_surface_count():
			var a: Array = n.mesh.surface_get_arrays(i)
			var idx = a[Mesh.ARRAY_INDEX]
			t += (idx.size()/3) if idx != null else (a[Mesh.ARRAY_VERTEX].size()/3)
	for c in n.get_children(): t += _tris(c)
	return t
