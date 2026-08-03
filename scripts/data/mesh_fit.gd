class_name MeshFit
extends RefCounted

## Fits an imported model (.glb/.obj — arbitrary internal node tree, arbitrary
## authored scale/pivot) into the game's 1x1x1 cell convention. Imported art
## rarely comes centred or unit-sized, so both block scripts route their model
## through here instead of hand-tuning a transform per asset.

## Combined AABB of every MeshInstance3D under `root`, expressed in root-LOCAL
## space (root's own transform is treated as identity). Lets us measure/centre a
## model before it's added to the tree.
static func local_aabb(root: Node) -> AABB:
	var found := [false]
	# AABB is a value type — MUST capture the returned box (the accumulator
	# threads it through returns). Dropping it left the box empty → centre (0,0,0)
	# → fit_* never re-centred Blockbench models (built at 0..16), so a gear
	# orbited an off-origin point instead of spinning in place.
	var box: AABB = _accumulate(root, Transform3D.IDENTITY, AABB(), found, true)
	return box if found[0] else AABB()

static func _accumulate(node: Node, xform: Transform3D, box: AABB, found: Array, is_root: bool) -> AABB:
	var t: Transform3D = xform
	if node is Node3D and not is_root:
		t = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var a: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
		if not found[0]:
			box = a
			found[0] = true
		else:
			box = box.merge(a)
	for child in node.get_children():
		box = _accumulate(child, t, box, found, false)
	return box

## Scale so the largest horizontal extent = `target`, then translate so the
## model's centre sits at the parent origin. For spinning parts (gears) that
## must rotate about their own centre.
static func fit_centered(model: Node3D, target: float) -> void:
	var box: AABB = local_aabb(model)
	var max_dim: float = maxf(box.size.x, box.size.z)
	if max_dim <= 0.0:
		return
	var s: float = target / max_dim
	model.scale = Vector3(s, s, s)
	model.position = -box.get_center() * s

## The game's matte clay material, built from a colour — the procedural-geometry
## counterpart to `matte()` (which flattens materials that came in with a model).
## Clock movement, tea doll, pinwheel, pipes, decor and island rocks each carried
## a byte-identical private copy of this; one shared factory instead, so the look
## can only drift in one place. Deliberately does NOT touch `metallic_specular`:
## roughness 1.0 already kills the highlight on these flat-shaded props, and the
## six originals left it at default — keeping it that way means no visual change.
static func flat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.metallic = 0.0
	return m

## Forces every material to the game's matte clay look. glTF import gives
## StandardMaterial3D with default specular 0.5, so smooth-shaded imported props
## catch bright highlights (a grey stone bell reads as white, wood as cream) —
## clashing with the flat wood/water shaders.
##
## Flattens the shared imported material IN PLACE rather than duplicating it
## per instance. Every instance of a model gets the identical treatment, so a
## copy each was pure cost: one material per instance in memory, and a
## `set_surface_override_material` call that makes the engine query the slot
## before anything is in it — thirty "Parameter material is null" lines per
## run. `tint` still overrides per surface, because that one genuinely differs
## between instances.
static func matte(root: Node) -> void:
	for node in root.get_children():
		matte(node)
	if not (root is MeshInstance3D):
		return
	var mi: MeshInstance3D = root
	if mi.mesh == null:
		return
	for s in range(mi.mesh.get_surface_count()):
		var m: Material = mi.get_active_material(s)
		if m is StandardMaterial3D:
			var sm: StandardMaterial3D = m
			sm.metallic = 0.0
			sm.metallic_specular = 0.0
			sm.roughness = 1.0

## ONE SURFACE PER MESH, colours carried per vertex.
##
## The imported props come out of glTF with a surface (and a material) per
## colour: 3-4 per block. Every one of those is a draw call — and then again for
## the shadow pass, and again per cascade, which is why a garden of 800 blocks
## was measured at 13,498 draw calls and 61 fps. Nothing about them differs
## except albedo, so they merge into one vertex-coloured surface exactly the way
## house cells do (see MeshBatch.build_merged).
##
## Surfaces that carry more than a colour — a texture, emission, transparency —
## are left alone with their own material. There are almost none, and guessing
## wrong there is visible.
##
## Baked meshes are CACHED by their source mesh and the exact colours baked into
## them, so every instance of the same prop in the same variant shares one
## ArrayMesh instead of building its own.
##
## Must run AFTER `tint`/`recolor_foliage`: baking flattens away the per-surface
## materials those work through. `tint` refuses to touch a baked mesh rather than
## silently doing nothing.
static var _bake_cache: Dictionary = {}
static var _bake_mat: StandardMaterial3D

const BAKED_META := "mesh_fit_baked"

static func baked_material() -> StandardMaterial3D:
	if _bake_mat == null:
		_bake_mat = flat(Color.WHITE)
		_bake_mat.vertex_color_use_as_albedo = true
	return _bake_mat

