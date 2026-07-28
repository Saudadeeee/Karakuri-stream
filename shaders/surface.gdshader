shader_type spatial;
// cull_disabled: both surfaces are solid masses drawn from a marching-cubes
// isosurface, so no face may ever be culled — a stray inward-wound triangle
// would otherwise open a see-through hole. Belt-and-braces on top of the
// watertight builder.
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

// ONE program for all three of the game's water-and-timber looks.
//
// These were two shaders. On gl_compatibility every shader is a program the
// driver compiles the first time something wearing it is drawn, and through
// ANGLE that is *seconds*: measured cold in Chrome on an RTX 3060, wood cost
// 7.8 s and water 7.8 s, each on its own. A `surface_mode` uniform is free —
// uniforms do not multiply programs, and the branch is dynamically uniform so
// the GPU takes one side for the whole draw. Merging them buys back one of
// those compiles outright and costs nothing at run time.
//
// Three shaders became one: 7.8 s + 7.8 s + 7.4 s of cold compile, down to a
// single program.
//
// The two only ever differed in `diffuse_burley` (wood) versus `diffuse_lambert`
// (water), which is a render_mode and therefore compile-time — it is the one
// thing a uniform cannot switch. Lambert for both: on a matte surface at
// roughness 0.85 the difference is not visible, and it was checked by rendering
// the deck side by side before and after.

// 0 = timber, 1 = still water, 2 = the falling stream.
uniform int surface_mode : hint_range(0, 2) = 0;

// -- stream ---------------------------------------------------------------
// The routed stream cylinders. `beat_pulse` is fed each frame from
// StreamManager's shared clock so every stream breathes on the downbeat.
//
// This used to be its own shader, kept apart because it was `blend_mix` while
// the other two are opaque — and blending is a render_mode, which no uniform can
// switch. But its alpha was 0.98: the game's water has been deliberately opaque
// since the isosurface rewrite ("a solid mass, never see-through"), and the
// stream was only nominally transparent. Making it honestly opaque let it join,
// and bought back another whole compile.
uniform float beat_pulse : hint_range(0.0, 1.0) = 0.0;

// -- timber ---------------------------------------------------------------
// Palette = artstyle.md Wood #D4A373 (warm sand timber) with a darker grain.
uniform vec3 base_color : source_color = vec3(0.831, 0.639, 0.451);
uniform vec3 grain_color : source_color = vec3(0.62, 0.44, 0.28);
uniform float grain_scale : hint_range(1.0, 20.0) = 4.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.15;
uniform vec3 rim_color : source_color = vec3(0.95, 0.85, 0.68);
uniform float rim_power : hint_range(0.5, 8.0) = 4.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.26;
uniform float top_shade : hint_range(0.0, 1.0) = 0.4;

// -- water ----------------------------------------------------------------
// Palette = artstyle.md Jelly Water #48CAE4. Kept FRESH: the deep tint barely
// darkens so a still pond reads the same lively cyan as the routed stream.
uniform vec4 water_color : source_color = vec4(0.282, 0.792, 0.894, 1.0);
uniform vec4 deep_color : source_color = vec4(0.18, 0.62, 0.76, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.91, 0.85, 0.98);
uniform float wave_speed : hint_range(0.0, 3.0) = 0.9;
uniform float wave_scale : hint_range(0.0, 20.0) = 5.0;
uniform float wave_height : hint_range(0.0, 0.12) = 0.025;
uniform float fresnel_power : hint_range(0.5, 6.0) = 3.2;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.08;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.18;
uniform float sparkle_strength : hint_range(0.0, 2.0) = 0.35;
// Fake sky reflection: at grazing angles the surface mixes toward the sky's
// warm horizon colour, reading as a sheen without any reflection probe.
uniform vec4 sky_tint : source_color = vec4(0.95, 0.84, 0.84, 1.0);
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.30;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying float v_crest;
varying float v_flow;

// The same fixed "sun" both looks bake their shading against, so a smooth matte
// blob reads as a SOLID convex shape from any camera angle rather than a hollow
// one. Baked, so it never depends on the scene lighting lining up.
const vec3 FIXED_SUN = vec3(0.5416, 1.2691, 0.6964);

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

float layered_waves(vec2 p, float t) {
	float w = 0.0;
	w += sin(dot(p, vec2(1.0, 0.4)) * wave_scale + t * 4.0);
	w += 0.6 * sin(dot(p, vec2(-0.3, 1.0)) * wave_scale * 1.7 - t * 3.1);
	w += 0.35 * sin(dot(p, vec2(0.8, -0.7)) * wave_scale * 2.6 + t * 5.2);
	return w / 1.95;
}

void vertex() {
	v_flow = 0.0;
	if (surface_mode == 2) {
		// Wobble pinned to zero at both ends (a sin(PI*v) envelope) so stacked
		// segments never crack at their joints. CylinderMesh's V runs along local
		// Y, which StreamManager aligns a→b, so UV.y already runs downstream.
		float envelope = sin(PI * UV.y);
		float wob = sin(UV.y * 18.0 - TIME * 9.0) * 0.04 * envelope;
		VERTEX.xz *= 1.0 + wob;
		v_flow = UV.y;
	}
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_crest = 0.0;
	if (surface_mode == 1) {
		float disp = layered_waves(world_pos.xz, TIME * wave_speed);
		v_crest = disp;
		// Ripple only the upward-facing part of the blob so the sides do not
		// wobble.
		float up = clamp(world_normal.y, 0.0, 1.0);
		VERTEX += NORMAL * disp * wave_height * up;
	}
	v_world_pos = world_pos;
	v_world_normal = world_normal;
}

