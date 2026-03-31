shader_type canvas_item;

// Up to 8 world-space occluder positions (entities behind this sprite).
uniform vec2 occluder_0;
uniform vec2 occluder_1;
uniform vec2 occluder_2;
uniform vec2 occluder_3;
uniform vec2 occluder_4;
uniform vec2 occluder_5;
uniform vec2 occluder_6;
uniform vec2 occluder_7;
uniform int  occluder_count = 0;

uniform float fade_radius  = 20.0;   // world-pixel radius of the soft fade
uniform float fade_alpha   = 0.25;   // minimum alpha at the centre of the fade

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

	// smoothstep: at dist=0 → fade_alpha, at dist>=fade_radius → 1.0
	float alpha_mult = 1.0;
	if (occluder_count > 0) {
		alpha_mult = mix(fade_alpha, 1.0, smoothstep(0.0, fade_radius, min_dist));
	}

	// Only modify alpha — leave RGB untouched.
	// Do NOT multiply by COLOR; Godot applies modulate after the fragment shader.
	COLOR = vec4(tex.rgb, tex.a * alpha_mult);
}
