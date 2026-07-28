extends Node

## A brief burst of glowing motes at the given position — triggered whenever
## a bell rings. Simplification: the plan calls for a night-only flicker
## loop, but there's no day/night cycle yet, so this fires on every strike
## as a one-shot burst instead (fade-out via particle lifetime, not a true
## sine-wave flicker).
func burst_at(pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 2.5
	particles.one_shot = true
	particles.explosiveness = 0.8

	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 0.05
	particles.initial_velocity_max = 0.2
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 0.03
	particles.scale_amount_max = 0.06

	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.albedo_color = Color(1.0, 0.95, 0.4, 1.0)
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ShaderBudget.glow(particle_material, Color(1.0, 0.9, 0.3), 2.0)
	quad.material = particle_material
	particles.mesh = quad

	add_child(particles)
	particles.global_position = pos
	particles.emitting = true

	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)
