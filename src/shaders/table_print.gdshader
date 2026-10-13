shader_type canvas_item;
uniform sampler2D table_scene : source_color, filter_linear, repeat_disable;
void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	vec3 paper_light = texture(table_scene, SCREEN_UV).rgb;
	// 原生字与插画保持清晰，颜色跟随其下方真实纸面的暖光/窗影。
	vec3 illumination = clamp(paper_light / vec3(0.94, 0.91, 0.85), vec3(0.68), vec3(1.07));
	COLOR = vec4(ink.rgb * illumination, ink.a);
}
