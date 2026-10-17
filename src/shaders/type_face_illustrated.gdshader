shader_type spatial;
render_mode unshaded;
uniform sampler2D face_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 quadrant = vec2(0.0);
uniform vec3 tint : source_color = vec3(1.0);
void fragment() {
	vec2 atlas_uv = quadrant + vec2(0.008) + UV * 0.484;
	vec3 sample_color = texture(face_atlas, atlas_uv).rgb;
	float grain = dot(sample_color, vec3(0.3, 0.6, 0.1));
	// ALBEDO 为线性颜色；直接填 sRGB 米色会被色调映射洗成白色。
	vec3 paper = mix(vec3(0.70, 0.58, 0.38), sample_color * vec3(0.94, 0.94, 0.92), 0.78);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	paper *= mix(0.56, 1.0, smoothstep(0.0, 0.028 + grain * 0.012, edge));
	ALBEDO = paper * tint;
}
