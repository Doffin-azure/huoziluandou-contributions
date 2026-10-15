shader_type canvas_item;
uniform vec3 seal_color : source_color = vec3(0.67, 0.22, 0.17);
uniform bool disabled = false;
uniform bool hovered = false;
uniform bool pressed = false;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float grain = hash(floor(UV * vec2(640.0, 170.0)));
	float alpha = smoothstep(0.002, 0.012, edge + (grain - 0.5) * 0.015);
	alpha *= 0.88 + grain * 0.12;
	vec3 color = disabled ? vec3(0.58, 0.53, 0.46) : seal_color;
	if (!disabled) { color *= pressed ? 0.82 : (hovered ? 0.93 : 1.0); }
	COLOR = vec4(color * (0.92 + grain * 0.08), alpha);
}
