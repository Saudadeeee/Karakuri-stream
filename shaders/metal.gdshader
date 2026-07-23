shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Warm toy-metal for gear/bell: bronze base, a bright rim sheen so the shape
// reads clearly against the pastel background, and a faint emissive glow that
// the Environment's bloom picks up for that soft "precious object" look.

uniform vec3 base_color : source_color = vec3(0.66, 0.45, 0.24);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.8;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec3 rim_color : source_color = vec3(1.0, 0.85, 0.55);
uniform float rim_power : hint_range(0.5, 8.0) = 2.5;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.6;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);

	ALBEDO = base_color;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	RIM = rim_strength;
	RIM_TINT = 0.5;
	EMISSION = rim_color * fresnel * glow_amount;
}
