extends Node

func _ready() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 9.0
	particles.preprocess = 6.0
	particles.position = Vector3(0.0, 7.0, 0.0)
	particles.visibility_aabb = AABB(Vector3(-14, -12, -14), Vector3(28, 24, 28))

	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(11.0, 1.0, 11.0)
	mat.direction = Vector3(0.2, -1.0, 0.1)
	mat.spread = 25.0
	mat.gravity = Vector3(0.0, -0.35, 0.0)
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.angular_velocity_min = -60.0
	mat.angular_velocity_max = 60.0
	mat.scale_min = 0.5
	mat.scale_max = 1.1
	particles.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	leaf_mat.albedo_color = Color(0.82, 0.38, 0.14)
	leaf_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = leaf_mat
	particles.draw_pass_1 = quad

	add_child(particles)
