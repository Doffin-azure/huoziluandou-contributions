shader_type fog;
uniform float ambient_time = 0.0;
uniform float density = 0.025;
uniform vec4 mist_pigment : source_color = vec4(0.30, 0.56, 0.55, 1.0);

void fog() {
	// Soft bounded volumes, with broad currents rather than high-frequency noise.
	vec3 edge = abs(UVW * 2.0 - 1.0);
	float envelope = 1.0 - smoothstep(0.45, 1.0, max(edge.x, max(edge.y, edge.z)));
	float current = sin(WORLD_POSITION.x * 0.29 + WORLD_POSITION.z * 0.19 - ambient_time * 0.075);
	current += sin(WORLD_POSITION.z * 0.42 + WORLD_POSITION.y * 1.4 + ambient_time * 0.055) * 0.45;
	float ribbon = smoothstep(-0.9, 0.85, current);
	DENSITY = density * envelope * (0.35 + ribbon * 0.65);
	ALBEDO = mist_pigment.rgb;
	EMISSION = vec3(0.009, 0.028, 0.030);
}
