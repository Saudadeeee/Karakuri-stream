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
## clashing with the flat wood/water shaders. Flatten it: no metal, no specular,
## full roughness. Keeps the authored base colour.
##
## This is also where an imported material's SHADER FEATURE FLAGS get normalised,
## because this is the one pass every .glb in the game already goes through. See
## `ShaderBudget`: each distinct flag combination is a separate program the
## browser has to compile before the first frame can finish, at a large fraction
## of a second each under ANGLE. Every scenery model shipped with double-sided
## materials — that alone was one extra program plus double the raster work on
## rocks and tree trunks that can never be seen from inside.
##
## The material is edited IN PLACE rather than duplicated per instance. Every
## caller wants the same answer — matte is a property of the art direction, not
## of one bell — so a duplicate per surface per instance meant thirty copies of
## one rock's material and thirty `set_surface_override_material` calls, each of
## which made the engine log `Parameter "material" is null` while refreshing the
## instance shader parameters of a slot that had nothing in it yet. Harmless, and
## invisible on the desktop GL path, but it filled the browser console with
## errors, and a console full of errors is indistinguishable from a broken build
## when someone else is reading it.
##
## `tint()` below still duplicates, because recolouring IS per instance.
##
## `double_sided` is for props that really are flat sheets: crossed reed planes,
## a lily pad, a flag. Those knowingly spend the extra program.
static func matte(root: Node, double_sided: bool = false) -> void:
	for node in root.get_children():
		matte(node, double_sided)
	if not (root is MeshInstance3D):
		return
	var mi: MeshInstance3D = root
	if mi.mesh == null:
		return
	for s in range(mi.mesh.get_surface_count()):
		var m: Material = mi.get_active_material(s)
		if m is StandardMaterial3D:
			ShaderBudget.normalise(m as StandardMaterial3D, double_sided)

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
