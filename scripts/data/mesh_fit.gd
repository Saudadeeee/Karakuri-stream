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

## Forces every material to the game's matte clay look. glTF import gives
## StandardMaterial3D with default specular 0.5, so smooth-shaded imported props
## catch bright highlights (a grey stone bell reads as white, wood as cream) —
## clashing with the flat wood/water shaders. Duplicate each material (don't
## mutate the shared imported resource) and flatten it: no metal, no specular,
## full roughness. Keeps the authored base colour.
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
			var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
			d.metallic = 0.0
			d.metallic_specular = 0.0
			d.roughness = 1.0
			mi.set_surface_override_material(s, d)

## Recolours the surfaces whose current albedo is close to `from` — used to
## retint one part of a multi-material model (e.g. the jelly body) to a variant
## colour while leaving the face (eyes/blush) untouched.
static func tint(root: Node, from: Color, to: Color, threshold: float = 0.18) -> void:
	if root == null:
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
