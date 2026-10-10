shader_type canvas_item;
// 「墨芯」背景：深蓝渐变 + 细网格 + 顶部冷光晕 + 暗角。
uniform vec3 top_color : source_color = vec3(0.027, 0.051, 0.110);
uniform vec3 bottom_color : source_color = vec3(0.071, 0.125, 0.235);
uniform vec3 grid_color : source_color = vec3(0.25, 0.70, 1.0);
uniform vec3 glow_color : source_color = vec3(0.24, 0.88, 1.0);
uniform float grid_alpha : hint_range(0.0, 0.4) = 0.05;
uniform float grid_scale : hint_range(4.0, 200.0) = 34.0;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.18;
uniform float vignette : hint_range(0.0, 1.5) = 0.55;

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color, bottom_color, uv.y * uv.y * 0.85 + uv.y * 0.15);
	// 细网格（横竖各一组）
	vec2 g = abs(fract(uv * vec2(grid_scale, grid_scale * 0.62)) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.035, min(g.x, g.y));
	col += grid_color * line * grid_alpha;
	// 顶部冷光晕
	float d = distance(uv, vec2(0.5, 0.12));
	col += glow_color * glow_amount * smoothstep(1.0, 0.0, d);
	// 暗角
	float v = smoothstep(0.42, 1.05, length(uv - vec2(0.5)));
	col = mix(col, col * 0.5, v * vignette);
	COLOR = vec4(col, 1.0);
}
