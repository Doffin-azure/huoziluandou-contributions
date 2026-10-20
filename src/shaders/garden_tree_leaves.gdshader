shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Leaf ribbons and palmate accents use one surface with two visible sides.
// Keeping the geometry single-sided avoids outlining their triangulation.
uniform vec4 top_color : source_color;
uniform vec4 front_color : source_color;
uniform vec4 side_color : source_color;
uniform bool scene_lighting = true;
varying vec3 face_normal;

void vertex() {
    face_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec3 weight = pow(abs(normalize(face_normal)), vec3(10.0));
    weight /= max(dot(weight, vec3(1.0)), 0.0001);
    vec3 tint = top_color.rgb * weight.y + front_color.rgb * weight.z + side_color.rgb * weight.x;
    ALBEDO = scene_lighting ? tint : vec3(0.0);
    EMISSION = scene_lighting ? vec3(0.0) : tint;
    NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}

#include "res://src/shaders/expedition_stylized_light.gdshaderinc"
