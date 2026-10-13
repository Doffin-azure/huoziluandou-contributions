shader_type canvas_item;
uniform sampler2D paper_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 paper_color : source_color = vec3(0.937, 0.91, 0.85);
uniform bool strip = false;
uniform bool physical = false;

void fragment() {
	if (physical) {
		COLOR = vec4(0.0);
	} else if (strip) {
		vec3 fiber = texture(paper_texture, vec2(0.18 + UV.x * 0.62, 0.32 + UV.y * 0.12)).rgb;
		COLOR = vec4(mix(fiber, paper_color, 0.12), 1.0);
	} else {
		vec2 sheet_uv = vec2(0.035, 0.022) + UV * vec2(0.94, 0.956);
		vec4 paper = texture(paper_texture, sheet_uv);
		// Four soft offset samples form a cast shadow beneath the actual deckled edge.
		vec2 shadow_uv = sheet_uv - vec2(0.006, 0.009);
		float shadow = texture(paper_texture, shadow_uv).a * 0.4;
		shadow += texture(paper_texture, shadow_uv + vec2(0.012, 0.0)).a * 0.15;
		shadow += texture(paper_texture, shadow_uv - vec2(0.012, 0.0)).a * 0.15;
		shadow += texture(paper_texture, shadow_uv + vec2(0.0, 0.009)).a * 0.15;
		shadow += texture(paper_texture, shadow_uv - vec2(0.0, 0.009)).a * 0.15;
		shadow *= 0.42;
		float alpha = paper.a + shadow * (1.0 - paper.a);
		vec3 ink_shadow = vec3(0.09, 0.055, 0.026);
		vec3 lit_paper = paper.rgb * mix(1.02, 0.97, UV.x * 0.55 + UV.y * 0.45);
		COLOR = vec4((lit_paper * paper.a + ink_shadow * shadow * (1.0 - paper.a)) / max(alpha, 0.001), alpha);
	}
}
