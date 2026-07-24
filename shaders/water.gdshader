shader_type spatial;
// OPAQUE + cull_disabled: the jelly water is a solid mass, never see-through.
// Opaque means it's in the opaque pass (writes depth, sorts correctly) and
// cull_disabled means no isosurface winding hole can ever open an X-ray gap —
// exactly the fix used for wood. The water look comes from colour + waves +
// foam, not from transparency.
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

// Water surface shader for the merged metaball isosurface (one continuous
// body, no per-cell tiles). Everything is world-space — there are no reliable
// UVs or per-face edges on an isosurface, so foam/waves/caustics/sparkle all
// key off world position + surface normal. edge_mask / v_is_top from the old
// per-block version are gone (the surface has no internal seams by construction).

// Mostly opaque so a merged body reads as a solid mass of water (no X-ray onto
// the far side), with only a faint hint of translucency at grazing angles.
// depth_draw_always still makes the near wall occlude the far wall of a ring.
// Palette = artstyle.md Jelly Water #48CAE4 (bright cyan) + warm foam. Kept
// FRESH: the deep tint barely darkens so a still pond reads the same lively cyan
// as the routed stream (StreamManager uses the same colour). Mostly opaque (no
// X-ray); depth_draw_always occludes the far wall of a ring pool.
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
// warm horizon colour (matches the ProceduralSky), reading as a reflective
// sheen without any actual reflection probe — the cheap Townscaper trick.
uniform vec4 sky_tint : source_color = vec4(0.95, 0.84, 0.84, 1.0);
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.30;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying float v_crest;

float layered_waves(vec2 p, float t) {
	float w = 0.0;
	w += sin(dot(p, vec2(1.0, 0.4)) * wave_scale + t * 4.0);
	w += 0.6 * sin(dot(p, vec2(-0.3, 1.0)) * wave_scale * 1.7 - t * 3.1);
	w += 0.35 * sin(dot(p, vec2(0.8, -0.7)) * wave_scale * 2.6 + t * 5.2);
	return w / 1.95;
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float disp = layered_waves(world_pos.xz, TIME * wave_speed);
	v_crest = disp;
	// Ripple only the upward-facing part of the blob so the sides don't wobble.
	float up = clamp(world_normal.y, 0.0, 1.0);
	VERTEX += NORMAL * disp * wave_height * up;
	v_world_pos = world_pos;
	v_world_normal = world_normal;
}

void fragment() {
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, view_dir), 0.0, 1.0), fresnel_power);

	// Depth-ish tint, but biased toward the bright surface colour so the body
	// stays a fresh lively cyan (matching the stream) instead of going dark jade.
	vec3 base = mix(deep_color.rgb, water_color.rgb, fresnel * 0.4 + 0.6);
	float base_a = mix(deep_color.a, water_color.a, fresnel * 0.4 + 0.6);

	// Foam gathers a little along the silhouette rim and on the upper crests —
	// frothy edges where water meets air, but kept subtle so the body stays
	// teal rather than washing out to white on thin cascade geometry.
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
	// mirrors the pink horizon like glass while the body stays cyan.
	albedo = mix(albedo, sky_tint.rgb, fresnel * sky_reflect * (0.35 + 0.65 * up));
	// Baked fixed-sun shade so a water block reads as a solid convex jelly from
	// any angle, not a hollow shell (same fix as wood — kills the concave/
	// see-through illusion).
	const vec3 WSUN = normalize(vec3(0.35, 0.82, 0.45));
	float wl = dot(v_world_normal, WSUN) * 0.5 + 0.5;
	albedo *= mix(0.66, 1.12, wl);
	float alpha = clamp(mix(base_a, foam_color.a, foam) + fresnel * 0.12, 0.0, 1.0);

	float sparkle = smoothstep(0.85, 1.0, v_crest) * sparkle_strength * up;

	ALBEDO = albedo;
	ALPHA = alpha;
	// Glassier when calm → tighter, brighter sun glint dancing on the waves.
	ROUGHNESS = mix(0.02, 0.5, foam);
	METALLIC = 0.12;
	SPECULAR = 0.65;
	// A faint self-glow of the water colour keeps the pond as lively/fresh as the
	// emissive stream cylinders, plus the foam/caustic/sparkle highlights.
	EMISSION = water_color.rgb * 0.08 + foam_color.rgb * (foam * 0.15 + caustic * 0.3 + sparkle * 0.5);
}
