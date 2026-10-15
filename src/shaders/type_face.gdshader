shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D face_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 quadrant = vec2(0.0);
uniform vec3 tint : source_color = vec3(1.0);
void fragment() {
	vec2 atlas_uv = quadrant + vec2(0.008) + UV * 0.484;
	vec3 paper = texture(face_atlas, atlas_uv).rgb;
	ALBEDO = paper * tint * 0.84;
	vec2 texel = 2.0 / vec2(textureSize(face_atlas, 0));
	float h = dot(paper, vec3(0.3, 0.6, 0.1));
	float dx = dot(texture(face_atlas, atlas_uv + vec2(texel.x, 0.0)).rgb, vec3(0.3, 0.6, 0.1)) - h;
	float dy = dot(texture(face_atlas, atlas_uv + vec2(0.0, texel.y)).rgb, vec3(0.3, 0.6, 0.1)) - h;
	NORMAL_MAP = normalize(vec3(-dx * 1.8, -dy * 1.8, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.35;
	ROUGHNESS = mix(0.87, 0.96, h);
	SPECULAR = 0.26;
}
