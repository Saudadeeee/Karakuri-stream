extends Node

## Ambient scenery ringing the floating island — pines, bushes, reeds, rocks,
## a lantern and a bonsai — purely decorative backdrop so the diorama feels like
## a little garden, not a bare platform. Placed once at startup at fixed spots
## around the rim (deterministic, so it never fights the build area in the
## centre). Each prop is a styled art model, fitted and flattened to matte.

const PINE := preload("res://assets/3DModel/generated/pine_tree.glb")
const BUSH := preload("res://assets/3DModel/generated/bush.glb")
const REEDS := preload("res://assets/3DModel/generated/reeds.glb")
const ROCKS := preload("res://assets/3DModel/generated/rock_cluster.glb")
const LANTERN := preload("res://assets/3DModel/generated/lantern.glb")
const BONSAI := preload("res://assets/3DModel/generated/bonsai.glb")

## (scene, angle°, radius, height, y). Ring sits just inside the island rim.
const PROPS: Array = [
	[PINE, 20.0, 7.2, 1.9, 0.0],
	[BUSH, 65.0, 7.6, 0.9, 0.0],
	[ROCKS, 110.0, 7.4, 0.9, 0.0],
	[REEDS, 150.0, 7.0, 1.5, 0.0],
	[LANTERN, 195.0, 7.5, 1.7, 0.0],
	[BUSH, 235.0, 7.3, 0.8, 0.0],
	[PINE, 275.0, 7.6, 1.6, 0.0],
	[BONSAI, 310.0, 7.1, 1.1, 0.0],
	[ROCKS, 345.0, 7.5, 0.8, 0.0],
]

func _ready() -> void:
	# Defer so the main scene (ground/island) exists first.
	call_deferred("_place_all")

func _place_all() -> void:
	for p in PROPS:
		var scene: PackedScene = p[0]
		var ang: float = deg_to_rad(p[1])
		var radius: float = p[2]
		var height: float = p[3]
		var y: float = p[4]
		var model: Node3D = scene.instantiate()
		var root := Node3D.new()
		add_child(root)
		root.position = Vector3(cos(ang) * radius, y, sin(ang) * radius)
		root.rotation.y = ang
		root.add_child(model)
		MeshFit.fit_bottom(model, height, 0.0)
		MeshFit.matte(model)
