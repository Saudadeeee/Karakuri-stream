extends Node

## Read the isosurface's normals STRAIGHT OUT OF THE MESH.
##
## The previous attempt to diagnose this sampled pixels out of a render, which is
## indirect and — as it turned out — easy to sample in the wrong place. The mesh
## arrays are right there; ask them.
##
## Builds a flat slab of wood, then reports, for the vertices sitting on the top
## face, what normal the builder gave them. A slab's top face must be (0, 1, 0).
##   godot --path . --headless tools/normcheck.tscn

func _ready() -> void:
	var game: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	for _f in range(12):
		await get_tree().process_frame
	GridManager.clear_all()
	await get_tree().process_frame
	for i in 4:
		var c := Vector3i(i - 2, 0, 0)
		var n: Node3D = BlockFactory.instantiate(BlockData.Type.WOOD)
		game.add_child(n)
		n.position = GridManager.cell_to_world(c)
		GridManager.set_block(c, BlockData.new(BlockData.Type.WOOD, n))
	for _f in range(8):
		await get_tree().process_frame

	var found := false
	for child in VoxelSurfaceManager.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		found = true
		print("NORM mesh at %s: %d verts, %d tris, normals=%s"
				% [mi.position, verts.size(), idx.size() / 3, str(norms.size() == verts.size())])

		# Highest vertices = the top face of a one-cell-tall slab.
		var top_y: float = -1e9
		for v in verts:
			top_y = maxf(top_y, v.y)
		var up_agree := 0
		var up_against := 0
		var sample := 0
		for i in verts.size():
			if absf(verts[i].y - top_y) > 0.05:
				continue
			var n: Vector3 = norms[i]
			if n.y > 0.3:
				up_agree += 1
			elif n.y < -0.3:
				up_against += 1
			if sample < 5:
				print("   top vert %s -> normal (%.2f, %.2f, %.2f)  len=%.3f"
						% [verts[i], n.x, n.y, n.z, n.length()])
				sample += 1
		print("NORM top-face vertices: %d point UP, %d point DOWN" % [up_agree, up_against])

		# And how consistent is the winding? A closed surface built with one
		# convention has every triangle's face normal agreeing with its vertices'.
		var agree := 0
		var disagree := 0
		for t in range(0, idx.size(), 3):
			var a: int = idx[t]
			var b: int = idx[t + 1]
			var c: int = idx[t + 2]
			var fn: Vector3 = (verts[b] - verts[a]).cross(verts[c] - verts[a])
			if fn.length_squared() < 1e-12:
				continue
			# Compare against the direction away from the slab's middle.
			var centre: Vector3 = (verts[a] + verts[b] + verts[c]) / 3.0
			var outward: Vector3 = centre - Vector3(verts.size() * 0.0, top_y * 0.5, 0.0)
			if fn.normalized().dot(outward.normalized()) > 0.0:
				agree += 1
			else:
				disagree += 1
		print("NORM winding: %d triangles face outward, %d face inward" % [agree, disagree])
	if not found:
		print("NORM no isosurface mesh found")
	print("NORM DONE")
	get_tree().quit()
