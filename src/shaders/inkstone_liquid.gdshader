shader_type canvas_item;
render_mode unshaded;

// Warp the approved reservoir painting; the original PNG is never repainted.
uniform float liquid_slope = 0.0;
uniform float ripple_phase = 0.0;
uniform float ripple_size = 0.0;
const vec2 SOURCE_SIZE = vec2(1375.0, 1144.0);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 p = UV * SOURCE_SIZE;
	float left_wall = mix(330.0, 295.0, clamp((p.y - 420.0) / 80.0, 0.0, 1.0));
	left_wall = mix(left_wall, 279.0, clamp((p.y - 500.0) / 100.0, 0.0, 1.0));
	left_wall = mix(left_wall, 300.0, clamp((p.y - 600.0) / 100.0, 0.0, 1.0));
	left_wall = mix(left_wall, 420.0, clamp((p.y - 700.0) / 90.0, 0.0, 1.0));
	float right_wall = mix(830.0, 867.0, clamp((p.y - 420.0) / 80.0, 0.0, 1.0));
	right_wall = mix(right_wall, 878.0, clamp((p.y - 500.0) / 100.0, 0.0, 1.0));
	right_wall = mix(right_wall, 854.0, clamp((p.y - 600.0) / 100.0, 0.0, 1.0));
	right_wall = mix(right_wall, 730.0, clamp((p.y - 700.0) / 90.0, 0.0, 1.0));
	float wall_distance = min(p.x - left_wall, right_wall - p.x);
	float edge = smoothstep(0.0, 32.0, wall_distance);
	float rest_level = 466.0 + (p.x - 350.0) * 0.10;
	float band = 1.0 - smoothstep(42.0, 145.0, abs(p.y - rest_level));
	float inside = smoothstep(415.0, 442.0, p.y) * (1.0 - smoothstep(735.0, 790.0, p.y));
	float wave = sin((p.x - 320.0) * 0.014 + ripple_phase) * ripple_size;
	float shift = ((p.x - 575.0) * liquid_slope + wave) * edge * band * inside;
	float safe_shift = max(0.0, wall_distance * 0.45);
	shift = clamp(shift, -safe_shift, safe_shift);
	COLOR = texture(TEXTURE, UV - vec2(0.0, shift / SOURCE_SIZE.y)) * tint;
}
