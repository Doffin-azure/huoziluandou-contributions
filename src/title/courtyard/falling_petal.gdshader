shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 cinnabar : source_color = vec4(0.74, 0.26, 0.31, 1.0);
uniform vec4 faded_red : source_color = vec4(0.89, 0.48, 0.42, 1.0);
uniform vec4 paper_gold : source_color = vec4(0.77, 0.65, 0.44, 1.0);
varying float colour_seed;

void vertex() {
	colour_seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec3 pigment = mix(cinnabar.rgb, faded_red.rgb, colour_seed);
	if (colour_seed > 0.90) pigment = paper_gold.rgb;
	float folded = FRONT_FACING ? 1.0 : 0.65;
	ALBEDO = pigment * folded * mix(0.83, 1.0, COLOR.r);
	ROUGHNESS = 0.15;
}
