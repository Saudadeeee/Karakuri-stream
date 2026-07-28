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

## "This thing glows." Say it through here rather than by setting `emission`
## directly, because what glowing COSTS depends on the profile.
##
## On a build with bloom, emission is the right answer: the glow pass finds the
## bright pixels and blooms them. The web profile has no bloom — `QualityManager`
## disables it — so emission there does nothing but raise the surface's
## brightness, which is exactly what an unshaded material already does.
##
## And it is not a small saving. Measured cold in Chrome (ANGLE → D3D11, RTX
## 3060), the emissive program cost **8.6 seconds** to compile, against 0.67 s
## for unshaded — and unshaded is already paid for, because the transparent UI
## bits use it. It was the single largest thing on the first-visit bill that this
## game had any say over.
static func glow(m: StandardMaterial3D, colour: Color, energy: float = 1.0) -> void:
	if m == null:
		return
	if QualityManager.lite:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var lit: Color = Color(colour.r, colour.g, colour.b) * maxf(energy, 1.0)
		m.albedo_color = Color(minf(lit.r, 1.0), minf(lit.g, 1.0), minf(lit.b, 1.0), m.albedo_color.a)
		m.emission_enabled = false
		# Painting the whole surface one bright colour makes any per-vertex tint
		# underneath it invisible — and leaving the flag on would buy a separate
		# program for a difference nobody can see. The island's heart cog is the
		# one thing this applies to, and it is what made the Night map cost a
		# seventh variant.
		m.vertex_color_use_as_albedo = false
		return
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy

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
