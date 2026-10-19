shader_type spatial;
render_mode cull_back, specular_disabled;
uniform vec4 roof_color : source_color;
uniform float roof_half_width = .75;
uniform float roof_half_depth = .53;
uniform float roof_ridge_half_width = .29;
varying vec3 roof_point;
varying vec3 local_normal;
varying mat3 roof_normal_matrix;

void vertex() {
    roof_point = VERTEX;
    local_normal = NORMAL;
    roof_normal_matrix = MODEL_NORMAL_MATRIX;
}

uniform float map_shade = 1.0;

void fragment() {
    float hip = max(0.0, abs(roof_point.x) - roof_ridge_half_width) / max(.001, roof_half_width - roof_ridge_half_width);
    float slope = abs(roof_point.z) / max(.001, roof_half_depth);
    // Semantic roof planes retain broad painted regions instead of triangle facets.
    vec3 normal = hip > slope
        ? normalize(vec3(sign(roof_point.x) * .48, .88, 0.0))
        : normalize(vec3(0.0, .88, sign(roof_point.z) * .48));
    if (local_normal.y < .1) normal = normalize(local_normal);
    NORMAL = normalize((VIEW_MATRIX * vec4(roof_normal_matrix * normal, 0.0)).xyz);
    vec2 tile = vec2(roof_point.x*5.2,abs(roof_point.z)*6.0);
    float joint = (1.0-smoothstep(.025,.065,min(fract(tile.x),1.0-fract(tile.x))))*.12;
    joint += (1.0-smoothstep(.02,.06,min(fract(tile.y),1.0-fract(tile.y))))*.10;
    ALBEDO = roof_color.rgb * (1.0-joint) * map_shade;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}

#include "res://src/shaders/expedition_stylized_light.gdshaderinc"
