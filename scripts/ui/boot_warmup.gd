extends Control

## The first thing the game does, and it exists ONLY for the browser.
##
## `gl_compatibility` compiles a shader program the first time something wearing
## it is drawn, synchronously, on the render thread. On desktop that is a few
## milliseconds. Through ANGLE it is a large fraction of a second EACH, because
## every program is retranslated to D3D11/Metal and reoptimised on the way.
##
## The menu draws the island, the sky, the scenery and the water all at once, so
## its very first frame owed the driver every program the game has. Measured on
## this project: that frame took ~41 seconds. Not slow — FROZEN. No spinner, no
## progress, no title; a blank tab for most of a minute, which anyone sensible
## reads as "this is broken" and closes.
##
## The compile cannot be avoided — the compat renderer has no async path — but it
## can be SPENT SOMEWHERE VISIBLE. This scene draws one thing per frame, so the
## driver compiles one program per frame, and between each the browser gets its
## main thread back: the bar moves, the tab breathes, and the player watches a
## garden being got ready instead of watching nothing.
##
## Halving the number of programs (`ShaderBudget`) makes this shorter. This makes
## it bearable. Both were needed.

const MENU := "res://scenes/main_menu.tscn"

## Two frames per item: one for the draw that triggers the compile, one to let
## the compiled frame present so the bar visibly moves. At one frame the browser
## coalesces the lot back into a single long paint, which is the exact thing
## this is here to stop.
const FRAMES_PER_ITEM := 2

const PAPER := Color("f4efe2")
const INK := Color("6b5a45")
const FILL := Color("7fb7a6")

var _fill: ColorRect
var _status: Label
var _stage: Node3D
var _done := false

## Boot timings are PRINTED, not measured from outside. Godot forwards print()
## to the browser console, so `tools/probe.mjs` can read exactly when the first
## picture appeared and when warming finished — from inside the engine, with the
## engine's own clock. Guessing at it from canvas pixels is how the earlier
## "roughly 40 seconds" estimate happened.
var _t0 := 0

func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	_build_ui()
	# 2D alone for two frames: the canvas shader is cheap, and getting a picture
	# up BEFORE anything 3D is drawn is the whole point.
	await get_tree().process_frame
	await get_tree().process_frame
	print("BOOT first-paint ", Time.get_ticks_msec(), "ms")

	# Warm in the MAIN viewport, not a SubViewport. A compiled program is keyed to
	# the render target it was compiled for, so warming somewhere with a different
	# size, format or MSAA setting risks paying for every program twice — once
	# here and again the moment the real scene draws. The items sit behind the
	# opaque background panel, which Control draws over 3D anyway.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	# Shadows OFF, and not as an optimisation: the web profile runs without them,
	# so a shadow-casting light here would compile the depth-pass variant of every
	# material — a whole second set of programs the game then never uses.
	light.shadow_enabled = false
	_stage = Node3D.new()
	add_child(_stage)
	_stage.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.4, 2.4)
	_stage.add_child(cam)
	cam.look_at(Vector3.ZERO)

	var jobs: Array = _jobs()
	for i in jobs.size():
		if _done:
			return
		_status.text = jobs[i]["say"]
		_set_ratio(float(i) / float(jobs.size()))
		var node: Node3D = (jobs[i]["make"] as Callable).call()
		if node == null:
			await get_tree().process_frame
			continue
		var _it := Time.get_ticks_msec()
		_stage.add_child(node)
		for _f in FRAMES_PER_ITEM:
			await get_tree().process_frame
			if not is_inside_tree():
				return
		print("BOOT item ", i, " ", jobs[i]["say"], " ", Time.get_ticks_msec() - _it, "ms")
		node.queue_free()
	print("BOOT warmed ", Time.get_ticks_msec(), "ms (", Time.get_ticks_msec() - _t0, "ms warming)")
	_set_ratio(1.0)
	_status.text = "Ready"
	await get_tree().create_timer(0.3).timeout
	_leave()

## One entry per SHADER PROGRAM the game will need — NOT one per thing on screen.
## Adding a block type does not belong here unless it introduces a material
## feature nothing else uses. `ShaderBudget` exists to keep this list short, and
## a longer boot is precisely the price of letting it grow.
func _jobs() -> Array:
	return [
		{"say": "Waking the island", "make": func(): return _lit(false, false)},
		{"say": "Mixing the paint", "make": func(): return _lit(true, false)},
		{"say": "Lighting the lanterns", "make": func(): return _lit(false, true)},
		{"say": "Filling the pond", "make": func(): return _shader_box(load("res://shaders/water.gdshader"))},
		{"say": "Laying the deck", "make": func(): return _shader_box(load("res://shaders/wood.gdshader"))},
		{"say": "Starting the stream", "make": func(): return _shader_box(load("res://shaders/stream.gdshader"))},
		{"say": "Hanging the clouds", "make": func(): return _shader_box(load("res://shaders/cloudsea.gdshader"))},
		{"say": "Catching the light", "make": func(): return _blended(BaseMaterial3D.BLEND_MODE_ADD)},
		{"say": "Clearing the glass", "make": func(): return _blended(BaseMaterial3D.BLEND_MODE_MIX)},
		{"say": "Letting the leaves go", "make": func(): return _leaf_particles()},
	]

# ------------------------------------------------------------------ warm items
func _box(m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mi.mesh = box
	mi.material_override = m
	return mi

## The three lit variants — plain, vertex-coloured, emissive — which between them
## clothe nearly every solid thing in the game.
func _lit(vertex_colour: bool, emissive: bool) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.75, 0.7)
	m.vertex_color_use_as_albedo = vertex_colour
	if emissive:
		m.emission_enabled = true
		m.emission = Color(1, 0.85, 0.6)
	ShaderBudget.normalise(m)
	return _box(m)

func _blended(mode: int) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = mode
	m.albedo_color = Color(0.6, 0.85, 1.0, 0.4)
	ShaderBudget.normalise(m)
	return _box(m)

func _shader_box(sh: Shader) -> MeshInstance3D:
	if sh == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = sh
	return _box(m)

## Particle quads are their own program — billboarding is a feature flag — and
## the process material is a second shader again.
func _leaf_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 4
	p.lifetime = 1.0
	p.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.6
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.albedo_color = Color(0.8, 0.9, 0.7)
	quad.material = qm
	p.draw_pass_1 = quad
	return p

# ------------------------------------------------------------------------- UI
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# A CenterContainer, not a measured offset: centring by hand needs the box's
	# laid-out size, which means awaiting a frame, and that coroutine then resumes
	# on a node this scene has already freed on its way to the menu.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(col)

	var title := Label.new()
	title.text = "Karakuri Stream"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var track := ColorRect.new()
	track.color = Color(INK.r, INK.g, INK.b, 0.14)
	track.custom_minimum_size = Vector2(280, 10)
	col.add_child(track)
	_fill = ColorRect.new()
	_fill.color = FILL
	_fill.size = Vector2(0, 10)
	track.add_child(_fill)

	_status = Label.new()
	_status.text = "Warming up"
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.75))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	var hint := Label.new()
	hint.text = "first visit only — click to skip"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

func _set_ratio(r: float) -> void:
	if _fill != null:
		_fill.size = Vector2(280.0 * clampf(r, 0.0, 1.0), 10)

## Skipping is allowed and deliberate: this only ever runs as the very first
## scene, so there is nothing behind it to break, and someone who has already
## waited once should not be made to wait again.
func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_leave()

func _leave() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file(MENU)
