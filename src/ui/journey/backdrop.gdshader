shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec3 painted = texture(TEXTURE, UV).rgb;
	float center = 1.0 - smoothstep(0.05, 0.70, length(UV - vec2(0.5)));
	vec3 ink = vec3(0.028, 0.075, 0.092);
	COLOR = vec4(mix(painted * vec3(0.75, 0.86, 0.86), ink, 0.56 + center * 0.25), 1.0);
}
