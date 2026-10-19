shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec3 base_color : source_color;
uniform vec3 tip_color : source_color;
uniform float map_shade = 1.0;
void fragment() {
    float tip = smoothstep(.15,.95,UV.y);
    float fold = pow(1.0-abs(UV.x*2.0-1.0),4.0);
    ALBEDO = mix(base_color,tip_color,tip*.84)*(1.0+fold*.055)*map_shade;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
#include "res://src/shaders/expedition_stylized_light.gdshaderinc"
