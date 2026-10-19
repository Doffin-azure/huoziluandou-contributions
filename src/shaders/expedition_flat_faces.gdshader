shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform vec4 top_color : source_color;
uniform vec4 front_color : source_color;
uniform vec4 side_color : source_color;
#include "res://src/shaders/expedition_flat_lighting.gdshaderinc"
varying vec3 face_normal;
varying vec3 world_position;

void vertex() {
    face_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

uniform float map_shade = 1.0;

void fragment() {
    vec3 weight = pow(abs(normalize(face_normal)), vec3(10.0));
    weight /= max(dot(weight, vec3(1.0)), 0.0001);
    vec3 base = top_color.rgb * weight.y + front_color.rgb * weight.z + side_color.rgb * weight.x;
    ALBEDO = painted_fire_light(base, world_position, face_normal) * map_shade;
}
