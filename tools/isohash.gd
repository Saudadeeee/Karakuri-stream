extends SceneTree

## Dev-only: proves an IsoSurface refactor did not change the geometry.
## Builds fixed synthetic density fields, runs IsoSurface.build, and prints an
## md5 of the vertex/index buffers. Run before and after touching the extractor:
## identical hashes = identical mesh, no photo comparison needed.
##
##   godot --headless --path . --script tools/isohash.gd

func _field(dims: Vector3i, cells: Array) -> PackedFloat32Array:
	# Mirror of VoxelSurfaceManager's union-of-rounded-boxes, fixed constants.
	var samples := PackedFloat32Array()
	samples.resize(dims.x * dims.y * dims.z)
	var spacing := 1.0 / 3.0
	for z in dims.z:
		for y in dims.y:
			for x in dims.x:
				var p := Vector3(x, y, z) * spacing
				var d := 0.0
				for c in cells:
					var ax: float = 1.0 - smoothstep(0.34, 0.66, absf(p.x - c.x))
					var ay: float = 1.0 - smoothstep(0.34, 0.66, absf(p.y - c.y))
					var az: float = 1.0 - smoothstep(0.34, 0.66, absf(p.z - c.z))
					d += minf(ax, minf(ay, az))
				samples[x + y * dims.x + z * dims.x * dims.y] = d
	return samples

func _hash_mesh(mesh: ArrayMesh) -> String:
	if mesh == null or mesh.get_surface_count() == 0:
		return "EMPTY"
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(v.to_byte_array())
	ctx.update(n.to_byte_array())
	ctx.update(idx.to_byte_array())
	return "%s v=%d i=%d" % [ctx.finish().hex_encode(), v.size(), idx.size()]

func _init() -> void:
	var layouts := {
		"single": [Vector3(1.5, 1.5, 1.5)],
		"bar3": [Vector3(1.5, 1.5, 1.5), Vector3(2.5, 1.5, 1.5), Vector3(3.5, 1.5, 1.5)],
		"deck": [],
		"steps": [Vector3(1.5, 1.5, 1.5), Vector3(2.5, 1.5, 1.5), Vector3(2.5, 2.5, 1.5), Vector3(2.5, 2.5, 2.5)],
	}
	for x in 5:
		for z in 5:
			layouts["deck"].append(Vector3(1.5 + x, 1.5, 1.5 + z))
	for name in layouts:
		var cells: Array = layouts[name]
		var dims := Vector3i(24, 12, 24)
		var samples := _field(dims, cells)
		var t0 := Time.get_ticks_usec()
		var mesh := IsoSurface.build(samples, dims, 1.0 / 3.0, 0.5)
		var t1 := Time.get_ticks_usec()
		var h := _hash_mesh(mesh)
		# build_async is a hand-kept mirror of build(); prove it stayed faithful.
		var amesh: ArrayMesh = await IsoSurface.build_async(samples, dims, 1.0 / 3.0, 0.5, 1 << 30)
		var ah := _hash_mesh(amesh)
		print("ISOHASH %-8s %s  build=%d us  async=%s" % [
			name, h, t1 - t0, "MATCH" if ah == h else "*** MISMATCH: %s ***" % ah])
	quit()
