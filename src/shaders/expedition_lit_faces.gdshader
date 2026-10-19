shader_type spatial;
render_mode cull_back, specular_disabled;
uniform vec4 top_color : source_color;
uniform vec4 front_color : source_color;
uniform vec4 side_color : source_color;
varying vec3 face_normal;

void vertex() {
    face_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

uniform float map_shade = 1.0;

void fragment() {
    vec3 weight = pow(abs(normalize(face_normal)), vec3(10.0));
    weight /= max(dot(weight, vec3(1.0)), 0.0001);
    ALBEDO = (top_color.rgb * weight.y + front_color.rgb * weight.z + side_color.rgb * weight.x) * map_shade;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}

#include "res://src/shaders/expedition_stylized_light.gdshaderinc"
