extends Node

## Theme-driven ambient drift particles over the whole diorama — WHAT drifts is
## the map theme's signature, readable at a glance: pink sakura petals (Xuân),
## orange maple leaves (Thu), white snowflakes (Tuyết), glowing fireflies (Đêm —
## these drift UP and glow instead of falling). Rebuilt on theme switch.

var _particles: GPUParticles3D

func _ready() -> void:
	rebuild.call_deferred()

func rebuild() -> void:
	if is_instance_valid(_particles):
		_particles.queue_free()
	var d: Dictionary = MapThemes.theme()["drift"]

	_particles = GPUParticles3D.new()
	_particles.amount = QualityManager.particles(d["amount"])
	_particles.lifetime = 10.0
	_particles.preprocess = 7.0
	_particles.position = Vector3(0.0, 7.0, 0.0)
	_particles.visibility_aabb = AABB(Vector3(-14, -12, -14), Vector3(28, 24, 28))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var rising: bool = d["gravity"] > 0.0   # fireflies float up, everything else falls
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(11.0, 2.0 if rising else 1.0, 11.0)
	mat.direction = Vector3(0.2, 1.0 if rising else -1.0, 0.1)
	mat.spread = 40.0 if rising else 25.0
	mat.gravity = Vector3(0.0, d["gravity"], 0.0)
	mat.initial_velocity_min = 0.1 if rising else 0.2
	mat.initial_velocity_max = 0.3 if rising else 0.6
	mat.angular_velocity_min = -60.0
	mat.angular_velocity_max = 60.0
	mat.scale_min = 0.5
	mat.scale_max = 1.1
	if rising:
		_particles.position = Vector3(0.0, 1.5, 0.0)
	_particles.process_material = mat

	var quad := QuadMesh.new()
	quad.size = d["size"]
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.albedo_color = d["color"]
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.cull_mode = BaseMaterial3D.CULL_DISABLED
	if d["glow"]:
		qm.emission_enabled = true
		qm.emission = d["color"]
		qm.emission_energy_multiplier = 2.2   # bloom picks these up → fireflies
	quad.material = qm
	_particles.draw_pass_1 = quad

	add_child(_particles)
