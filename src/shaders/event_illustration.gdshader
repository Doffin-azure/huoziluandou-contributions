shader_type canvas_item;
render_mode unshaded;

// Keep the painted scene intact; only soften its outer edge into the journey backdrop.
void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	vec2 edge = min(UV, vec2(1.0) - UV);
	float opacity = smoothstep(0.0, 0.035, min(edge.x, edge.y));
	COLOR = vec4(painted.rgb, painted.a * opacity);
}
