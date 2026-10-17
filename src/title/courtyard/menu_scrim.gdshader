shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float shade = (1.0 - smoothstep(0.12, 0.43, UV.x)) * 0.55;
	COLOR = vec4(0.025, 0.045, 0.05, shade);
}
