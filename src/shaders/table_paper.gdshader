shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D paper_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
void fragment() {
	vec2 uv = vec2(0.035, 0.022) + UV * vec2(0.94, 0.956);
	vec4 fiber = texture(paper_texture, uv);
	ALBEDO = fiber.rgb * tint;
	ALPHA = fiber.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	vec2 texel = 1.0 / vec2(textureSize(paper_texture, 0));
	float h = dot(fiber.rgb, vec3(0.3, 0.6, 0.1));
	float dx = dot(texture(paper_texture, uv + vec2(texel.x * 3.0, 0.0)).rgb, vec3(0.3, 0.6, 0.1)) - h;
	float dy = dot(texture(paper_texture, uv + vec2(0.0, texel.y * 3.0)).rgb, vec3(0.3, 0.6, 0.1)) - h;
	NORMAL_MAP = normalize(vec3(-dx * 1.2, -dy * 1.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.3;
	ROUGHNESS = 0.92;
	SPECULAR = 0.22;
}
