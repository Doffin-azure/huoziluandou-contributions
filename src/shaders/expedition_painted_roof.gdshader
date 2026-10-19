shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform vec4 roof_color : source_color;
uniform float roof_half_width = .75;
uniform float roof_half_depth = .53;
uniform float roof_ridge_half_width = .29;
#include "res://src/shaders/expedition_flat_lighting.gdshaderinc"
varying vec3 world_normal;
varying vec3 world_position;
varying vec3 roof_point;
varying vec3 axis_x;
varying vec3 axis_y;
varying vec3 axis_z;

void vertex() {
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    roof_point = VERTEX;
    axis_x = normalize(MODEL_NORMAL_MATRIX * vec3(1.0,0.0,0.0));
    axis_y = normalize(MODEL_NORMAL_MATRIX * vec3(0.0,1.0,0.0));
    axis_z = normalize(MODEL_NORMAL_MATRIX * vec3(0.0,0.0,1.0));
}

uniform float map_shade = 1.0;

void fragment() {
    float hip = max(0.0, abs(roof_point.x) - roof_ridge_half_width) / max(.001, roof_half_width - roof_ridge_half_width);
    float slope = abs(roof_point.z) / max(.001, roof_half_depth);
    // Broad painted hip/front/back regions follow the roof construction. Subdivision
    // triangles and the curved eave do not become small alternating light patches.
    vec3 normal = hip > slope
        ? normalize(axis_y * .88 + axis_x * sign(roof_point.x) * .48)
        : normalize(axis_y * .88 + axis_z * sign(roof_point.z) * .48);
    if (dot(world_normal, axis_y) < .1) normal = normalize(world_normal);
    float facing = dot(normal, normalize(vec3(-.55, .85, .60)));
    // Three broad painted values, without specular or gloss.
    float shade = facing > .76 ? 1.15 : (facing > .35 ? .94 : .72);
    ALBEDO = painted_fire_light(roof_color.rgb * shade, world_position, normal) * map_shade;
}
