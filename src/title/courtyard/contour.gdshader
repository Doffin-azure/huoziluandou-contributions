shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D scene : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normals : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec4 ink : source_color = vec4(0.025, 0.065, 0.085, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inverse_projection) {
	vec4 p = inverse_projection * vec4(uv * 2.0 - 1.0, texture(depth, uv).r, 1.0);
	return -p.z / p.w;
}

void fragment() {
	vec2 pixel = 0.9 / VIEWPORT_SIZE;
	float z = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 n = texture(normals, SCREEN_UV).rgb * 2.0 - 1.0;
	float silhouette = 0.0;
	float crease = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 offset = vec2(0.0);
		if (i == 0) offset.x = pixel.x;
		if (i == 1) offset.x = -pixel.x;
		if (i == 2) offset.y = pixel.y;
		if (i == 3) offset.y = -pixel.y;
		vec2 uv = SCREEN_UV + offset;
		float neighbor = view_depth(uv, INV_PROJECTION_MATRIX);
		float gap = neighbor - z;
		silhouette = max(silhouette, smoothstep(max(0.05, z * 0.007), max(0.1, z * 0.016), gap));
		vec3 next_n = texture(normals, uv).rgb * 2.0 - 1.0;
		float on_surface = 1.0 - smoothstep(0.04, 0.14, abs(gap));
		crease = max(crease, smoothstep(0.38, 0.75, 1.0 - dot(n, next_n)) * on_surface);
	}
	vec3 colour = texture(scene, SCREEN_UV).rgb;
	float recession = 1.0 - smoothstep(25.0, 70.0, z);
	float architectural_surface = smoothstep(0.50, 0.75, texture(normals, SCREEN_UV).a);
	float line = max(silhouette, crease * 0.45) * recession * strength * architectural_surface;
	ALBEDO = mix(colour, min(colour, ink.rgb), line);
}
