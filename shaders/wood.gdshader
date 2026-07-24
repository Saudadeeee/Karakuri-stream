shader_type spatial;
// cull_disabled: opaque wood is double-sided so no face can ever be culled —
// even a stray inward-wound triangle can't open a see-through hole. Belt-and-
// braces on top of the watertight isosurface.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Procedural warm wood: grain rings driven by world position (so stacked
// blocks read as one continuous timber, matching the merge aesthetic), plus
// a soft rim-light that lightens silhouette edges for the rounded, "toy
// diorama" pop — a cheap stand-in for real bevels/AO that gl_compatibility
// can't do with SSAO.

// Palette = artstyle.md Wood #D4A373 (warm sand timber) with a darker grain.
uniform vec3 base_color : source_color = vec3(0.831, 0.639, 0.451);
uniform vec3 grain_color : source_color = vec3(0.62, 0.44, 0.28);
uniform float grain_scale : hint_range(1.0, 20.0) = 4.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.15;
uniform vec3 rim_color : source_color = vec3(0.95, 0.85, 0.68);
uniform float rim_power : hint_range(0.5, 8.0) = 4.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.26;

uniform float top_shade : hint_range(0.0, 1.0) = 0.4;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// SOFT low-contrast blotches only — NO sine "ring" banding. The old
	// world-Y sine rings drew hard dark zig-zag bands across the faces that
	// read as carved grooves / hollow folds, making a solid block look
	// see-through. artstyle.md wants flat matte clay, so keep the grain barely
	// there: a gentle 3D-noise tint, nothing structured.
	vec3 gp = v_world_pos * grain_scale * 0.5;
	float n = value_noise(gp.xz + gp.y) * 0.6 + value_noise(gp.zy * 1.9) * 0.4;
	float grain = smoothstep(0.35, 0.75, n);

	vec3 albedo = mix(base_color, grain_color, grain * grain_strength);

	// Baked directional shade from a fixed "sun" — differentiates EVERY face by
	// orientation (top bright, sun-side bright, shadow-side dark, underside
	// darkest). This is the cue that makes a smooth matte block read as a SOLID
	// convex shape from any camera angle instead of a hollow/see-through one
	// (a flat-lit rounded blob is otherwise convex/concave ambiguous — the
	// hollow-face illusion the user kept seeing). Baked so it never depends on
	// scene lighting lining up.
	const vec3 SUN = normalize(vec3(0.35, 0.82, 0.45));
	float lambert = dot(v_world_normal, SUN) * 0.5 + 0.5;
	albedo *= mix(1.0 - top_shade, 1.0 + top_shade * 0.35, lambert);

	// Rim light: fresnel toward the silhouette, lightened for a soft edge.
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	albedo = mix(albedo, rim_color, fresnel * rim_strength);

	// Baked vertex AO from the isosurface builder (crevices darken).
	ALBEDO = albedo * mix(0.55, 1.0, COLOR.r);
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}
