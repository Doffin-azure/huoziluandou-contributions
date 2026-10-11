shader_type canvas_item;
// 活字块材质：压印木/陶版。重点是轮廓、倒角和内框，不追求随机噪声贴图感。
uniform vec3 wood_dark : source_color = vec3(0.30, 0.20, 0.12);
uniform vec3 wood_light : source_color = vec3(0.76, 0.58, 0.34);
uniform vec3 edge_tint : source_color = vec3(0.16, 0.10, 0.06);
uniform float grain_strength : hint_range(0.0, 1.0) = 0.32;
uniform float rings : hint_range(0.0, 40.0) = 7.0;
uniform vec2 tile_size = vec2(104.0, 104.0);
uniform float corner_radius : hint_range(0.0, 64.0) = 12.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float rounded_mask(vec2 uv, vec2 size, float radius) {
	vec2 p = (uv - 0.5) * size;
	vec2 b = size * 0.5 - vec2(radius);
	vec2 q = abs(p) - b;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	return 1.0 - smoothstep(-1.0, 1.0, d);
}

void fragment() {
	vec2 uv = UV;
	float mask = rounded_mask(uv, tile_size, corner_radius);
	vec2 p = (uv - 0.5) * tile_size;
	vec2 b = tile_size * 0.5 - vec2(corner_radius);
	vec2 q = abs(p) - b;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius;

	// 低频暖色面，避免旧版强烈的“贴图噪点”感。
	float grain = noise(vec2(uv.x * 18.0, uv.y * 5.0));
	float light = clamp(0.62 + (1.0 - uv.y) * 0.24 + (uv.x - 0.5) * 0.08, 0.0, 1.0);
	vec3 col = mix(wood_dark, wood_light, light);
	col += (grain - 0.5) * grain_strength * 0.10;

	// 外轮廓和内压边。
	float outer = 1.0 - smoothstep(-1.0, 1.5, abs(d));
	float inset_d = d + 6.0;
	float inset = 1.0 - smoothstep(-1.0, 1.0, abs(inset_d));
	col = mix(col, edge_tint, outer * 0.72);
	col = mix(col, wood_light * 1.08, inset * 0.12);

	// 上沿高光、下沿压暗，形成实体厚度。
	float top = smoothstep(0.16, 0.0, uv.y) * mask;
	float bottom = smoothstep(0.72, 1.0, uv.y) * mask;
	col += vec3(0.16, 0.11, 0.06) * top;
	col -= vec3(0.10, 0.07, 0.04) * bottom;
	COLOR = vec4(col, mask * alpha);
}
