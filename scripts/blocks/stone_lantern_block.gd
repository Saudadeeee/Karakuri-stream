extends StaticBody3D

## Đèn đá (stone lantern). A gentle warm glow that breathes slowly — the
## emissive panels catch the bloom pass, so on the night map the garden fills
## with little pools of lantern light. Reuses the lantern art model; its pale
## panels are switched to an emissive material here.

const MODEL: PackedScene = preload("res://assets/3DModel/generated/lantern.glb")
const GLOW := Color(1.0, 0.85, 0.55)

var grid_cell: Vector3i
var _glow_mats: Array[StandardMaterial3D] = []
var _phase: float = randf() * TAU

func _ready() -> void:
	# Same uprighting trick as the scenery ring: the GLB lies on its side, and
	# the straightening rotation must live on a CHILD (local_aabb ignores the
	# queried root's own transform), so fit the wrapper.
	var model: Node3D = MODEL.instantiate()
	var wrap := Node3D.new()
	wrap.add_child(model)
	add_child(wrap)
	var box: AABB = MeshFit.local_aabb(wrap)
	if box.size.y < maxf(box.size.x, box.size.z) * 0.9:
		# Rotate about the axis PERPENDICULAR to the long side, so the long
		# side becomes vertical (the model may lie along X or along Z).
		if box.size.x >= box.size.z:
			model.rotation.z = PI / 2.0
		else:
			model.rotation.x = PI / 2.0
	MeshFit.fit_bottom(wrap, 0.85, -0.5)
	MeshFit.matte(wrap)
	_light_up(wrap)
	_add_real_light()

## An emissive material only makes the LANTERN look bright — it puts nothing on
## the ground around it. A stone lantern that lights nothing is just a glowing
## ornament, so it now casts a real pool of warm light.
##
## Shadows stay OFF even on desktop: an omni shadow costs a cubemap pass per
## light, and a garden can hold a lot of lanterns. The pool of light is the whole
## point; the shadows are not.
func _add_real_light() -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = GLOW
	lamp.light_energy = 1.5
	lamp.omni_range = 4.2
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 0.15, 0)
	add_child(lamp)
	_lamp = lamp

var _lamp: OmniLight3D

## Turn every pale surface into a soft emitter (the paper panels).
func _light_up(root: Node) -> void:
	for node in root.get_children():
		_light_up(node)
	if not (root is MeshInstance3D):
		return
	var mi: MeshInstance3D = root
	if mi.mesh == null:
		return
	for s in range(mi.mesh.get_surface_count()):
		var m: Material = mi.get_active_material(s)
		if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_color.get_luminance() > 0.72:
			var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
			ShaderBudget.glow(d, GLOW, 1.1)
			mi.set_surface_override_material(s, d)
			_glow_mats.append(d)

func _process(_delta: float) -> void:
	if _glow_mats.is_empty():
		return
	# Slow candle breathing — and on the NIGHT map, when the machine is
	# playing, the lantern eases brighter on every downbeat (a breath, never a
	# blink): the garden becomes a light instrument.
	var t: float = Time.get_ticks_msec() / 1000.0
	var e: float = 1.1 + sin(t * 1.7 + _phase) * 0.25
	if MapThemes.current == 3 and StreamManager.is_playing():
		e += 0.9 * pow(1.0 - StreamManager.beat_phase(), 2.0)
	for m in _glow_mats:
		m.emission_energy_multiplier = lerpf(m.emission_energy_multiplier, e, 0.25)
	# The cast light breathes with the panels, or the pool on the ground would sit
	# dead still while the lantern itself flickers.
	if is_instance_valid(_lamp):
		_lamp.light_energy = lerpf(_lamp.light_energy, e * 1.35, 0.25)
