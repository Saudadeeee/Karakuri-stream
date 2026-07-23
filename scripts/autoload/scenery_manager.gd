extends Node

## Ambient scenery ringing the floating island — pines, bushes, reeds, rocks,
## a lantern, a bonsai and cherry-blossom (sakura) trees — plus a distant ring of
## hazy MOUNTAINS on the horizon and drifting sakura PETALS, so the diorama reads
## as a little spring garden floating in the sky rather than a bare platform.
## Placed once at startup at fixed spots (deterministic, so it never fights the
## build area in the centre). Each prop is a styled art model, fitted + matte.

const PINE := preload("res://assets/3DModel/generated/pine_tree.glb")
const BUSH := preload("res://assets/3DModel/generated/bush.glb")
const REEDS := preload("res://assets/3DModel/generated/reeds.glb")
const ROCKS := preload("res://assets/3DModel/generated/rock_cluster.glb")
const LANTERN := preload("res://assets/3DModel/generated/lantern.glb")
const BONSAI := preload("res://assets/3DModel/generated/bonsai.glb")
const SAKURA := preload("res://assets/3DModel/generated/sakura_tree.glb")
const MOUNTAIN := preload("res://assets/3DModel/generated/mountain.glb")

## (scene, angle°, radius, height, y). Ring sits just inside the island rim.
const PROPS: Array = [
	[PINE, 20.0, 7.2, 1.9, 0.0],
	[SAKURA, 45.0, 7.7, 2.5, 0.0],
	[BUSH, 65.0, 7.6, 0.9, 0.0],
	[ROCKS, 110.0, 7.4, 0.9, 0.0],
	[REEDS, 150.0, 7.0, 1.5, 0.0],
	[LANTERN, 195.0, 7.5, 1.7, 0.0],
	[BUSH, 235.0, 7.3, 0.8, 0.0],
	[SAKURA, 258.0, 7.7, 2.3, 0.0],
	[PINE, 285.0, 7.6, 1.6, 0.0],
	[BONSAI, 315.0, 7.1, 1.1, 0.0],
	[ROCKS, 345.0, 7.5, 0.8, 0.0],
]

## Distant backdrop mountains, far outside the island, based low so their peaks
## rise on the horizon through the fog. (angle°, radius, height, y).
const MOUNTAINS: Array = [
	[10.0, 34.0, 26.0, -12.0],
	[55.0, 40.0, 20.0, -11.0],
	[95.0, 32.0, 30.0, -13.0],
	[140.0, 38.0, 22.0, -11.0],
	[185.0, 36.0, 27.0, -12.5],
	[230.0, 42.0, 19.0, -10.0],
	[275.0, 33.0, 29.0, -13.0],
	[320.0, 39.0, 23.0, -11.0],
]

func _ready() -> void:
	# Defer so the main scene (ground/island) exists first.
	call_deferred("_place_all")

func _place_all() -> void:
	for p in PROPS:
		_place_ring_model(p[0], deg_to_rad(p[1]), p[2], p[3], p[4])
	for m in MOUNTAINS:
		_place_ring_model(MOUNTAIN, deg_to_rad(m[0]), m[1], m[2], m[3])
	_add_sakura_petals()

func _place_ring_model(scene: PackedScene, ang: float, radius: float, height: float, y: float) -> void:
	var model: Node3D = scene.instantiate()
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(cos(ang) * radius, y, sin(ang) * radius)
	root.rotation.y = ang
	root.add_child(model)
	MeshFit.fit_bottom(model, height, 0.0)
	MeshFit.matte(model)

## Soft pink cherry-blossom petals drifting down over the whole diorama — the
## spring counterpart to the orange autumn leaves (AmbientLeaves).
func _add_sakura_petals() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 11.0
	particles.preprocess = 7.0
	particles.position = Vector3(0.0, 7.5, 0.0)
	particles.visibility_aabb = AABB(Vector3(-14, -12, -14), Vector3(28, 24, 28))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(10.0, 1.0, 10.0)
	mat.direction = Vector3(0.3, -1.0, 0.15)
	mat.spread = 30.0
	mat.gravity = Vector3(0.0, -0.22, 0.0)   # gentler than leaves — petals float
	mat.initial_velocity_min = 0.15
	mat.initial_velocity_max = 0.5
	mat.angular_velocity_min = -80.0
	mat.angular_velocity_max = 80.0
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	particles.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.09)  # small petal, wider than tall
	var petal_mat := StandardMaterial3D.new()
	petal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	petal_mat.albedo_color = Color(0.96, 0.72, 0.84)  # soft sakura pink
	petal_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	petal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = petal_mat
	particles.draw_pass_1 = quad

	add_child(particles)
