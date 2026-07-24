shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;

// Falling-water stream shader for the routed stream cylinders. The water
// visibly FLOWS: the surface wobbles and two foam-streak layers scroll along
// the segment (CylinderMesh V runs along local Y, which StreamManager's
// _basis_towards aligns a→b, so UV.y already runs downstream). A beat_pulse
// uniform (fed each frame from StreamManager's shared clock) makes every
// stream glow softly on the downbeat — the machine breathes with its music.

uniform vec4 water_color : source_color = vec4(0.282, 0.792, 0.894, 0.98);
uniform vec4 foam_color : source_color = vec4(0.95, 0.93, 0.88, 1.0);
uniform float beat_pulse : hint_range(0.0, 1.0) = 0.0;

varying float v_flow;

void vertex() {
	// Wobble pinned to zero at both ends (sin(PI*v) envelope) so stacked
	// segments never crack at their joints. Radius is 0.09 — keep tiny.
	float envelope = sin(PI * UV.y);
	float wob = sin(UV.y * 18.0 - TIME * 9.0) * 0.04 * envelope;
	VERTEX.xz *= 1.0 + wob;
	v_flow = UV.y;
}

void fragment() {
	// Two scrolling foam-streak layers at different speeds — the read of
	// water sliding down the column.
	float s1 = step(0.75, fract(v_flow * 3.0 - TIME * 2.8));
	float s2 = step(0.8, fract(v_flow * 5.0 - TIME * 4.1));
	float streaks = s1 * 0.08 + s2 * 0.06;

	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, view_dir), 0.0, 1.0), 3.0);

	vec3 col = water_color.rgb * (1.0 + streaks);
	col = mix(col, foam_color.rgb, fresnel * 0.35 + streaks * 0.5);

	ALBEDO = col;
	ALPHA = water_color.a;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	// The downbeat breath: emission swells as the shared clock hits the beat.
	EMISSION = water_color.rgb * (0.10 + 0.12 * pow(beat_pulse, 3.0));
}
