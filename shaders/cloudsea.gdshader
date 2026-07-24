shader_type spatial;
render_mode blend_mix, cull_back, unshaded;

// The SEA OF CLOUDS below the floating island — one vertex-animated plane.
// Every off-edge waterfall plunges into it; the backdrop mountains rise out
// of it like a woodblock print. Theme-tinted via cloud_color.

uniform vec4 cloud_color : source_color = vec4(0.96, 0.85, 0.88, 1.0);

varying float v_n;
varying vec3 v_world_pos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = vnoise(wp.xz * 0.06 + TIME * 0.05)
		+ 0.5 * vnoise(wp.xz * 0.13 - TIME * 0.03);
	n /= 1.5;
	VERTEX.y += n * 0.8;
	v_n = n;
	v_world_pos = wp;
}

void fragment() {
	// Strong swell shading so the sea reads as ROLLING CLOUDS, not a flat tint
	// lost against the sky; edges dissolve into the fog.
	float rim = 0.80 + 0.32 * v_n;
	ALBEDO = cloud_color.rgb * rim + vec3(0.06) * smoothstep(0.75, 1.0, v_n);
	ALPHA = smoothstep(60.0, 40.0, length(v_world_pos.xz));
}
