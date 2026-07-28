extends Node

## Where does the browser's boot time actually go?
##
## First answer from this harness: a scene containing a Camera3D, one light and
## NOTHING ELSE cost 26 seconds, after which the first lit box cost 13 ms. So the
## bill is not the game's art — it is whatever the renderer compiles the moment a
## 3D viewport starts drawing. This version splits that 26 seconds up.
##
## Each step adds one thing and reports what it cost. Anything expensive here is
## an engine feature, which means the lever is a project/environment setting, not
## a mesh.
##   godot --path . --rendering-driver opengl3 tools/floor.tscn

var _cam: Camera3D
var _env: WorldEnvironment

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("f4efe2")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	print("FLOOR 2d-only ", Time.get_ticks_msec() - t0, "ms")

	# 1. A camera on its own. This alone starts the 3D pipeline.
	await _time("camera only", func():
		_cam = Camera3D.new()
		_cam.position = Vector3(0, 0.4, 2.4)
		add_child(_cam)
		_cam.look_at(Vector3.ZERO))

	# 2. An environment whose background is a flat COLOUR — no sky shader.
	await _time("environment, flat colour bg", func():
		_env = WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color("cfd8e3")
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.7, 0.75, 0.8)
		_env.environment = e
		add_child(_env))

	# 3. Swap that for a procedural SKY, which is its own shader.
	await _time("procedural sky", func():
		var sky := Sky.new()
		sky.sky_material = ProceduralSkyMaterial.new()
		_env.environment.sky = sky
		_env.environment.background_mode = Environment.BG_SKY
		_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY)

	# 4. Fog, tonemap and colour adjustment: each is a branch or a pass.
	await _time("fog", func(): _env.environment.fog_enabled = true)
	await _time("tonemap AGX", func():
		_env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX)
	await _time("colour adjustment", func():
		_env.environment.adjustment_enabled = true
		_env.environment.adjustment_contrast = 1.12
		_env.environment.adjustment_saturation = 1.3)
	await _time("glow", func(): _env.environment.glow_enabled = true)

	# 5. Now the lights, and only then any geometry.
	await _time("directional light, no shadow", func():
		var l := DirectionalLight3D.new()
		l.rotation_degrees = Vector3(-50, -30, 0)
		l.shadow_enabled = false
		add_child(l))
	await _time("one lit box", func(): _box(_plain()))
	await _time("second box, colour only", func():
		var m := _plain()
		m.albedo_color = Color(0.2, 0.4, 0.9)
		_box(m))
	await _time("unshaded", func():
		var m := _plain()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_box(m))
	await _time("emissive", func():
		var m := _plain()
		m.emission_enabled = true
		m.emission = Color(1, 0.8, 0.5)
		_box(m))
	await _time("omni light", func():
		var o := OmniLight3D.new()
		o.position = Vector3(0.5, 0.5, 0.5)
		o.shadow_enabled = false
		add_child(o))

	print("FLOOR total ", Time.get_ticks_msec() - t0, "ms")
	get_tree().quit()

func _plain() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.75, 0.7)
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.0
	return m

var _n := 0

func _box(m: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	mi.mesh = box
	mi.material_override = m
	mi.position = Vector3(_n * 0.7 - 1.0, 0, 0)
	_n += 1
	add_child(mi)

func _time(label: String, work: Callable) -> void:
	var t := Time.get_ticks_msec()
	work.call()
	for _f in 3:
		await get_tree().process_frame
	print("FLOOR ", label, " ", Time.get_ticks_msec() - t, "ms")