static func bake(root: Node) -> void:
	for node in root.get_children():
		bake(node)
	if not (root is MeshInstance3D):
		return
	var mi: MeshInstance3D = root
	if mi.mesh == null or mi.has_meta(BAKED_META):
		return
	var count: int = mi.mesh.get_surface_count()
	if count < 2:
		return

	# Key on the source mesh plus the colours actually in effect, so two instances
	# of the same prop in different variants do not share a baked mesh.
	var key: String = str(mi.mesh.get_rid().get_id())
	var plain: Array = []      # surfaces that can merge: [arrays, albedo]
	var keep: Array = []       # surfaces that cannot: [arrays, material]
	for i in count:
		var m: Material = mi.get_active_material(i)
		var arrays: Array = mi.mesh.surface_get_arrays(i)
		if m is StandardMaterial3D and _is_plain(m as StandardMaterial3D):
			var col: Color = (m as StandardMaterial3D).albedo_color
			plain.append([arrays, col])
			key += "|%s" % col.to_html()
		else:
			keep.append([arrays, m])
			key += "|x%d" % i
	if plain.size() < 2:
		return

	var mesh: ArrayMesh = _bake_cache.get(key)
	if mesh == null:
		mesh = ArrayMesh.new()
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for entry in plain:
			var arrays: Array = entry[0]
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# INDICES MATTER. An imported surface is an index buffer over a shared
			# vertex list, so concatenating the vertex arrays alone and calling the
			# result a triangle list turns every prop into a fan of shards — which
			# is exactly what it did before this loop kept them.
			var base: int = verts.size()
			var src: Variant = arrays[Mesh.ARRAY_INDEX]
			if src is PackedInt32Array and not (src as PackedInt32Array).is_empty():
				for i in (src as PackedInt32Array):
					idx.append(base + i)
			else:
				for i in v.size():
					idx.append(base + i)
			verts.append_array(v)
			var n: Variant = arrays[Mesh.ARRAY_NORMAL]
			if n is PackedVector3Array and (n as PackedVector3Array).size() == v.size():
				norms.append_array(n)
			else:
				# A surface with no normals would desync the arrays; give it
				# flat-up normals rather than dropping the whole merge.
				for _i in v.size():
					norms.append(Vector3.UP)
			for _i in v.size():
				cols.append(entry[1])
		var merged: Array = []
		merged.resize(Mesh.ARRAY_MAX)
		merged[Mesh.ARRAY_VERTEX] = verts
		merged[Mesh.ARRAY_NORMAL] = norms
		merged[Mesh.ARRAY_COLOR] = cols
		merged[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged)
		mesh.surface_set_material(0, baked_material())
		for entry in keep:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, entry[0])
			mesh.surface_set_material(mesh.get_surface_count() - 1, entry[1] as Material)
		_bake_cache[key] = mesh

	# Overrides were per-surface on the OLD surface list; they mean nothing now.
	for i in count:
		mi.set_surface_override_material(i, null)
	mi.mesh = mesh
	mi.set_meta(BAKED_META, true)

## Only a colour, nothing else. Anything with a texture, emission or blending is
## carrying information a vertex colour cannot.
static func _is_plain(m: StandardMaterial3D) -> bool:
	return m.albedo_texture == null and not m.emission_enabled 		and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED 		and m.next_pass == null

## Recolours the surfaces whose current albedo is close to `from` — used to
## retint one part of a multi-material model (e.g. the jelly body) to a variant
## colour while leaving the face (eyes/blush) untouched.
static func tint(root: Node, from: Color, to: Color, threshold: float = 0.18) -> void:
	if root == null:
		return
	if root is MeshInstance3D and (root as MeshInstance3D).has_meta(BAKED_META):
		# Loud on purpose: after bake() there are no per-surface materials left to
		# retint, so this would quietly produce the wrong colour forever.
		push_warning("MeshFit.tint on an already-baked mesh — bake must come last")
		return
	for node in root.get_children():
		tint(node, from, to, threshold)
	if not (root is MeshInstance3D):
		return
	var mi: MeshInstance3D = root
	if mi.mesh == null:
		return
	for s in range(mi.mesh.get_surface_count()):
		var m: Material = mi.get_active_material(s)
		if m is StandardMaterial3D:
			var sm: StandardMaterial3D = m
			var a: Color = sm.albedo_color
			var dist: float = absf(a.r - from.r) + absf(a.g - from.g) + absf(a.b - from.b)
			if dist < threshold:
				var d: StandardMaterial3D = sm.duplicate()
				d.albedo_color = to
				mi.set_surface_override_material(s, d)

## Recolours FOLIAGE — every surface whose albedo is green-dominant — toward
## `target` (lerp 0.85 keeps a hint of shading variation). Trunks/rocks/snow are
## untouched, so one prop set serves every seasonal map theme (autumn orange,
## frosted winter, moonlit night). No-op when `target` is the zero Color().
static func recolor_foliage(root: Node, target: Color) -> void:
	if root == null or target == Color():
		return
	for node in root.get_children():
		recolor_foliage(node, target)
	if not (root is MeshInstance3D):
		return
	var mi: MeshInstance3D = root
	if mi.mesh == null:
		return
	for s in range(mi.mesh.get_surface_count()):
		var m: Material = mi.get_active_material(s)
		if m is StandardMaterial3D:
			var a: Color = (m as StandardMaterial3D).albedo_color
			if a.g > a.r and a.g > a.b:
				var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
				d.albedo_color = a.lerp(target, 0.85)
				mi.set_surface_override_material(s, d)

## Scale to `target_height` tall, centre in X/Z, and rest the model's BASE on
## `floor_y` (cell bottom = -0.5 in local block space). For standing props (bell).
static func fit_bottom(model: Node3D, target_height: float, floor_y: float) -> void:
	var box: AABB = local_aabb(model)
	if box.size.y <= 0.0:
		return
	var s: float = target_height / box.size.y
	model.scale = Vector3(s, s, s)
	var c: Vector3 = box.get_center()
	model.position = Vector3(-c.x * s, floor_y - box.position.y * s, -c.z * s)
