shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D grain_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 half_size = vec3(0.5);
uniform vec2 grain_scale = vec2(1.0);
uniform float wear = 0.16;
uniform bool rotate_grain = false;
uniform vec2 grain_offset = vec2(0.0);
varying vec3 local_position;
varying vec3 local_normal;
float luminance(vec3 c) { return dot(c, vec3(0.25, 0.6, 0.15)); }
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec2 uv = (rotate_grain ? UV.yx : UV) * grain_scale + grain_offset;
	vec3 grain = texture(grain_texture, uv).rgb;
	float height = luminance(grain);
	float fiber = clamp((height - 0.01) * 8.0, 0.0, 1.0);
	vec2 pixel = 1.0 / vec2(textureSize(grain_texture, 0));
	float dx = luminance(texture(grain_texture, uv + vec2(pixel.x * 2.0, 0.0)).rgb) - height;
	float dy = luminance(texture(grain_texture, uv + vec2(0.0, pixel.y * 2.0)).rgb) - height;
	NORMAL_MAP = normalize(vec3(-dx * 3.2, -dy * 3.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.32;
	float edge = min(half_size.x - abs(local_position.x), half_size.z - abs(local_position.z));
	float worn_edge = exp(-max(edge, 0.0) * 35.0) * wear * max(local_normal.y, 0.0);
	worn_edge *= smoothstep(0.12, 0.75, fiber);
	float scratch = smoothstep(0.60, 0.90, fiber) * 0.012;
	ALBEDO = mix(grain * tint, vec3(0.47, 0.28, 0.125), worn_edge + scratch);
	ROUGHNESS = clamp(0.78 - fiber * 0.10 - worn_edge * 0.2, 0.60, 0.82);
	SPECULAR = 0.26;
	AO = mix(0.78, 1.0, fiber);
	AO_LIGHT_AFFECT = 0.30;
}
