extends Node

## Dev-only: how many distinct SHADER VARIANTS does the scene ask the driver to
## compile? On gl_compatibility every unique StandardMaterial3D feature set is a
## separate program, and the compat renderer compiles them synchronously the
## first time something using one is drawn. That is what a first-frame stall IS.
##
## Albedo COLOUR is not a variant — a hundred colours share one program. Feature
## FLAGS are. So counting materials tells you nothing; this counts flag sets.
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 tools/shadercount.tscn -- scene=...

var owners: Dictionary = {}

func _ready() -> void:
	var target := "res://scenes/main.tscn"
	var houses := 24  # count of sample blocks, not houses
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			target = a.substr(6)
		elif a.begins_with("houses="):
			houses = int(a.substr(7))
		elif a.begins_with("theme="):
			MapThemes.current = int(a.substr(6))
			MapThemes.save_current()
		elif a.begins_with("lite="):
			QualityManager.lite = a.substr(5) != "0"

	var s: Node = load(target).instantiate()
	add_child(s)
	for _f in range(45):
		await get_tree().process_frame
	if houses > 0:
		GridManager.clear_all()
		await get_tree().process_frame
		_village(s, houses)
	for _f in range(60):
		await get_tree().process_frame

	var variants: Dictionary = {}
	var custom: Dictionary = {}
	owners = {}
	var mats := 0
	_walk(get_tree().root, variants, custom)
	for k in variants:
		mats += int(variants[k])
	print("SHADERS distinct_standard_variants=%d  custom_shaders=%d  material_instances=%d"
			% [variants.size(), custom.size(), mats])
	for k in variants:
		print("   x%-4d %s" % [variants[k], k])
		var who: Array = owners.get(k, [])
		print("        owners: %s" % [", ".join(who)])
	for k in custom:
		print("   custom x%-3d %s" % [custom[k], k])
	get_tree().quit()

## Only the properties that make gl_compatibility emit a DIFFERENT program.
func _key(m: StandardMaterial3D) -> String:
	return "shade=%d trans=%d cull=%d blend=%d vcol=%s uv1tri=%s emis=%s rim=%s spec=%d dif=%d billb=%d nomap=%s" % [
		m.shading_mode, m.transparency, m.cull_mode, m.blend_mode,
		str(m.vertex_color_use_as_albedo), str(m.uv1_triplanar),
		str(m.emission_enabled), str(m.rim_enabled),
		m.specular_mode, m.diffuse_mode, m.billboard_mode,
		str(m.normal_enabled)]

func _walk(n: Node, variants: Dictionary, custom: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(i)
				_note(m, variants, custom)
				if m is StandardMaterial3D:
					var k := _key(m)
					var lst: Array = owners.get(k, [])
					var label := "%s/%s" % [n.get_parent().name if n.get_parent() else "?", n.name]
					if lst.size() < 6 and not lst.has(label):
						lst.append(label)
					owners[k] = lst
	elif n is GPUParticles3D:
		var p := n as GPUParticles3D
		_note(p.draw_pass_1.surface_get_material(0) if p.draw_pass_1 else null, variants, custom)
		if p.process_material != null:
			custom["particles:" + p.process_material.get_class()] = \
					int(custom.get("particles:" + p.process_material.get_class(), 0)) + 1
	for c in n.get_children():
		_walk(c, variants, custom)

func _note(m: Material, variants: Dictionary, custom: Dictionary) -> void:
	if m == null:
		return
	if m is StandardMaterial3D:
		var k := _key(m)
		variants[k] = int(variants.get(k, 0)) + 1
	elif m is ShaderMaterial:
		var sh: Shader = (m as ShaderMaterial).shader
		var k: String = sh.resource_path if sh != null else "shader:null"
		custom[k] = int(custom.get(k, 0)) + 1
	else:
		custom[m.get_class()] = int(custom.get(m.get_class(), 0)) + 1

func _village(root: Node, houses: int) -> void:
	var kit: Array = [BlockData.Type.BELL, BlockData.Type.CHIME, BlockData.Type.DRUM,
			BlockData.Type.PINWHEEL, BlockData.Type.STONE_LANTERN, BlockData.Type.JELLY]
	for i in houses:
		_place(root, Vector3i(-6 + (i % 8), i / 24, -4 + ((i / 8) % 3)), kit[i % kit.size()])
	for z in 3:
		for x in 3:
			_place(root, Vector3i(2 + x, 0, 1 + z), BlockData.Type.WATER)
	for t in [BlockData.Type.SOURCE, BlockData.Type.BELL, BlockData.Type.GEAR,
			BlockData.Type.DRUM, BlockData.Type.CHIME, BlockData.Type.SHISHI,
			BlockData.Type.MUSIC_BOX, BlockData.Type.SCOOP, BlockData.Type.PIPE,
			BlockData.Type.STONE_LANTERN, BlockData.Type.PINWHEEL, BlockData.Type.GATE,
			BlockData.Type.JELLY, BlockData.Type.WOOD]:
		_place(root, Vector3i(-8 + int(t), 0, 6), t)

func _place(root: Node, c: Vector3i, t: int) -> void:
	var n: Node3D = BlockFactory.instantiate(t)
	root.add_child(n)
	n.position = GridManager.cell_to_world(c)
	if "grid_cell" in n:
		n.grid_cell = c
	GridManager.set_block(c, BlockData.new(t, n))
	if n.has_method("refresh_shape"):
		n.refresh_shape()
