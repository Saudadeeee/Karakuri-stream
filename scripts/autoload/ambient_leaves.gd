extends Node

## Theme-driven ambient drift particles over the whole diorama — WHAT drifts is
## the map theme's signature, readable at a glance: pink sakura petals (Xuân),
## orange maple leaves (Thu), white snowflakes (Tuyết), glowing fireflies (Đêm —
## these drift UP and glow instead of falling). Rebuilt on theme switch.

var _particles: CPUParticles3D

func _ready() -> void:
	rebuild.call_deferred()

func rebuild() -> void:
	if is_instance_valid(_particles):
		_particles.queue_free()
	var d: Dictionary = MapThemes.theme()["drift"]

	_particles = CPUParticles3D.new()
	_particles.amount = QualityManager.particles(d["amount"])
	_particles.lifetime = 10.0
	_particles.preprocess = 7.0
	_particles.position = Vector3(0.0, 7.0, 0.0)
	_particles.visibility_aabb = AABB(Vector3(-14, -12, -14), Vector3(28, 24, 28))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var rising: bool = d["gravity"] > 0.0   # fireflies float up, everything else falls
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(11.0, 2.0 if rising else 1.0, 11.0)
	_particles.direction = Vector3(0.2, 1.0 if rising else -1.0, 0.1)
	_particles.spread = 40.0 if rising else 25.0
	_particles.gravity = Vector3(0.0, d["gravity"], 0.0)
	_particles.initial_velocity_min = 0.1 if rising else 0.2
	_particles.initial_velocity_max = 0.3 if rising else 0.6
	_particles.angular_velocity_min = -60.0
	_particles.angular_velocity_max = 60.0
	_particles.scale_amount_min = 0.5
	_particles.scale_amount_max = 1.1
	if rising:
		_particles.position = Vector3(0.0, 1.5, 0.0)

	var quad := QuadMesh.new()
	quad.size = d["size"]
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.albedo_color = d["color"]
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.cull_mode = BaseMaterial3D.CULL_DISABLED
	if d["glow"]:
		# Bloom picks these up and they read as fireflies. Without bloom they just
		# have to be bright; see ShaderBudget.glow.
		ShaderBudget.glow(qm, d["color"], 2.2)
	quad.material = qm
	_particles.mesh = quad

	add_child(_particles)
