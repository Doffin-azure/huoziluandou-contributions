shader_type canvas_item;
uniform vec2 margin = vec2(0.045, 0.075);
uniform vec3 paper_color : source_color = vec3(0.937, 0.910, 0.847);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 nearest_edge = min(UV - margin, vec2(1.0) - margin - UV);
	float distance_to_edge = min(nearest_edge.x, nearest_edge.y);
	float ragged = sin(UV.y * 480.0) * 0.0005 + sin(UV.x * 610.0) * 0.0004;
	float sheet = smoothstep(-0.001, 0.001, distance_to_edge + ragged);
	float shadow = smoothstep(-0.013, -0.002, distance_to_edge) * 0.26;
	vec3 color = paper_color + (hash(UV * vec2(1400.0, 900.0)) - 0.5) * 0.025;
	COLOR = vec4(mix(vec3(0.07, 0.05, 0.035), color, sheet), max(sheet, shadow));
}
