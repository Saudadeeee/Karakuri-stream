extends Node

## Ambient scenery ringing the floating island — pines, bushes, reeds, rocks,
## a lantern, a bonsai, a THEME FEATURE TREE (sakura / maple / snow pine /
## lantern) — plus a distant ring of backdrop mountains. Everything is
## recoloured per map theme (MapThemes): foliage lerps to the theme colour and
## mountains take the theme tint, so each map reads differently at a glance.
## `rebuild()` re-places it all — called at startup and when the menu switches
## theme. Purely decorative backdrop; never touches the block grid.

const PINE := preload("res://assets/3DModel/generated/pine_tree.glb")
const BUSH := preload("res://assets/3DModel/generated/bush.glb")
const REEDS := preload("res://assets/3DModel/generated/reeds.glb")
const ROCKS := preload("res://assets/3DModel/generated/rock_cluster.glb")
const LANTERN := preload("res://assets/3DModel/generated/lantern.glb")
const BONSAI := preload("res://assets/3DModel/generated/bonsai.glb")
const SAKURA := preload("res://assets/3DModel/generated/sakura_tree.glb")
const MOUNTAIN := preload("res://assets/3DModel/generated/mountain.glb")

## (scene_key, angle°, radius, height). "feature" resolves per theme.
const PROPS: Array = [
	["pine", 20.0, 7.2, 1.9],
	["feature", 45.0, 7.7, 2.5],
	["bush", 65.0, 7.6, 0.9],
	["rocks", 110.0, 7.4, 0.9],
	["reeds", 150.0, 7.0, 1.5],
	["lantern", 195.0, 7.5, 1.7],
	["bush", 235.0, 7.3, 0.8],
	["feature", 258.0, 7.7, 2.3],
	["pine", 285.0, 7.6, 1.6],
	["bonsai", 315.0, 7.1, 1.1],
	["rocks", 345.0, 7.5, 0.8],
]

## Distant backdrop mountains: (angle°, radius, height, y).
const MOUNTAINS: Array = [
	[10.0, 34.0, 26.0, -12.0], [55.0, 40.0, 20.0, -11.0],
	[95.0, 32.0, 30.0, -13.0], [140.0, 38.0, 22.0, -11.0],
	[185.0, 36.0, 27.0, -12.5], [230.0, 42.0, 19.0, -10.0],
	[275.0, 33.0, 29.0, -13.0], [320.0, 39.0, 23.0, -11.0],
]

func _ready() -> void:
	MapThemes.load_current()
	# Defer so the main scene (ground/island) exists first.
	rebuild.call_deferred()

## Wipe + re-place everything for the CURRENT theme.
func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var t: Dictionary = MapThemes.theme()
	for p in PROPS:
		_place_ring_model(_scene_for(p[0], t), deg_to_rad(p[1]), p[2], p[3], 0.0, t)
	for m in MOUNTAINS:
		_place_ring_model(MOUNTAIN, deg_to_rad(m[0]), m[1], m[2], m[3], t, true)

func _scene_for(key: String, t: Dictionary) -> PackedScene:
	match key:
		"pine": return PINE
		"bush": return BUSH
		"reeds": return REEDS
		"rocks": return ROCKS
		"lantern": return LANTERN
		"bonsai": return BONSAI
		"feature":
			match t["feature"]:
				"sakura": return SAKURA
				"maple": return PINE      # pine silhouette, maple-orange foliage
				"lantern": return LANTERN
				_: return PINE
	return PINE

func _place_ring_model(scene: PackedScene, ang: float, radius: float, height: float, y: float, t: Dictionary, is_mountain: bool = false) -> void:
	var model: Node3D = scene.instantiate()
	# Wrapper: MeshFit.local_aabb treats the queried root's own transform as
	# identity, so any straightening rotation must live on a CHILD (the model)
	# and the fit must run on the wrapper for the rotation to count.
	var holder := Node3D.new()
	holder.add_child(model)
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(cos(ang) * radius, y, sin(ang) * radius)
	root.rotation.y = ang
	root.add_child(holder)
	# The lantern GLB is authored lying on its side — stand it up before fitting
	# (a standing lantern is TALLER than wide; wider-than-tall = fallen).
	if scene == LANTERN:
		var box: AABB = MeshFit.local_aabb(holder)
		if box.size.y < maxf(box.size.x, box.size.z) * 0.9:
			# Long side may run along X or Z — rotate about the other axis.
			if box.size.x >= box.size.z:
				model.rotation.z = PI / 2.0
			else:
				model.rotation.x = PI / 2.0
	MeshFit.fit_bottom(holder, height, 0.0)
	MeshFit.matte(holder)
	if is_mountain:
		var tint: Color = t["mountain_tint"]
		if tint != Color(1, 1, 1):
			_tint_all(holder, tint)
	else:
		MeshFit.recolor_foliage(holder, t["foliage"])

## Multiply every surface's albedo (mountains take the theme haze tint).
func _tint_all(root: Node, mul: Color) -> void:
	for node in root.get_children():
		_tint_all(node, mul)
	if not (root is MeshInstance3D):
		return
	var mi: MeshInstance3D = root
	if mi.mesh == null:
		return
	for s in range(mi.mesh.get_surface_count()):
		var m: Material = mi.get_active_material(s)
		if m is StandardMaterial3D:
			var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
			d.albedo_color = Color(d.albedo_color.r * mul.r, d.albedo_color.g * mul.g, d.albedo_color.b * mul.b, d.albedo_color.a)
			mi.set_surface_override_material(s, d)
