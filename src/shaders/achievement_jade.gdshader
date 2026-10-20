shader_type canvas_item;
// 已确认总览的墨青底在绘制时透明化；保留原始图案文件。
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float jade = smoothstep(0.075, 0.18, source.r);
	COLOR.a *= jade;
}
