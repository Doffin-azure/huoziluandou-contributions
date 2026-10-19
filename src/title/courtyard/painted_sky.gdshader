shader_type sky;
uniform vec4 zenith : source_color = vec4(0.016, 0.17, 0.22, 1.0);
uniform vec4 horizon : source_color = vec4(0.08, 0.49, 0.47, 1.0);
uniform vec4 moon_paper : source_color = vec4(0.75, 0.69, 0.49, 1.0);
uniform sampler2D paper_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D gilt_clouds : source_color, filter_linear_mipmap, repeat_disable;
uniform float gilt_strength : hint_range(0.0, 1.0) = 0.42;

void sky() {
	float height = smoothstep(-0.05, 0.85, EYEDIR.y);
	COLOR = mix(horizon.rgb, zenith.rgb, height);
	float moon_distance = distance(EYEDIR, normalize(vec3(0.16, 0.235, -0.95)));
	float moon = 1.0 - smoothstep(0.094, 0.096, moon_distance);
	vec2 paper_uv = (EYEDIR.xy - normalize(vec3(0.16, 0.235, -0.95)).xy) / 0.190 + 0.5;
	float paper = dot(texture(paper_texture, paper_uv).rgb, vec3(0.333));
	COLOR = mix(COLOR, moon_paper.rgb * (0.94 + paper * 0.10), moon);
	// Painted scrolls live in sky direction space, so the main camera and the
	// actual water-reflection camera see the same distant cloud ornaments.
	vec2 cloud_uv = (EYEDIR.xy / max(0.01, -EYEDIR.z) - vec2(-0.85, 0.02)) / vec2(1.85, 0.64);
	cloud_uv.y = 1.0 - cloud_uv.y;
	if (EYEDIR.z < 0.0 && all(greaterThanEqual(cloud_uv, vec2(0.0))) && all(lessThanEqual(cloud_uv, vec2(1.0)))) {
		vec4 cloud = texture(gilt_clouds, cloud_uv);
		COLOR = mix(COLOR, cloud.rgb, cloud.a * gilt_strength * (1.0 - moon * 0.88));
	}
}
