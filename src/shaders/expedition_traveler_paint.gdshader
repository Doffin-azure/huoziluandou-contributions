shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 pigment : source_color = vec4(0.15, 0.22, 0.24, 1.0);
uniform float map_shade = 1.0;
uniform float emissive = 0.0;

void fragment() {
	ALBEDO = pigment.rgb * COLOR.rgb * map_shade;
	EMISSION = pigment.rgb * emissive;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://src/shaders/expedition_stylized_light.gdshaderinc"
