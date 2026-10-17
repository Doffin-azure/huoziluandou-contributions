shader_type sky;
uniform vec4 zenith : source_color = vec4(0.016, 0.17, 0.22, 1.0);
uniform vec4 horizon : source_color = vec4(0.08, 0.49, 0.47, 1.0);
uniform vec4 moon_paper : source_color = vec4(0.75, 0.69, 0.49, 1.0);
uniform sampler2D paper_texture : source_color, filter_linear_mipmap, repeat_disable;

void sky() {
	float height = smoothstep(-0.05, 0.85, EYEDIR.y);
	COLOR = mix(horizon.rgb, zenith.rgb, height);
	float moon_distance = distance(EYEDIR, normalize(vec3(0.12, 0.30, -0.95)));
	float moon = 1.0 - smoothstep(0.115, 0.117, moon_distance);
	vec2 paper_uv = (EYEDIR.xy - normalize(vec3(0.12, 0.30, -0.95)).xy) / 0.232 + 0.5;
	float paper = dot(texture(paper_texture, paper_uv).rgb, vec3(0.333));
	COLOR = mix(COLOR, moon_paper.rgb * (0.94 + paper * 0.10), moon);
}
