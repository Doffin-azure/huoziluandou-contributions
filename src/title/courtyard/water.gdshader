shader_type spatial;
render_mode unshaded, cull_disabled;

varying vec3 world_position;
uniform vec4 water_colour : source_color = vec4(0.035, 0.28, 0.31, 1.0);
uniform sampler2D reflection_texture : filter_linear_mipmap, repeat_disable;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.50;
uniform float ambient_time = 0.0;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float wave_x = sin(p.x * 4.8 + p.y * 1.9 + ambient_time * 0.65) * 0.010;
	float wave_y = sin(p.y * 6.0 - p.x * 1.2 + ambient_time * 0.44) * 0.008;
	vec2 mirror_uv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y) + vec2(wave_x, wave_y) * 0.04;
	vec3 mirror_colour = textureLod(reflection_texture, mirror_uv, 1.5).rgb;
	// The mirrored view has already been lit. Do not illuminate it a second time.
	ALBEDO = mix(water_colour.rgb, mirror_colour * vec3(0.58, 0.72, 0.74), reflection_strength);
	float line = 1.0 - smoothstep(0.016, 0.035, abs(sin(p.y * 2.5 + sin(p.x * 0.6) * 0.12 + ambient_time * 0.08)));
	float span = smoothstep(0.65, 0.90, sin(p.x * 1.2 + p.y * 2.0));
	ALBEDO += vec3(0.012, 0.025, 0.023) * line * span;

}
