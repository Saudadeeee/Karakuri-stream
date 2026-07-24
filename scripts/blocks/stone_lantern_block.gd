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
			d.emission_enabled = true
			d.emission = GLOW
			d.emission_energy_multiplier = 1.1
			mi.set_surface_override_material(s, d)
			_glow_mats.append(d)

func _process(_delta: float) -> void:
	if _glow_mats.is_empty():
		return
	# Slow candle breathing.
	var t: float = Time.get_ticks_msec() / 1000.0
	var e: float = 1.1 + sin(t * 1.7 + _phase) * 0.25
	for m in _glow_mats:
		m.emission_energy_multiplier = e
