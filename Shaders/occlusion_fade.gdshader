// =========================================================================
//  Occlusion Fade Shader  (canvas_item)
//
//  Makes foreground sprites semi-transparent when they overlap entities
//  behind them (e.g. trees in front of an NPC).
//
//  Up to 8 world-space occluder positions are passed in.  Each fragment
//  finds the nearest occluder and fades alpha via smoothstep:
//      distance = 0           →  fade_alpha  (nearly see-through)
//      distance ≥ fade_radius →  1.0         (fully opaque)
//
//  Godot applies the node's modulate colour AFTER the fragment shader,
//  so we intentionally skip multiplying by COLOR here.
// =========================================================================

shader_type canvas_item;

// ── Occluder positions (world-space) ────────────────────────────────
uniform vec2 occluder_0;
uniform vec2 occluder_1;
uniform vec2 occluder_2;
uniform vec2 occluder_3;
uniform vec2 occluder_4;
uniform vec2 occluder_5;
uniform vec2 occluder_6;
uniform vec2 occluder_7;
uniform int  occluder_count = 0;

// ── Fade parameters ─────────────────────────────────────────────────
uniform float fade_radius = 20.0;   // world-pixel radius of the soft fade
uniform float fade_alpha  = 0.25;   // minimum alpha at the centre of the fade

// Per-pixel world position, computed in vertex and interpolated to fragment.
varying vec2 world_pos;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Find the closest occluder distance.
	float min_dist = 99999.0;
	if (occluder_count > 0) min_dist = min(min_dist, distance(world_pos, occluder_0));
	if (occluder_count > 1) min_dist = min(min_dist, distance(world_pos, occluder_1));
	if (occluder_count > 2) min_dist = min(min_dist, distance(world_pos, occluder_2));
	if (occluder_count > 3) min_dist = min(min_dist, distance(world_pos, occluder_3));
	if (occluder_count > 4) min_dist = min(min_dist, distance(world_pos, occluder_4));
	if (occluder_count > 5) min_dist = min(min_dist, distance(world_pos, occluder_5));
	if (occluder_count > 6) min_dist = min(min_dist, distance(world_pos, occluder_6));
	if (occluder_count > 7) min_dist = min(min_dist, distance(world_pos, occluder_7));

	// Smooth fade: fully transparent at dist=0, fully opaque at dist≥fade_radius.
	float alpha_mult = 1.0;
	if (occluder_count > 0) {
		alpha_mult = mix(fade_alpha, 1.0, smoothstep(0.0, fade_radius, min_dist));
	}

	// Only modify alpha — leave RGB untouched.
	COLOR = vec4(tex.rgb, tex.a * alpha_mult);
}
