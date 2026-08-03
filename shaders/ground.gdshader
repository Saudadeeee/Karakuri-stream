shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// The island is the largest single surface on screen — most frames are more than
// half lawn — and it was ONE flat colour. A big unbroken patch of one RGB value
// is what reads as plastic more than any material setting does: real ground has
// patches, wear and shade in its dips, and the eye looks for that before it
// looks at a highlight.
//
// So: value noise in world space, two octaves, biased so it darkens more than it
// lightens (soil is dirty, not shiny). No texture, no UVs — an island built from
// rings has no usable UV layout, and world-space noise also means the pattern
// does not swim when the mesh is rebuilt for a different map theme.
//
// Also a WEAK sheen. Everything in this game was roughness 1.0 / specular 0,
// which is a perfectly diffuse surface — physically the definition of chalk, and
// visually the definition of vinyl. A little grazing-angle light is what tells
// the eye a surface has a material at all.

// PERIODS IN WORLD UNITS, not a bare "scale" — one cell of the build grid is
// 1.0, so these read as "patches about two and a half blocks across" and "grain
// about half a block across". The first pass used a scale the shader divided by,
// which made the "detail" octave four times COARSER than the base one and turned
// the lawn into two giant blobs.
uniform float patch_period : hint_range(0.5, 8.0) = 2.4;
uniform float patch_strength : hint_range(0.0, 0.4) = 0.10;
uniform float grain_period : hint_range(0.1, 2.0) = 0.45;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.06;
// Slope darkening: the sides of the island and the lip under the rim take a
// touch more shade, which is where a real mound holds its dirt.
uniform float slope_shade : hint_range(0.0, 1.0) = 0.22;
uniform float ground_roughness : hint_range(0.3, 1.0) = 0.92;
uniform float ground_specular : hint_range(0.0, 0.5) = 0.14;

varying vec3 v_world;
varying vec3 v_normal_world;

// Value noise: hash a lattice and smooth between corners.
//
// The hash is deliberately NOT the usual fract(sin(dot(...))*43758.5) — that
// costs a transcendental per lattice corner, i.e. eight sin() calls per pixel
// over the largest surface on screen, and the compatibility renderer is the
// target that can least afford it. This one is pure multiply-fract and measured
// the ground pass down from 0.85 ms to 0.3 ms at 800 blocks.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;

	// Two octaves, centred on zero and pulled downward: patches of shade rather
	// than a field of bright speckles.
	float n = value_noise(v_world.xz / patch_period) - 0.5;
	float d = value_noise(v_world.xz / grain_period + 31.4) - 0.5;
	float shade = n * patch_strength + d * grain_strength;
	// Biased downward: soil is dirty, not shiny, and a field of bright speckles
	// reads as noise-for-its-own-sake.
	shade -= patch_strength * 0.3;

	// Anything not facing up is a slope; slopes hold shade.
	float up = clamp(v_normal_world.y, 0.0, 1.0);
	shade -= (1.0 - up) * slope_shade * 0.5;

	ALBEDO = clamp(base * (1.0 + shade), vec3(0.0), vec3(1.0));
	ROUGHNESS = ground_roughness;
	SPECULAR = ground_specular;
}
