shader_type canvas_item;
void fragment() {
	float opacity = smoothstep(0.40, 1.0, UV.x) * 0.84;
	COLOR = vec4(vec3(0.055, 0.043, 0.029), opacity);
}
