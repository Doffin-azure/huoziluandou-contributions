shader_type canvas_item;
render_mode unshaded;
void fragment() {
 float top = (1.0 - smoothstep(0.0, 0.22, UV.y)) * 0.70;
 float bottom = smoothstep(0.65, 0.88, UV.y) * 0.96;
 COLOR = vec4(0.022, 0.052, 0.069, max(top, bottom));
}
