shader_type canvas_item;
// 木活字纹理：竖向木纹 + 年轮 + 圆角遮罩。
uniform vec3 wood_dark : source_color = vec3(0.44, 0.29, 0.14);
uniform vec3 wood_light : source_color = vec3(0.79, 0.61, 0.37);
uniform vec3 edge_tint : source_color = vec3(0.30, 0.18, 0.08);
uniform float grain_strength : hint_range(0.0, 1.0) = 0.5;
uniform float rings : hint_range(0.0, 40.0) = 7.0;
uniform vec2 tile_size = vec2(104.0, 104.0);
uniform float corner_radius : hint_range(0.0, 64.0) = 12.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float rounded_mask(vec2 uv, vec2 size, float radius) {
	vec2 p = (uv - 0.5) * size;
	vec2 b = size * 0.5 - vec2(radius);
	vec2 q = abs(p) - b;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	return 1.0 - smoothstep(-1.2, 1.2, d);
}

void fragment() {
	vec2 uv = UV;
	float ring = sin((uv.x * rings + noise(uv * 3.0) * 1.2) * 6.2831) * 0.5 + 0.5;
	float fiber = noise(vec2(uv.x * 200.0, uv.y * 16.0));
	float t = mix(0.32, 1.0, ring * 0.6 + fiber * 0.4);
	vec3 col = mix(wood_dark, wood_light, t);
	float mask = rounded_mask(uv, tile_size, corner_radius);
	// 靠近边缘压暗，营造倒角
	vec2 p = (UV - 0.5) * tile_size;
	vec2 b = tile_size * 0.5 - vec2(corner_radius);
	float dist = length(max(abs(p) - b, 0.0)) + min(max(abs(p).x - b.x, abs(p).y - b.y), 0.0) - corner_radius;
	float bevel = smoothstep(-10.0, 0.0, dist);
	col = mix(col, edge_tint, bevel * 0.48);
	col += (hash(uv * 480.0) - 0.5) * 0.05 * grain_strength;
	COLOR = vec4(col, mask * alpha);
}
