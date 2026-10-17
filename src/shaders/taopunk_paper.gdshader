shader_type canvas_item;
uniform sampler2D paper_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool strip = false;
uniform bool open_scene = false;

void fragment() {
	if (strip) {
		vec3 paper = texture(paper_texture, vec2(0.15 + UV.x * 0.70, 0.28 + UV.y * 0.05)).rgb;
		float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		COLOR = vec4(paper * mix(0.45, 1.0, smoothstep(0.0, 0.012, edge)), 1.0);
	} else {
		float paper_y = UV.y < 0.72 ? 0.05 + UV.y * 0.82 : 0.6404 + (UV.y - 0.72) * 1.18;
		vec4 paper = texture(paper_texture, vec2(0.015 + UV.x * 0.97, paper_y));
		if (open_scene) {
			// 右纸下缘退入景物，角色躯干直接叠在庭院上，避免整幅头像贴纸感。
			float cut = 0.42 + (1.0 - UV.x) * 0.23;
			cut += sin(UV.x * 39.0) * 0.008 + sin(UV.x * 107.0) * 0.004;
			paper.a *= 1.0 - smoothstep(cut - 0.004, cut + 0.004, UV.y);
		}
		COLOR = paper;
	}
}
