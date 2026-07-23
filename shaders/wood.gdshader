shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural warm wood: grain rings driven by world position (so stacked
// blocks read as one continuous timber, matching the merge aesthetic), plus
// a soft rim-light that lightens silhouette edges for the rounded, "toy
// diorama" pop — a cheap stand-in for real bevels/AO that gl_compatibility
// can't do with SSAO.

uniform vec3 base_color : source_color = vec3(0.76, 0.62, 0.4);
uniform vec3 grain_color : source_color = vec3(0.52, 0.38, 0.22);
uniform float grain_scale : hint_range(1.0, 20.0) = 6.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec3 rim_color : source_color = vec3(1.0, 0.92, 0.78);
uniform float rim_power : hint_range(0.5, 8.0) = 3.5;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.35;

varying vec3 v_world_pos;

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
}

void fragment() {
	// Grain: concentric-ish rings warped by noise, sampled in world space.
	vec2 gp = v_world_pos.xz * grain_scale;
	float rings = sin((v_world_pos.y * grain_scale * 0.5 + value_noise(gp) * 3.0) * 3.14159);
	float grain = value_noise(gp * 2.0) * 0.5 + rings * 0.5;
	grain = clamp(grain, 0.0, 1.0);

	vec3 albedo = mix(base_color, grain_color, grain * grain_strength);

	// Rim light: fresnel toward the silhouette, lightened for a soft edge.
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	albedo = mix(albedo, rim_color, fresnel * rim_strength);

	ALBEDO = albedo;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}
