shader_type canvas_item;
// 「墨芯」字块：半透明玻璃面板 + 冷色描边 + 内高光 + 圆角遮罩。
uniform vec2 tile_size = vec2(90.0, 90.0);
uniform float corner_radius : hint_range(0.0, 64.0) = 16.0;
uniform vec3 face : source_color = vec3(0.05, 0.09, 0.16);
uniform vec3 face_light : source_color = vec3(0.25, 0.50, 0.72);
uniform vec3 edge : source_color = vec3(0.24, 0.88, 1.0);
uniform float edge_width : hint_range(0.0, 12.0) = 2.2;
uniform float alpha : hint_range(0.0, 1.0) = 0.94;
uniform float glow : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * tile_size;
	vec2 b = tile_size * 0.5 - vec2(corner_radius);
	vec2 q = abs(p) - b;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius;
	float mask = 1.0 - smoothstep(-1.2, 1.2, d);

	// 斜向渐变（玻璃质感）
	float t = clamp(uv.x * 0.45 + (1.0 - uv.y) * 0.55, 0.0, 1.0);
	vec3 col = mix(face, face_light, t * 0.8);

	// 描边环
	float ring = clamp(1.0 - abs(d + edge_width * 0.5) / (edge_width * 0.5 + 0.001), 0.0, 1.0);
	col = mix(col, edge, pow(ring, 1.4) * clamp(glow, 0.0, 1.0));

	// 顶部内高光
	float spec = smoothstep(corner_radius * 0.6, 0.0, d) * (1.0 - uv.y);
	col += vec3(0.35, 0.55, 0.75) * spec * 0.25;

	COLOR = vec4(col, mask * alpha);
}
