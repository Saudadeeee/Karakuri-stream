class_name ShaderBudget
extends RefCounted

## THE ONE THING THAT MATTERS FOR THE WEB BUILD.
##
## On `gl_compatibility` the renderer does not compile one program per material.
## It compiles a program per unique COMBINATION OF MATERIAL FEATURES, and it
## compiles it synchronously the first time something wearing that combination
## is drawn. Albedo colour is free — a hundred colours share one program. Flags
## are not: flip `cull_mode` on one prop and the whole scene owes the driver
## another program.
##
## On desktop GL that costs a few milliseconds and nobody notices. In a browser
## the GL calls go through ANGLE and out to D3D11/Metal, where each program is
## re-translated and re-optimised, and the bill is a large fraction of a second
## EACH. Measured on this project: the first frame took ~41 seconds, during which
## the tab is simply frozen — no spinner, no progress, nothing to tell the player
## the game has not crashed. That is the single worst thing about the web build,
## and it is not a triangle problem or a draw-call problem. It is this.
##
## So the rule on this branch: a small, fixed set of feature combinations, and
## anything arriving from outside (a .glb the exporter marked double-sided, a
## material copied from a tutorial) gets normalised into it on the way in.
##
## `tame()` is what does the normalising. It is idempotent and safe to call on
## anything; imported materials are shared between instances of a scene, so the
## first call generally fixes every copy at once.

## Back-face culling ON is the default everywhere. Blender and most glTF
## exporters mark materials double-sided out of habit, which both costs a
## variant and doubles the triangles the rasteriser has to consider for solid
## props that can never be seen from the inside — rocks, bushes, tree trunks.
##
## `keep_double_sided` is the escape hatch for geometry that genuinely IS a flat
## sheet seen from both faces (crossed grass planes, a flag, a lily pad). Pass
## true and this leaves cull_mode alone; you are then knowingly spending a
## program on it.
static func tame(node: Node, keep_double_sided: bool = false) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		normalise(mi.material_override as StandardMaterial3D, keep_double_sided)
		for i in mi.get_surface_override_material_count():
			normalise(mi.get_surface_override_material(i) as StandardMaterial3D, keep_double_sided)
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				normalise(mi.mesh.surface_get_material(i) as StandardMaterial3D, keep_double_sided)
	for c in node.get_children():
		tame(c, keep_double_sided)

## Flatten one material onto the branch's fixed feature set.
static func normalise(sm: StandardMaterial3D, keep_double_sided: bool = false) -> void:
	if sm == null:
		return
	if not keep_double_sided and sm.cull_mode == BaseMaterial3D.CULL_DISABLED:
		sm.cull_mode = BaseMaterial3D.CULL_BACK
	# Nothing in this game has a normal map, an SSS profile or a rim term, but an
	# imported material can arrive with the feature switched on and nothing bound
	# to it — which buys a whole program to compute exactly nothing.
	sm.normal_enabled = false
	sm.rim_enabled = false
	sm.refraction_enabled = false
	sm.subsurf_scatter_enabled = false
	sm.backlight_enabled = false
	sm.clearcoat_enabled = false
	sm.anisotropy_enabled = false
	sm.ao_enabled = false
	sm.heightmap_enabled = false
	sm.detail_enabled = false
	sm.grow = false
	sm.use_point_size = false
	sm.proximity_fade_enabled = false
	sm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
	# The art style is flat and matte, but get there by turning the specular
	# STRENGTH to zero, not by switching specular_mode off. The mode is a feature
	# flag, so setting it on imported props alone simply moved the split from
	# cull_mode to specular_mode and bought nothing — count came back at 9 either
	# way. Strength is a uniform: free, and it shares a program with everything
	# the game builds by hand.
	sm.metallic = 0.0
	sm.metallic_specular = 0.0
	sm.roughness = 1.0
