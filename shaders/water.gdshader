shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.16, 0.58, 0.56, 0.6);
uniform vec4 deep_color : source_color = vec4(0.06, 0.34, 0.42, 0.82);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 0.96, 0.95);
uniform float wave_speed : hint_range(0.0, 3.0) = 0.8;
uniform float wave_scale : hint_range(0.0, 20.0) = 8.0;
uniform float wave_height : hint_range(0.0, 0.2) = 0.035;
uniform float foam_width : hint_range(0.0, 0.5) = 0.12;
uniform float fresnel_power : hint_range(0.5, 6.0) = 3.0;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.35;
uniform float sparkle_strength : hint_range(0.0, 2.0) = 0.8;

// Flow animation: still water (flow_amount = 0) keeps a gentle standing
// ripple. Flow segments (flow_amount > 0) travel along flow_dir and show a
// scrolling foam streak, so moving water visibly reads as "flowing".
uniform vec2 flow_dir = vec2(0.0, 0.0);
uniform float flow_speed : hint_range(0.0, 5.0) = 1.8;
uniform float flow_amount : hint_range(0.0, 1.0) = 0.0;

// Per-instance mask for the TOP face only: 1.0 = true pool boundary (show
// foam), 0.0 = touching another water cell on that side (internal seam,
// suppress foam so a connected pool reads as one surface, not a grid of
// tiles). Order: +X, -X, +Z, -Z. Set by BlockMergeManager from the same
// same-type-neighbor check that hides the geometry seams between blocks.
uniform vec4 edge_mask = vec4(1.0, 1.0, 1.0, 1.0);

varying float v_is_top;
varying vec3 v_world_pos;
varying float v_crest;

// Sum of directional sine waves for a livelier surface than a single ripple.
float layered_waves(vec2 p, float t) {
	float w = 0.0;
	w += sin(dot(p, vec2(1.0, 0.4)) * wave_scale + t * 4.0);
	w += 0.6 * sin(dot(p, vec2(-0.3, 1.0)) * wave_scale * 1.7 - t * 3.1);
	w += 0.35 * sin(dot(p, vec2(0.8, -0.7)) * wave_scale * 2.6 + t * 5.2);
	return w / 1.95;
}

void vertex() {
	v_is_top = step(0.49, VERTEX.y);
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_pos = world_pos;

	float disp;
	if (flow_amount > 0.0) {
		vec2 dir = normalize(flow_dir + vec2(0.0001));
		disp = sin((dot(world_pos.xz, dir) * wave_scale - TIME * wave_speed * 4.0));
	} else {
		disp = layered_waves(world_pos.xz, TIME * wave_speed);
	}
	v_crest = disp;
	// Only the top face rides the waves; side faces stay flat so stacked
	// water columns don't tear apart at their shared vertical seams.
	VERTEX.y += disp * wave_height * v_is_top;
}

void fragment() {
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, view_dir), 0.0, 1.0), fresnel_power);

	// Foam ring near the border of each face. On the top face, edges that
	// touch another water cell are masked out so a connected pool's surface
	// reads as one continuous sheet instead of a grid of foam-edged tiles.
	float edge_dist;
	if (v_is_top > 0.5) {
		float d_plus_x = mix(1.0, 1.0 - UV.x, edge_mask.x);
		float d_minus_x = mix(1.0, UV.x, edge_mask.y);
		float d_plus_z = mix(1.0, 1.0 - UV.y, edge_mask.z);
		float d_minus_z = mix(1.0, UV.y, edge_mask.w);
		edge_dist = min(min(d_plus_x, d_minus_x), min(d_plus_z, d_minus_z));
	} else {
		float edge_u = min(UV.x, 1.0 - UV.x);
		float edge_v = min(UV.y, 1.0 - UV.y);
		edge_dist = min(edge_u, edge_v);
	}
	float foam = 1.0 - smoothstep(0.0, foam_width, edge_dist);

	// Depth tint: viewed head-on the eye looks deep into the water (darker
	// jade), grazing angles skim the bright surface — a fake-depth gradient
	// since gl_compatibility can't read the real depth buffer.
	vec3 base = mix(deep_color.rgb, water_color.rgb, fresnel * 0.7 + 0.3);
	float base_a = mix(deep_color.a, water_color.a, fresnel * 0.7 + 0.3);

	// Caustic shimmer: interfering bands that crawl across the surface, only
	// on the top face where you'd actually see light dancing through water.
	float caustic = 0.0;
	if (v_is_top > 0.5) {
		vec2 cp = v_world_pos.xz * 3.0;
		float c = sin(cp.x + TIME * 1.3) * sin(cp.y - TIME * 1.1);
		c += 0.5 * sin(cp.x * 1.8 - TIME * 0.7) * sin(cp.y * 1.6 + TIME * 0.9);
		caustic = smoothstep(0.4, 1.0, c) * caustic_strength;
	}

	vec3 albedo = mix(base, foam_color.rgb, max(foam, fresnel * 0.4));
	albedo += vec3(0.9, 1.0, 0.98) * caustic * 0.4;
	float alpha = clamp(mix(base_a, foam_color.a, foam) + fresnel * 0.15, 0.0, 1.0);

	// Sharp glint on wave crests -> tiny sparkles the bloom will bloom out.
	float sparkle = smoothstep(0.85, 1.0, v_crest) * sparkle_strength * v_is_top;
	float emission_amount = foam * 0.2 + caustic * 0.3 + sparkle * 0.5;

	if (flow_amount > 0.0) {
		vec2 dir = normalize(flow_dir + vec2(0.0001));
		float scroll = dot(UV, dir) * 5.0 - TIME * flow_speed;
		float streak = smoothstep(0.65, 1.0, fract(scroll)) * flow_amount;
		albedo = mix(albedo, foam_color.rgb, streak * 0.6);
		emission_amount += streak * 0.3;
	}

	ALBEDO = albedo;
	ALPHA = alpha;
	ROUGHNESS = mix(0.02, 0.5, foam);
	METALLIC = 0.2;
	SPECULAR = 0.6;
	EMISSION = foam_color.rgb * emission_amount;
}