void fragment() {
	vec3 sun = normalize(FIXED_SUN);
	if (surface_mode == 2) {
		// Two scrolling foam-streak layers at different speeds — the read of
		// water sliding down the column.
		float s1 = step(0.75, fract(v_flow * 3.0 - TIME * 2.8));
		float s2 = step(0.8, fract(v_flow * 5.0 - TIME * 4.1));
		float streaks = s1 * 0.08 + s2 * 0.06;
		float fres = pow(1.0 - clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0), 3.0);
		vec3 col = water_color.rgb * (1.0 + streaks);
		col = mix(col, foam_color.rgb, fres * 0.35 + streaks * 0.5);
		ALBEDO = col;
		ALPHA = 1.0;
		ROUGHNESS = 0.15;
		METALLIC = 0.0;
		SPECULAR = 0.6;
		// The downbeat breath: emission swells as the shared clock hits the beat.
		EMISSION = water_color.rgb * (0.10 + 0.12 * pow(beat_pulse, 3.0));
	} else if (surface_mode == 1) {
		vec3 view_dir = normalize(VIEW);
		float fresnel = pow(1.0 - clamp(dot(NORMAL, view_dir), 0.0, 1.0), fresnel_power);

		// Depth-ish tint, biased toward the bright surface colour so the body
		// stays a fresh lively cyan instead of going dark jade.
		vec3 base = mix(deep_color.rgb, water_color.rgb, fresnel * 0.4 + 0.6);
		float base_a = mix(deep_color.a, water_color.a, fresnel * 0.4 + 0.6);

		// Foam gathers along the silhouette rim and on the upper crests, kept
		// subtle so the body stays teal rather than washing out to white.
		float up = clamp(v_world_normal.y, 0.0, 1.0);
		float foam = clamp(fresnel * 0.6 + smoothstep(0.7, 1.0, v_crest) * up, 0.0, 1.0) * foam_amount;

		// Caustic shimmer crawling across the top.
		vec2 cp = v_world_pos.xz * 3.0;
		float c = sin(cp.x + TIME * 1.3) * sin(cp.y - TIME * 1.1);
		c += 0.5 * sin(cp.x * 1.8 - TIME * 0.7) * sin(cp.y * 1.6 + TIME * 0.9);
		float caustic = smoothstep(0.4, 1.0, c) * caustic_strength * up;

		vec3 albedo = mix(base, foam_color.rgb, foam);
		albedo += vec3(0.9, 1.0, 0.98) * caustic * 0.4;
		// Sky sheen at grazing angles — strongest on the flat top, so a pond
		// mirrors the horizon like glass while the body stays cyan.
		albedo = mix(albedo, sky_tint.rgb, fresnel * sky_reflect * (0.35 + 0.65 * up));
		float wl = dot(v_world_normal, sun) * 0.5 + 0.5;
		albedo *= mix(0.66, 1.12, wl);

		float sparkle = smoothstep(0.85, 1.0, v_crest) * sparkle_strength * up;

		ALBEDO = albedo;
		ALPHA = clamp(mix(base_a, foam_color.a, foam) + fresnel * 0.12, 0.0, 1.0);
		// Glassier when calm → tighter, brighter sun glint dancing on the waves.
		ROUGHNESS = mix(0.02, 0.5, foam);
		METALLIC = 0.12;
		SPECULAR = 0.65;
		// A faint self-glow keeps the pond as lively as the routed stream.
		EMISSION = water_color.rgb * 0.08
			+ foam_color.rgb * (foam * 0.15 + caustic * 0.3 + sparkle * 0.5);
	} else {
		// SOFT low-contrast blotches only — NO sine "ring" banding. World-Y sine
		// rings drew hard dark zig-zags that read as carved grooves and made a
		// solid block look see-through. Keep the grain barely there.
		vec3 gp = v_world_pos * grain_scale * 0.5;
		float n = value_noise(gp.xz + gp.y) * 0.6 + value_noise(gp.zy * 1.9) * 0.4;
		float grain = smoothstep(0.35, 0.75, n);
		vec3 albedo = mix(base_color, grain_color, grain * grain_strength);

		// Baked directional shade: top bright, sun-side bright, shadow-side dark,
		// underside darkest. This is the cue that stops a flat-lit rounded blob
		// reading as concave.
		float lambert = dot(v_world_normal, sun) * 0.5 + 0.5;
		albedo *= mix(1.0 - top_shade, 1.0 + top_shade * 0.35, lambert);

		// Rim light: fresnel toward the silhouette, for the soft toy-diorama edge
		// that gl_compatibility cannot get from real SSAO.
		float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
		albedo = mix(albedo, rim_color, fres * rim_strength);

		// Baked vertex AO from the isosurface builder (crevices darken).
		ALBEDO = albedo * mix(0.55, 1.0, COLOR.r);
		ALPHA = 1.0;
		ROUGHNESS = 0.85;
		METALLIC = 0.0;
		SPECULAR = 0.15;
		EMISSION = vec3(0.0);
	}
}
